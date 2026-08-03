import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/key_manager.dart';
import '../../core/models/asset.dart';
import '../../core/services/tx_history_service.dart';
import '../../core/state/providers/asset_provider.dart';
import '../../core/state/providers/currency_provider.dart';
import '../../core/state/providers/wallet_provider.dart';
import '../../features/send/fee/models/fee_estimate.dart';
import '../../features/send/send_gateway.dart';
import '../common/passphrase_gate.dart';
import '../format/chain_display.dart';
import '../send/fee_option.dart';
import '../send/send_view.dart';

/// Connects the send form to the executors and fee providers that already exist.
///
/// The passphrase here is not a confirmation step that could be switched off in settings: the
/// seed is stored encrypted under it, so `getSeedPhrase` is the only way to a signing key and
/// it cannot run without one. Sending without the app passphrase is not merely disallowed,
/// it is not expressible.
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key, required this.initialAsset, required this.onSent, this.request = 0});

  final Asset? initialAsset;

  /// Increments each time the user asks to send from a coin page, so the form re-seeds even
  /// when it is the same coin as last time.
  final int request;

  /// Called with the broadcast hash so the shell can take the user to the history.
  final ValueChanged<String> onSent;

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  Asset? _selected;
  FeeSpeed _speed = FeeSpeed.normal;
  bool _busy = false;
  String? _failure;

  /// Broadcasts made from this screen. Handed to the form, which clears itself when it goes
  /// up — otherwise the recipient and amount stay filled in and the button goes live again,
  /// which is one press away from sending the same money twice.
  int _sent = 0;

  /// The estimate as of the last build.
  ///
  /// Kept here because `watchFee` is a `ref.watch`, which is only legal during build —
  /// calling it from the send handler would throw. The value is the one the user was looking
  /// at when they pressed the button, which is also the one they agreed to pay.
  FeeEstimate? _estimate;

  /// Tiers the current chain has already quoted.
  ///
  /// Cleared whenever the asset changes, because an estimate belongs to the chain it came from.
  final Set<FeeSpeed> _answered = {};

  @override
  void initState() {
    super.initState();
    _selected = widget.initialAsset;
    // The chain is asked as soon as the form exists. Every fee provider is a StateNotifier
    // seeded with data(null) and fetches nothing on its own, so without this the estimate
    // never arrives and the tier shows a dash for as long as the screen is open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _askForFee();
    });
  }

  @override
  void didUpdateWidget(SendScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAsset != null && widget.request != oldWidget.request) {
      setState(() => _selected = widget.initialAsset);
      _askForFee();
    }
  }

  /// Asks the current chain what a transaction costs right now.
  ///
  /// On a chain with tiers, all three are asked for at once. A picker where two of the three
  /// cells are blank until you select them is not a comparison — and comparing is the only
  /// reason to show tiers at all.
  ///
  /// [only] limits the request to one tier. Choosing a tier must not re-ask for the other
  /// two: each has its own notifier, and re-fetching them all put every cell back to
  /// "Estimating…" — so picking a fee erased the very numbers being compared.
  ///
  /// A tier that has already answered is not asked again. Every notifier opens its fetch with a
  /// bare `AsyncValue.loading()`, which drops the figure it was holding, so re-asking is not a
  /// quiet background top-up: the cell blanks to "Estimating…", the row loses the line that
  /// carries the native amount and everything below it jumps up, and the primary button — which
  /// requires a live estimate before it will let anything be signed — goes dead under the
  /// cursor. Selecting a fee is the one moment that must not do any of that.
  void _askForFee({FeeSpeed? only}) {
    final asset = _resolved(ref.read(visibleAssetsProvider));
    if (asset == null) return;
    if (only != null) {
      if (_answered.contains(only)) return;
      SendGateway.requestFee(ref, asset, only);
      return;
    }
    if (SendGateway.hasSpeedTiers(asset.blockchain)) {
      for (final speed in FeeSpeed.values) {
        SendGateway.requestFee(ref, asset, speed);
      }
    } else {
      SendGateway.requestFee(ref, asset, _speed);
    }
  }

  /// The selected asset, re-read from the live list so a price tick or a balance change does
  /// not leave the form holding a stale copy.
  Asset? _resolved(List<Asset> assets) {
    if (assets.isEmpty) return null;
    final chosen = _selected;
    if (chosen == null) return assets.first;
    return assets.where((a) => a.id == chosen.id).firstOrNull ?? assets.first;
  }

  /// The tiers this chain actually offers.
  ///
  /// Chains that quote one price get one option rather than three identical ones — a choice
  /// that changes nothing is worse than no choice, because it implies the others were
  /// considered.
  List<FeeOption> _feeOptions(Asset asset, String nativeSymbol) {
    FeeOption build(String id, String label, FeeSpeed speed) {
      // Each tier watches its own provider, so each cell reports its own estimate rather than
      // borrowing the selected one's — which put the same wait time on all three.
      final fee = SendGateway.watchFee(ref, asset, speed);
      final estimate = fee.valueOrNull;
      // Noted here rather than at the request, because this is where the answer actually
      // arrives: a tier is "answered" once its provider has handed over a real estimate.
      if (estimate != null) _answered.add(speed);
      return FeeOption(
        id: id,
        label: label,
        wait: estimate?.estimatedTime ?? '',
        cost: estimate?.feeInUsd,
        native: estimate?.feeInNative,
        symbol: nativeSymbol,
        status: switch (fee) {
          AsyncLoading() => FeeStatus.loading,
          AsyncError() => FeeStatus.unavailable,
          _ => estimate == null ? FeeStatus.loading : FeeStatus.ready,
        },
      );
    }

    if (!SendGateway.hasSpeedTiers(asset.blockchain)) {
      return [build(FeeSpeed.normal.name, 'NETWORK FEE', FeeSpeed.normal)];
    }
    return [
      for (final speed in FeeSpeed.values) build(speed.name, speed.name.toUpperCase(), speed),
    ];
  }

  Future<void> _send(SendRequest request) async {
    final asset = request.asset;
    final wallet = ref.read(currentWalletProvider).value;
    if (wallet == null) return;

    final estimate = _estimate;
    final executor = SendGateway.executorFor(asset.blockchain, fee: estimate);
    if (executor == null) {
      setState(() => _failure = '${asset.blockchain} cannot be sent from KORA.');
      return;
    }

    final passphrase = await askPassphrase(
      context,
      title: 'SEND ${request.amount} ${asset.symbol}',
      explanation:
          'To ${request.recipient} on ${asset.chain.network}. '
          'Once broadcast this cannot be recalled.',
      confirmLabel: 'SIGN AND SEND',
    );
    if (passphrase == null || !mounted) return;

    setState(() {
      _busy = true;
      _failure = null;
    });

    final mnemonic = await KeyManager.getSeedPhrase(passphrase, walletId: wallet.id);
    if (mnemonic == null) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failure = 'That passphrase does not open this wallet.';
      });
      return;
    }

    try {
      final hash = await executor.execute(
        mnemonic: mnemonic,
        asset: asset,
        toAddress: request.recipient,
        amount: request.amount.toString(),
      );

      // The chain will not report this transaction for a block or two, so it is written down
      // here. `assetHistoryProvider` merges the pending store into every list and drops each
      // record once the chain confirms it — but nothing had ever written to that store, so
      // the merge was reading an always-empty file and a just-sent transaction simply did not
      // appear anywhere until the explorer caught up.
      await PendingTxStore.save(
        asset.id,
        TxRecord(
          hash: hash,
          from: '',
          to: request.recipient,
          amount: request.amount,
          symbol: asset.symbol,
          timestamp: DateTime.now(),
          direction: TxDirection.outgoing,
          confirmed: false,
          blockchain: asset.blockchain,
          feePaid: estimate?.feeInNative,
        ),
      );

      // Writing the balance down now means the number the user sees next matches what they
      // just did, instead of showing the old balance and looking as though nothing happened.
      final fee = asset.type == AssetType.native ? (estimate?.feeInNative ?? 0) : 0.0;
      final remaining = (asset.balanceAsDouble - request.amount - fee).clamp(0.0, double.infinity);
      await ref
          .read(currentWalletProvider.notifier)
          .applyOptimisticBalance(asset.id, remaining.toStringAsFixed(asset.decimals.clamp(0, 10)));

      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent++;
      });
      widget.onSent(hash);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failure = _readable('$e');
      });
    }
  }

  /// Chain errors arrive as raw node responses. The two that users actually hit are worth
  /// translating; the rest are shown as they came, because a vague rewording of an error we
  /// did not anticipate is worse than the original.
  static String _readable(String raw) {
    final message = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    if (message.isEmpty) return 'The transaction did not go through.';
    final lower = message.toLowerCase();
    if (lower.contains('insufficient funds for gas') ||
        lower.contains('gas required exceeds allowance')) {
      return 'Not enough of the native coin left to pay the network fee.';
    }
    if (lower.contains('nonce')) {
      return 'An earlier transaction from this wallet is still pending. Wait for it to confirm.';
    }
    return message[0].toUpperCase() + message.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    // A wallet switch has to reach this form.
    //
    // The shell keeps every visited screen alive, so this state and its two controllers
    // outlive the wallet they were filled in for. The form clears on a change of asset id,
    // and two wallets both holding BTC share that id — so switching wallets left the previous
    // wallet's recipient and amount typed in, on a screen now spending different money.
    ref.listen(currentWalletProvider.select((w) => w.valueOrNull?.id), (previous, next) {
      if (previous == next) return;
      setState(() {
        _selected = null;
        _failure = null;
        _answered.clear();
        _speed = FeeSpeed.normal;
      });
      _askForFee();
    });

    final assets = ref.watch(visibleAssetsProvider);
    final money = ref.watch(currencyProvider);
    final walletId = ref.watch(currentWalletProvider.select((w) => w.valueOrNull?.id));

    final selected = _resolved(assets);
    if (selected == null) return const SizedBox.shrink();

    _estimate = SendGateway.watchFee(ref, selected, _speed).valueOrNull;
    final executor = SendGateway.executorFor(selected.blockchain);

    return SendView(
      assets: assets,
      selected: selected,
      walletId: walletId,
      fees: _feeOptions(selected, _nativeSymbol(assets, selected)),
      money: money,
      busy: _busy,
      failure: _failure,
      sentCount: _sent,
      // The same check the executor will run when it comes to build the transaction, so the
      // form cannot accept an address the engine would refuse.
      validateAddress: executor?.validateAddress,
      onSelectAsset: (asset) {
        setState(() {
          _selected = asset;
          _failure = null;
          _answered.clear();
          // A tier chosen on Bitcoin means nothing on Tron, and carrying it across meant the
          // form could sign at a speed the new chain never offered.
          _speed = FeeSpeed.normal;
        });
        _askForFee();
      },
      onFeeTier: (id) {
        final chosen = FeeSpeed.values.firstWhere(
          (s) => s.name == id,
          orElse: () => FeeSpeed.normal,
        );
        setState(() => _speed = chosen);
        _askForFee(only: chosen);
      },
      onReview: _send,
    );
  }

  /// The ticker the fee is actually paid in — the chain's native coin, which for a token is a
  /// different asset from the one being sent. Sending USDT costs TRX, and saying so is the
  /// difference between a fee the user can check and a number they have to trust.
  String _nativeSymbol(List<Asset> assets, Asset asset) {
    if (asset.type == AssetType.native) return asset.symbol;
    final native = assets
        .where((a) => a.blockchain == asset.blockchain && a.type == AssetType.native)
        .firstOrNull;
    return native?.symbol ?? asset.symbol;
  }
}
