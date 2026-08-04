import 'package:flutter/material.dart';
import 'package:kora/features/send/chain_labels.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';
import 'package:kora/core/widgets/kora_button.dart';
import 'package:kora/core/widgets/kora_field.dart';
import 'package:kora/core/widgets/kora_rows.dart';
import 'package:kora/core/widgets/input/numpad.dart';
import 'package:kora/features/address_book/address_book_screen.dart';
import 'package:kora/features/scan/qr_scanner_screen.dart';
// ─── Executor imports ─────────────────────────────────────────────────────────
import 'package:kora/features/send/executors/registry.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/features/send/tx_success_screen.dart';
import 'package:kora/core/utils/page_transitions.dart';
// ─── Fee imports ──────────────────────────────────────────────────────────────
import 'package:kora/features/send/fee/models/fee_estimate.dart';
import 'package:kora/features/send/fee/bitcoin_fee/bitcoin_fee_provider.dart';
import 'package:kora/features/send/fee/ethereum_fee/ethereum_fee_provider.dart';
import 'package:kora/features/send/fee/solana_fee/solana_fee_provider.dart';
import 'package:kora/features/send/fee/tron_fee/tron_fee_provider.dart';
import 'package:kora/features/send/fee/litecoin_fee/litecoin_fee_provider.dart';
import 'package:kora/features/send/fee/bitcoin_cash_fee/bitcoin_cash_fee_provider.dart';
import 'package:kora/features/send/fee/bsc_fee/bsc_fee_provider.dart';
import 'package:kora/features/send/fee/ethereum_classic_fee/ethereum_classic_fee_provider.dart';
import 'package:kora/core/services/tx_history_service.dart';
import 'package:kora/features/send/review/review_sheet.dart';
import 'package:kora/features/send/fee/fee_speed_selector.dart';
import 'package:kora/features/send/widgets/unsupported_banner.dart';

// ─── Chain helpers ─────────────────────────────────────────────────────────────

bool _isEvm(String b)           => APIConfig.evmChains.contains(b);
bool _isTron(String b)          => b == 'tron';
bool _isSolana(String b)        => b == 'solana';
bool _isUtxo(String b)    => APIConfig.utxoChains.contains(b);

bool _sendSupported(Asset a) =>
    _isEvm(a.blockchain) || _isTron(a.blockchain) || _isSolana(a.blockchain) ||
    _isUtxo(a.blockchain);

// ─── SendScreen ───────────────────────────────────────────────────────────────

/// The send form, exactly the prototype's: the asset is a field that opens a sheet, the
/// amount is a large figure driven by the wallet's own square keypad, the fee is one row.
/// As a tab (embedded) the bottom bar stays under it; pushed from an asset's page it
/// arrives with that asset chosen and a back arrow that pops.
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({
    super.key,
    required this.assets,
    this.initialAddress,
    this.embedded = false,
    this.onExit,
  });
  final List<Asset> assets;
  final String? initialAddress;

  /// True when living as tab 02 under the shell's bar: the back arrow then hands control
  /// back to the wallet tab through [onExit] instead of popping a route.
  final bool embedded;
  final VoidCallback? onExit;

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> with ThemeAwareMixin {
  final _toCtrl           = TextEditingController();
  final _amountCtrl       = TextEditingController();
  Asset?    _asset;
  bool      _loading      = false;
  String?   _addrErr;
  String?   _amountErr;
  FeeSpeed  _selectedSpeed = FeeSpeed.normal;

  static const _speedSupportedChains = {
    'bitcoin', 'litecoin', 'bitcoin_cash',
  };

  /// Solana rent exemption for a system account (0 bytes data) = 890,880 lamports.
  /// The sender's account must retain at least this much after a transfer.
  static const _solRentExemption = 0.00089088;

  bool _supportsSpeedSelector(String blockchain) =>
      _speedSupportedChains.contains(blockchain);

  void _selectSpeed(FeeSpeed speed) {
    if (_selectedSpeed == speed || _asset == null) return;
    setState(() => _selectedSpeed = speed);
    _fetchFeeForAsset(_asset!);
    // Re-validate amount after provider has a chance to update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAmountAgainstFee();
    });
  }

  @override
  void initState() {
    super.initState();
    _pickInitialAsset();
    if (widget.initialAddress != null) {
      _toCtrl.text = widget.initialAddress!;
    }
    _toCtrl.addListener(_onAddrChanged);
    _amountCtrl.addListener(_onAmountChanged);
  }

  /// The form always has an asset in front of it, like the prototype: pushed with one, that
  /// one; as a tab, the first asset that actually holds a balance, else simply the first.
  void _pickInitialAsset() {
    if (widget.assets.isEmpty) return;
    _asset = widget.assets.length == 1
        ? widget.assets.first
        : widget.assets.firstWhere((a) => a.balanceAsDouble > 0,
            orElse: () => widget.assets.first);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _asset != null) _fetchFeeForAsset(_asset!);
    });
  }

  @override
  void didUpdateWidget(SendScreen old) {
    super.didUpdateWidget(old);
    // The shell hands a scanned address to the living tab this way.
    if (widget.initialAddress != null &&
        widget.initialAddress != old.initialAddress) {
      _toCtrl.text = widget.initialAddress!;
      _onAddrChanged();
    }
    // A freshly funded wallet's assets arrive after the first build.
    if (_asset == null && widget.assets.isNotEmpty) {
      setState(_pickInitialAsset);
    }
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    _checkAmountAgainstFee();
    setState(() {}); // the large figure and the CTA's readiness both read the controller
  }

  void _checkAmountAgainstFee() {
    final asset = _asset;
    if (asset == null || asset.type != AssetType.native) {
      if (_amountErr != null) setState(() => _amountErr = null);
      return;
    }
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || amt <= 0) {
      if (_amountErr != null) setState(() => _amountErr = null);
      return;
    }
    final fee = _readCurrentFee();
    if (fee == null || fee.feeInNative <= 0) {
      if (_amountErr != null) setState(() => _amountErr = null);
      return;
    }
    final sufficient = amt + fee.feeInNative <= asset.balanceAsDouble;
    final err = sufficient ? null : 'Insufficient funds at this fee. Tap MAX to update.';
    if (err != _amountErr) setState(() => _amountErr = err);
  }

  void _onAddrChanged() {
    if (_asset == null) return;
    final addr = _toCtrl.text.trim();
    final err = addr.isEmpty
        ? 'Enter recipient address'
        : getExecutor(_asset!.blockchain)?.validateAddress(addr);
    if (err != _addrErr) setState(() => _addrErr = err);
  }

  void _fetchFeeForAsset(Asset asset) {
    final blockchain = asset.blockchain;
    final spd = _selectedSpeed;
    debugPrint('[FEE] Fetching fee for $blockchain (speed: ${spd.name})');

    switch (blockchain) {
      case 'bitcoin':
        ref.read(bitcoinFeeProvider(spd).notifier).fetchFee(forceRefresh: true);
      case 'ethereum':
        ref.read(ethereumFeeProvider(EthereumFeeParams(blockchain: 'ethereum', speed: FeeSpeed.normal, isToken: asset.type == AssetType.token)).notifier).fetchFee(forceRefresh: true);
      case 'bsc':
        ref.read(bscFeeProvider(FeeSpeed.normal).notifier).fetchFee(forceRefresh: true, isToken: asset.type == AssetType.token);
      case 'ethereum_classic':
        ref.read(ethereumClassicFeeProvider(FeeSpeed.normal).notifier).fetchFee(forceRefresh: true);
      case 'solana':
        ref.read(solanaFeeProvider(null).notifier).fetchFee(forceRefresh: true);
      case 'tron':
        ref.read(tronFeeProvider.notifier).fetchFee(forceRefresh: true, isToken: asset.type == AssetType.token);
      case 'litecoin':
        ref.read(litecoinFeeProvider(spd).notifier).fetchFee(forceRefresh: true);
      case 'bitcoin_cash':
        ref.read(bitcoinCashFeeProvider(spd).notifier).fetchFee(forceRefresh: true);
      default:
        debugPrint('[FEE] No fee provider for $blockchain');
    }
  }

  void _applyMax() {
    final assetRaw = _asset;
    if (assetRaw == null) return;
    // Use live balance from provider (reflects optimistic updates after sends)
    final asset = ref.read(currentWalletProvider).value?.assets
        .firstWhere((a) => a.id == assetRaw.id, orElse: () => assetRaw)
        ?? assetRaw;
    final bal = asset.balanceAsDouble;
    if (asset.type == AssetType.native) {
      final fee = _readCurrentFee();
      if (fee != null && fee.feeInNative > 0) {
        final reserve = fee.feeInNative +
            (asset.blockchain == 'solana' ? _solRentExemption : 0.0);
        final max = (bal - reserve).clamp(0.0, double.infinity);
        _amountCtrl.text = _fmt(max, asset.decimals);
        if (_amountErr != null) setState(() => _amountErr = null);
        return;
      }
    }
    _amountCtrl.text = _fmt(bal, asset.decimals);
    if (_amountErr != null) setState(() => _amountErr = null);
  }

  double _maxSendable(Asset asset) {
    if (asset.type == AssetType.native) {
      final fee = _readCurrentFee();
      if (fee != null && fee.feeInNative > 0) {
        final reserve = fee.feeInNative +
            (asset.blockchain == 'solana' ? _solRentExemption : 0.0);
        return (asset.balanceAsDouble - reserve).clamp(0.0, double.infinity);
      }
    }
    return asset.balanceAsDouble;
  }

  static String _fmt(double v, int decimals) {
    if (v <= 0) return '0';
    final cap = decimals.clamp(0, 8);
    final s   = v.toStringAsFixed(cap);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  // ─── The keypad drives the amount ───────────────────────────────────────────

  void _padDigit(String d) {
    final t = _amountCtrl.text;
    if (t.replaceAll('.', '').length >= 12) return;
    _amountCtrl.text = t + d;
  }

  void _padDot() {
    final t = _amountCtrl.text;
    if (t.contains('.')) return;
    _amountCtrl.text = t.isEmpty ? '0.' : '$t.';
  }

  void _padBackspace() {
    final t = _amountCtrl.text;
    if (t.isEmpty) return;
    _amountCtrl.text = t.substring(0, t.length - 1);
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScannerScreen()),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() { _toCtrl.text = result; _onAddrChanged(); });
    }
  }

  Future<void> _openAddressBook() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => AddressBookScreen(filterBlockchain: _asset?.blockchain),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() { _toCtrl.text = result; _onAddrChanged(); });
    }
  }

  FeeEstimate? _readCurrentFee() {
    final asset = _asset;
    if (asset == null) return null;
    final spd = _selectedSpeed;
    const normal = FeeSpeed.normal;
    return switch (asset.blockchain) {
      'bitcoin'           => ref.read(bitcoinFeeProvider(spd)).valueOrNull,
      'ethereum'          => ref.read(ethereumFeeProvider(EthereumFeeParams(blockchain: 'ethereum', speed: normal, isToken: asset.type == AssetType.token))).valueOrNull,
      'bsc'               => ref.read(bscFeeProvider(normal)).valueOrNull,
      'ethereum_classic'  => ref.read(ethereumClassicFeeProvider(normal)).valueOrNull,
      'solana'            => ref.read(solanaFeeProvider(null)).valueOrNull,
      'tron'              => ref.read(tronFeeProvider).valueOrNull,
      'litecoin'          => ref.read(litecoinFeeProvider(spd)).valueOrNull,
      'bitcoin_cash'      => ref.read(bitcoinCashFeeProvider(spd)).valueOrNull,
      _                   => null,
    };
  }

  /// The same providers, watched — the fee row re-renders as the quote arrives.
  AsyncValue<FeeEstimate?>? _watchCurrentFee() {
    final asset = _asset;
    if (asset == null) return null;
    final spd = _selectedSpeed;
    const normal = FeeSpeed.normal;
    return switch (asset.blockchain) {
      'bitcoin'           => ref.watch(bitcoinFeeProvider(spd)),
      'ethereum'          => ref.watch(ethereumFeeProvider(EthereumFeeParams(blockchain: 'ethereum', speed: normal, isToken: asset.type == AssetType.token))),
      'bsc'               => ref.watch(bscFeeProvider(normal)),
      'ethereum_classic'  => ref.watch(ethereumClassicFeeProvider(normal)),
      'solana'            => ref.watch(solanaFeeProvider(null)),
      'tron'              => ref.watch(tronFeeProvider),
      'litecoin'          => ref.watch(litecoinFeeProvider(spd)),
      'bitcoin_cash'      => ref.watch(bitcoinCashFeeProvider(spd)),
      _                   => null,
    };
  }

  void _review() {
    final asset = _asset;
    if (asset == null) return;
    final to  = _toCtrl.text.trim();
    final err = to.isEmpty
        ? 'Enter recipient address'
        : getExecutor(asset.blockchain)?.validateAddress(to);
    if (err != null) { setState(() => _addrErr = err); return; }
    final amtStr = _amountCtrl.text.trim();
    final amt    = double.tryParse(amtStr);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    final liveAssetForCheck = ref.read(currentWalletProvider).value?.assets
        .firstWhere((a) => a.id == asset.id, orElse: () => asset) ?? asset;
    if (amt > liveAssetForCheck.balanceAsDouble) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amount exceeds available balance')));
      return;
    }
    // For token sends: check native coin balance covers gas fee
    if (asset.type == AssetType.token) {
      final fee = _readCurrentFee();
      if (fee != null && fee.feeInNative > 0) {
        final wallet = ref.read(currentWalletProvider).value;
        final native = wallet?.assets.firstWhere(
          (a) => a.blockchain == asset.blockchain && a.type == AssetType.native,
          orElse: () => asset,
        );
        final nativeBal = (native?.type == AssetType.native)
            ? (double.tryParse(native!.balance) ?? 0.0)
            : 0.0;
        if (nativeBal < fee.feeInNative) {
          final sym = _gasSymbol(asset.blockchain);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Insufficient $sym for gas fee (need ${fee.feeInNative.toStringAsFixed(8)} $sym)'),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 4),
          ));
          return;
        }
      }
    }
    if (_amountErr != null) return; // insufficient at current fee — error shown inline
    final feeEstimate = _readCurrentFee();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewSheet(
        asset: asset, to: to, amount: amtStr,
        feeEstimate: feeEstimate,
        onConfirm: (pin) async {
          final (hash, err) = await _execute(pin, asset, to, amtStr, feeEstimate);
          return (hash, err);
        },
        onSuccess: (txHash) {
          // A tab cannot be replaced, only covered; a pushed screen steps aside.
          final route = PushPageRoute<void>(page: TxSuccessScreen(
            asset: asset,
            toAddress: to,
            amount: amtStr,
            txHash: txHash,
            feeEstimate: feeEstimate,
          ));
          if (widget.embedded) {
            _toCtrl.clear();
            _amountCtrl.clear();
            Navigator.of(context).push(route);
          } else {
            Navigator.of(context).pushReplacement(route);
          }
        },
      ),
    );
  }

  // Returns (txHash, errorMessage):
  //   (hash,  null ) → success
  //   (null,  null ) → wrong PIN
  //   (null, 'msg' ) → executor/network error
  Future<(String?, String?)> _execute(
    String pin, Asset asset, String to, String amountStr, [
    FeeEstimate? feeOverride,
  ]) async {
    final walletState = ref.read(currentWalletProvider);
    final walletId = walletState.value?.id ?? '';
    debugPrint('[SEND][_execute] blockchain=${asset.blockchain} assetId=${asset.id}');
    debugPrint('[SEND][_execute] walletState=${walletState.runtimeType} walletId="$walletId" pinLen=${pin.length}');

    final mnemonic = await KeyManager.getSeedPhrase(pin, walletId: walletId);
    debugPrint('[SEND][_execute] getSeedPhrase → ${mnemonic != null ? 'OK (${mnemonic.split(' ').length} words)' : 'NULL (wrong PIN or walletId not found)'}');
    if (mnemonic == null) return (null, null); // wrong PIN

    final executor = getExecutorWithFee(asset.blockchain, feeOverride);
    if (executor == null) {
      debugPrint('[SEND][_execute] ERROR: no executor for ${asset.blockchain}');
      return (null, 'Blockchain ${asset.blockchain} is not supported');
    }

    debugPrint('[SEND][_execute] calling executor.execute to=$to amount=$amountStr');
    try {
      final txHash = await executor.execute(
        mnemonic: mnemonic,
        asset: asset,
        toAddress: to,
        amount: amountStr,
      );
      debugPrint('[SEND][_execute] SUCCESS txHash=$txHash');
      // Optimistic TX in cache with confirmed:false → shows "Processing" until blockchain confirms
      try {
        final newRecord = TxRecord(
          hash:       txHash,
          from:       '',
          to:         to,
          amount:     double.tryParse(amountStr) ?? 0,
          symbol:     asset.symbol,
          timestamp:  DateTime.now(),
          direction:  TxDirection.outgoing,
          confirmed:  false,
          blockchain: asset.blockchain,
          feePaid:    feeOverride?.feeInNative,
        );
        final existing = getCachedHistory(asset) ?? [];
        if (!existing.any((r) => r.hash == txHash)) {
          setCachedHistory(asset, [newRecord, ...existing]);
        }
        await PendingTxStore.save(asset.id, newRecord);
      } catch (_) {}
      // Optimistic balance: subtract sent amount + fee locally, schedule real refresh in 4 min
      try {
        final sentAmt = double.tryParse(amountStr) ?? 0.0;
        final isNative = asset.type == AssetType.native;
        final fee = isNative ? (feeOverride?.feeInNative ?? 0.0) : 0.0;
        final currentBal = double.tryParse(asset.balance) ?? 0.0;
        final newBal = (currentBal - sentAmt - fee).clamp(0.0, double.maxFinite);
        final decimals = asset.decimals.clamp(0, 10);
        await ref.read(currentWalletProvider.notifier)
            .applyOptimisticBalance(asset.id, newBal.toStringAsFixed(decimals));
      } catch (_) {}
      return (txHash, null);
    } catch (e, st) {
      debugPrint('[SEND][_execute] EXECUTOR ERROR: $e');
      debugPrint('[SEND][_execute] STACK: $st');
      return (null, _cleanError('$e'));
    }
  }

  static String _gasSymbol(String blockchain) => switch (blockchain) {
    'bsc'               => 'BNB',
    'ethereum_classic'  => 'ETC',
    _                   => 'ETH',
  };

  static String _cleanError(String raw) {
    // Strip 'Exception: ' prefix that Dart adds
    final s = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    if (s.isEmpty) return 'Transaction failed';
    // Translate cryptic gas/funds RPC errors to user-friendly messages
    final lower = s.toLowerCase();
    if (lower.contains('gas required exceeds allowance') ||
        lower.contains('insufficient funds for gas') ||
        lower.contains('gas * price + value')) {
      return 'Insufficient funds for gas fee. Please top up your wallet.';
    }
    // Capitalise first letter
    return s[0].toUpperCase() + s.substring(1);
  }

  // ─── The asset sheet ────────────────────────────────────────────────────────

  void _openAssetSheet() {
    if (widget.assets.length < 2) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssetPickSheet(
        assets: widget.assets,
        selectedId: _asset?.id,
        onPick: (a) {
          Navigator.of(context).pop();
          if (a.id == _asset?.id) return;
          setState(() {
            _asset = a;
            _addrErr = null;
            _amountErr = null;
            _amountCtrl.clear();
          });
          _onAddrChanged();
          _fetchFeeForAsset(a);
        },
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asset = _asset;

    if (asset == null) {
      // A wallet with nothing to send — words only, in the language.
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: koraAppBar(context, 'Send',
            backLabel: 'Wallet',
          onBack: widget.embedded
                ? widget.onExit
                : () => Navigator.of(context).pop()),
        body: Center(
          child: Text('NO ASSETS TO SEND',
              style: kLabel(AppColors.textTertiary, size: 10, tracking: 0.14)),
        ),
      );
    }

    // Live balance from provider reflects optimistic updates after sends
    final liveBalanceStr = ref.watch(currentWalletProvider).value?.assets
        .firstWhere((a) => a.id == asset.id, orElse: () => asset)
        .balance ?? asset.balance;
    final liveAsset = liveBalanceStr != asset.balance
        ? asset.copyWith(balance: liveBalanceStr)
        : asset;
    final supported = _sendSupported(asset);

    final amountText = _amountCtrl.text;
    final amountVal  = double.tryParse(amountText) ?? 0;
    final usdText    = '≈ \$${(amountVal * liveAsset.priceUsd).toStringAsFixed(2)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: koraAppBar(
        context,
        'Send',
        backLabel: 'Wallet',
          onBack: widget.embedded
            ? widget.onExit
            : () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        top: false,
        bottom: !widget.embedded,
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const KoraSlabel('Asset'),
                _assetField(liveAsset),

                if (!supported) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: UnsupportedBanner(asset.symbol),
                  ),
                ] else ...[
                  const KoraSlabel('Recipient'),
                  KoraField(
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _toCtrl,
                          style: koraInputStyle(),
                          decoration: koraInputDecoration(
                              'ADDRESS ON ${netLabel(asset.blockchain).toUpperCase()}'),
                        ),
                      ),
                      AnimatedTap(
                        onTap: _scanQr,
                        child: Icon(Icons.qr_code_scanner_rounded,
                            color: AppColors.textTertiary, size: 16),
                      ),
                      const SizedBox(width: 12),
                      AnimatedTap(
                        onTap: _openAddressBook,
                        child: Icon(Icons.book_outlined,
                            color: AppColors.textTertiary, size: 16),
                      ),
                    ]),
                  ),
                  if (_addrErr != null && _toCtrl.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                      child: Text(_addrErr!.toUpperCase(),
                          style: kLabel(AppColors.negative, size: 9, tracking: 0.08)),
                    ),

                  const KoraSlabel('Amount'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                    // A fixed line for the figure, and MAX centred against it. Baseline
                    // alignment moved the button every time the number changed length —
                    // a control that shifts under the thumb it is waiting for.
                    child: SizedBox(
                      height: 34 * kTextScale * 1.1,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // A crypto amount is not a price: the last digits are the
                          // difference between sending everything and leaving dust behind,
                          // so the figure shrinks to fit rather than ending in an ellipsis.
                          //
                          // Expanded, not Flexible: the figure claims the whole line so MAX
                          // stays pinned to the right edge. Flexible let it collapse to the
                          // width of the digits, and MAX came sliding in beside a short
                          // number instead of holding its corner.
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    amountText.isEmpty ? '0' : amountText,
                                    maxLines: 1,
                                    style: kNum(
                                        amountText.isEmpty
                                            ? AppColors.textTertiary
                                            : AppColors.textPrimary,
                                        size: 34),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(asset.symbol,
                                      style: kMonoText(
                                          AppColors.textTertiary, size: 12)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedTap(
                            onTap: _applyMax,
                            pressScale: 0.92,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(border: kHairline()),
                              child: Text('MAX',
                                  style: kLabel(AppColors.textSecondary,
                                      size: 10, tracking: 0.14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                    child: Builder(builder: (_) {
                      final maxSend = _maxSendable(liveAsset);
                      final afterFee = liveAsset.type == AssetType.native &&
                          maxSend < liveAsset.balanceAsDouble;
                      return Row(children: [
                        Text(usdText,
                            style: kMonoText(AppColors.textTertiary, size: 10)),
                        const Spacer(),
                        Text(
                          (afterFee
                                  ? 'AVAILABLE ${_fmt(maxSend, liveAsset.decimals)} ${liveAsset.symbol}'
                                  : 'BALANCE ${liveAsset.formattedBalance}')
                              .toUpperCase(),
                          style: kMonoText(AppColors.textTertiary, size: 9),
                        ),
                      ]);
                    }),
                  ),
                  if (_amountErr != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                      child: Text(_amountErr!.toUpperCase(),
                          style: kLabel(AppColors.negative, size: 9, tracking: 0.08)),
                    ),

                  const KoraSlabel('Network fee'),
                  _feeRow(asset),

                  // The wallet's own keypad enters the amount — no system keyboard for
                  // figures, exactly the prototype.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
                    child: Numpad(
                      onDigit: _padDigit,
                      onBackspace: _padBackspace,
                      onDot: _padDot,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (supported)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
              child: KoraCta(
                label: 'Review Transaction',
                onTap: amountVal > 0 ? _review : null,
                busy: _loading,
              ),
            ),
        ]),
      ),
    );
  }

  /// The asset as a field: symbol and name, the live balance under them, ▾ at the edge.
  Widget _assetField(Asset liveAsset) {
    final canPick = widget.assets.length > 1;
    return AnimatedTap(
      onTap: canPick ? _openAssetSheet : null,
      pressScale: 0.99,
      pressOpacity: 0.9,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: AppColors.surface, border: kHairline()),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(liveAsset.symbol,
                        style: kLabel(AppColors.textPrimary,
                            size: 12.5, tracking: 0.06)),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(liveAsset.name,
                          overflow: TextOverflow.ellipsis,
                          style: kBody(AppColors.textSecondary, size: 11)),
                    ),
                  ]),
              const SizedBox(height: 3),
              Text('BALANCE ${liveAsset.formattedBalance}'.toUpperCase(),
                  style: kMonoText(AppColors.textSecondary, size: 10)),
            ]),
          ),
          if (canPick)
            Text('▾', style: kMonoText(AppColors.textTertiary, size: 12)),
        ]),
      ),
    );
  }

  /// The fee as one field-row: the quote and the speed, ▸ where a choice exists.
  Widget _feeRow(Asset asset) {
    final feeState = _watchCurrentFee();
    final hasSpeeds = _supportsSpeedSelector(asset.blockchain);

    Widget content;
    if (feeState == null) {
      content = Text('NOT AVAILABLE',
          style: kMonoText(AppColors.textTertiary, size: 11));
    } else {
      content = feeState.when(
        data: (fee) {
          if (fee == null) {
            return Text('FEE UNAVAILABLE · CHECK CONNECTION',
                style: kMonoText(AppColors.warning, size: 10));
          }
          final usd = fee.feeInUsd > 0
              ? '~ \$${fee.feeInUsd >= 0.01 ? fee.feeInUsd.toStringAsFixed(2) : fee.feeInUsd.toStringAsFixed(4)}'
              : '~ ${_fmt(fee.feeInNative, 8)} ${_gasTicker(asset.blockchain)}';
          return Text('$usd · ${_selectedSpeed.name.toUpperCase()}',
              style: kMonoText(AppColors.textSecondary, size: 11));
        },
        loading: () => Text('ESTIMATING…',
            style: kMonoText(AppColors.textTertiary, size: 11)),
        error: (e, _) => Text('FEE UNAVAILABLE · TAP TO RETRY',
            style: kMonoText(AppColors.warning, size: 10)),
      );
    }

    return AnimatedTap(
      onTap: () {
        final isError = feeState is AsyncError || feeState?.valueOrNull == null;
        if (isError) {
          _fetchFeeForAsset(asset);
        } else if (hasSpeeds) {
          _openSpeedSheet();
        }
      },
      pressScale: 0.99,
      pressOpacity: 0.9,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: AppColors.surface, border: kHairline()),
        child: Row(children: [
          content,
          const Spacer(),
          if (hasSpeeds)
            Text('▸', style: kMonoText(AppColors.textTertiary, size: 12)),
        ]),
      ),
    );
  }

  static String _gasTicker(String blockchain) => switch (blockchain) {
    'bitcoin' => 'BTC', 'ethereum' => 'ETH', 'bsc' => 'BNB',
    'ethereum_classic' => 'ETC', 'solana' => 'SOL', 'tron' => 'TRX',
    'litecoin' => 'LTC', 'bitcoin_cash' => 'BCH', _ => '',
  };

  void _openSpeedSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.borderHi, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 14),
            Container(width: 24, height: 2, color: AppColors.textTertiary),
            const SizedBox(height: 18),
            Text('NETWORK FEE',
                style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.18)),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: FeeSpeedSelector(
                selected: _selectedSpeed,
                onSelect: (s) {
                  Navigator.of(sheetCtx).pop();
                  _selectSpeed(s);
                },
              ),
            ),
            const SizedBox(height: 26),
          ]),
        ),
      ),
    );
  }
}

// ─── The asset sheet: the prototype's k-assetpick ─────────────────────────────
// Symbol and name lead, the price under them; quantity and value at the right edge.

class _AssetPickSheet extends StatelessWidget {
  const _AssetPickSheet({
    required this.assets,
    required this.selectedId,
    required this.onPick,
  });
  final List<Asset> assets;
  final String? selectedId;
  final ValueChanged<Asset> onPick;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.62;
    // Richest first. Choosing what to send starts from what there is to send, so the coins
    // holding real value sit at the top and the empty ones fall to the bottom — the same
    // order the wallet list defaults to.
    final ordered = [...assets]
      ..sort((a, b) {
        final byValue = b.balanceInUsd.compareTo(a.balanceInUsd);
        if (byValue != 0) return byValue;
        // Nothing in either: keep them steady rather than letting equal values shuffle.
        return a.symbol.compareTo(b.symbol);
      });
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderHi, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          Container(width: 24, height: 2, color: AppColors.textTertiary),
          const SizedBox(height: 18),
          Text('CHOOSE ASSET',
              style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.18)),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: ordered.length,
              itemBuilder: (_, i) {
                final a = ordered[i];
                final on = a.id == selectedId;
                return AnimatedTap(
                  onTap: () => onPick(a),
                  pressScale: 0.98,
                  pressOpacity: 0.85,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    decoration: BoxDecoration(
                      border: Border(
                        top: i == 0 ? kHairlineSide() : BorderSide.none,
                        bottom: kHairlineSide(),
                      ),
                    ),
                    child: Row(children: [
                      KoraSymbolBox(a.symbol),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: kLabel(AppColors.textPrimary,
                                      size: 12.5, tracking: 0.06)),
                              const SizedBox(height: 4),
                              Text('\$${a.priceUsd.toStringAsFixed(a.priceUsd >= 1 ? 2 : 4)}',
                                  style: kMonoText(
                                      AppColors.textSecondary, size: 10)),
                            ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(a.formattedBalance,
                                style: kNum(AppColors.textPrimary, size: 13.5)),
                            const SizedBox(height: 4),
                            Text(a.formattedUsdValue,
                                style: kMonoText(
                                    AppColors.textSecondary, size: 10)),
                          ]),
                      if (on) ...[
                        const SizedBox(width: 12),
                        Text('✓',
                            style:
                                kMonoText(AppColors.textPrimary, size: 12)),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }
}
