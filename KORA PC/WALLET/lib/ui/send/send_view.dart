import 'package:flutter/material.dart';

import '../common/smooth_scroll.dart';

import '../../core/models/asset.dart';
import '../../core/theme/kora_design.dart';
import '../common/kora_button.dart';
import '../common/kora_field.dart';
import '../common/section_header.dart';
import '../common/segmented_control.dart';
import '../format/chain_display.dart';
import '../../core/state/providers/currency_provider.dart';
import '../format/currency_format.dart';
import '../format/money.dart';
import 'fee_option.dart';

/// What the form produces when the user asks to review it.
class SendRequest {
  const SendRequest({
    required this.asset,
    required this.recipient,
    required this.amount,
    required this.fee,
  });

  final Asset asset;
  final String recipient;
  final double amount;
  final FeeOption fee;
}

/// An outgoing transaction.
///
/// The form validates as it goes and keeps its action unavailable until it would succeed. A
/// wallet that lets a transaction be submitted and then explains why it could not be sent has
/// wasted the one moment when the user was paying attention.
class SendView extends StatefulWidget {
  const SendView({
    super.key,
    required this.assets,
    required this.selected,
    required this.walletId,
    required this.fees,
    required this.money,
    required this.onSelectAsset,
    required this.onReview,
    this.onFeeTier,
    this.validateAddress,
    this.busy = false,
    this.failure,
    this.sentCount = 0,
  });

  /// Straight from the asset provider — the same objects the send engine will be handed.
  final List<Asset> assets;
  final Asset selected;

  /// Which wallet this form is spending from.
  ///
  /// Not used to look anything up — it is here so the form can tell that the money underneath
  /// it changed. Asset ids repeat across wallets, so a switch between two wallets that both
  /// hold BTC changes nothing else this widget can see.
  final String? walletId;

  final List<FeeOption> fees;
  final CurrencyState money;

  final ValueChanged<Asset> onSelectAsset;
  final ValueChanged<SendRequest> onReview;

  /// The chosen tier's id, so the screen can ask the fee provider for that tier's estimate.
  /// Without this the picker would change a label and nothing else.
  final ValueChanged<String>? onFeeTier;

  /// Per-chain address checking, from the executor that will have to use the address.
  /// Returns a reason it is unacceptable, or null.
  final String? Function(String address)? validateAddress;

  /// True while a transaction is being signed or broadcast.
  final bool busy;

  /// Why the last attempt did not go through. Shown beside the action rather than in a
  /// dialog: the form is still filled in, and the reason belongs next to what caused it.
  final String? failure;

  /// How many transactions this screen has broadcast. The form clears whenever it goes up —
  /// a hash alone could repeat, and a bool could not express "again".
  final int sentCount;

  @override
  State<SendView> createState() => _SendViewState();
}

class _SendViewState extends State<SendView> {
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  FeeOption? _fee;

  @override
  void initState() {
    super.initState();
    _recipient.addListener(_onChanged);
    _amount.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(SendView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different coin means a different chain, and an address for the old chain is not
    // merely wrong here — following it would lose the funds.
    //
    // A completed send clears the form for a different reason: the recipient and the amount
    // are still on screen and the button is live again, so one more press sends the same
    // money to the same place a second time. There is no undo for that.
    if (oldWidget.selected.id != widget.selected.id ||
        oldWidget.walletId != widget.walletId ||
        widget.sentCount != oldWidget.sentCount) {
      _recipient.clear();
      _amount.clear();
      _fee = null;
    }
  }

  @override
  void dispose() {
    _recipient.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// The middle tier, chosen for the user until they say otherwise. Resolved on read rather
  /// than stored, because the estimates arrive after the form is first built.
  FeeOption? get _selectedFee {
    if (widget.fees.isEmpty) return null;
    final chosen = _fee;
    if (chosen == null) return widget.fees[widget.fees.length ~/ 2];
    return widget.fees.firstWhere((f) => f.id == chosen.id, orElse: () => widget.fees.first);
  }

  double? get _parsedAmount {
    final text = _amount.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  /// The coin the network fee is actually paid in.
  ///
  /// For a token that is not the asset being sent: a USDT transfer costs TRX. Null when the
  /// wallet does not hold the chain's native coin at all, which is itself the answer to
  /// "can this fee be paid".
  Asset? get _feeAsset {
    final selected = widget.selected;
    if (selected.type == AssetType.native) return selected;
    return widget.assets
        .where((a) => a.blockchain == selected.blockchain && a.type == AssetType.native)
        .firstOrNull;
  }

  /// The fee in the chain's own coin, once the chain has actually said what it is.
  double? get _feeNative {
    final fee = _selectedFee;
    if (fee == null || fee.status != FeeStatus.ready) return null;
    return fee.native;
  }

  /// The largest amount that can be sent and still leave the fee payable.
  ///
  /// For a native coin the fee comes out of the same balance, so it has to be held back. A
  /// transaction that spends the balance to the last unit is not merely rejected by the node —
  /// on a UTXO chain it is rejected after the wallet has already shown it as sent.
  double get _sendable {
    final available = widget.selected.balanceAsDouble;
    if (widget.selected.type != AssetType.native) return available;
    final fee = _feeNative ?? 0;
    final headroom = available - fee;
    return headroom > 0 ? headroom : 0;
  }

  /// Why the fee cannot be paid, independent of the amount typed.
  ///
  /// Separate from [_amountProblem] because it is true before anything has been typed: a
  /// wallet holding USDT and no TRX cannot send that USDT at all, and saying so at the top of
  /// the form is kinder than saying it after the address has been pasted in.
  String? get _feeProblem {
    final fee = _feeNative;
    if (fee == null || fee <= 0) return null;
    if (widget.selected.type == AssetType.native) return null;

    final feeAsset = _feeAsset;
    if (feeAsset == null) {
      return 'This transfer is paid for in ${_selectedFee?.symbol ?? widget.selected.chain.tag}, '
          'which this wallet does not hold.';
    }
    if (feeAsset.balanceAsDouble < fee) {
      return 'Needs about ${quantity(fee)} ${feeAsset.symbol} for the network fee; '
          '${quantity(feeAsset.balanceAsDouble)} held.';
    }
    return null;
  }

  String? get _amountProblem {
    if (_amount.text.trim().isEmpty) return null;
    final value = _parsedAmount;
    if (value == null) return 'That is not a number.';
    if (value <= 0) return 'Enter an amount above zero.';
    final available = widget.selected.balanceAsDouble;
    if (value > available) {
      return 'More than the ${quantity(available)} ${widget.selected.symbol} available.';
    }
    // The fee is not a separate pot. Accepting the whole balance here meant the form said yes
    // and the chain said no, after the one moment the user was paying attention.
    if (value > _sendable) {
      final fee = _feeNative ?? 0;
      return 'Leave ${quantity(fee)} ${widget.selected.symbol} for the network fee — '
          '${quantity(_sendable)} can be sent.';
    }
    return null;
  }

  String? get _addressProblem {
    final text = _recipient.text.trim();
    if (text.isEmpty) return null;
    return widget.validateAddress?.call(text);
  }

  /// Whether the transaction can be signed.
  ///
  /// The fee must have arrived, not merely have a cell on screen. A `FeeOption` exists from
  /// the first frame and carries a null cost while the chain is still being asked — signing
  /// then hands the executor no rate, and the UTXO executor quietly falls back to an internal
  /// guess. The user would have agreed to a fee that was never shown to them.
  bool get _ready =>
      !widget.busy &&
      _selectedFee != null &&
      _selectedFee!.status == FeeStatus.ready &&
      _selectedFee!.cost != null &&
      _recipient.text.trim().isNotEmpty &&
      _addressProblem == null &&
      _parsedAmount != null &&
      _amountProblem == null &&
      _feeProblem == null;

  String get _amountHint {
    final problem = _amountProblem;
    if (problem != null) return problem;
    final value = _parsedAmount;
    if (value == null) return '—';
    final price = widget.selected.priceUsd;
    if (price == 0) return '—';
    return '${widget.money.format(value * price)} at the current price';
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final chain = selected.chain;
    // Held first, then anything only being watched. A list that opens on an empty coin asks
    // the user to notice the balance before the name.
    final ordered = [...widget.assets]
      ..sort((a, b) {
        final aEmpty = a.balanceAsDouble <= 0;
        final bEmpty = b.balanceAsDouble <= 0;
        if (aEmpty != bEmpty) return aEmpty ? 1 : -1;
        return b.balanceInUsd.compareTo(a.balanceInUsd);
      });

    return SmoothScrollView(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'SEND'),
          const SizedBox(height: 20),
          _AssetField(
            assets: ordered,
            selected: selected,
            money: widget.money,
            onSelect: widget.onSelectAsset,
          ),
          const SizedBox(height: 18),
          KoraField(
            label: 'RECIPIENT',
            controller: _recipient,
            placeholder: 'Address on ${chain.network}',
            error: _addressProblem != null,
            hint:
                _addressProblem ??
                'Network ${chain.network} (${chain.tag}). An address from another chain '
                    'will be rejected.',
          ),
          const SizedBox(height: 18),
          KoraField(
            label: 'AMOUNT',
            controller: _amount,
            placeholder: '0.00',
            error: _amountProblem != null,
            hint: _amountHint,
            // Sending everything is a thing people genuinely want to do, and doing it by hand
            // means either subtracting the fee themselves or being rejected by the node.
            trailing: _sendable > 0
                ? _MaxButton(
                    onTap: () {
                      _amount.text = quantity(_sendable);
                      _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
                    },
                  )
                : null,
          ),
          const SizedBox(height: 18),
          _FeeField(
            options: widget.fees,
            selected: _selectedFee,
            money: widget.money,
            onSelect: (option) {
              setState(() => _fee = option);
              widget.onFeeTier?.call(option.id);
            },
          ),
          if (_feeProblem case final problem?) ...[
            const SizedBox(height: 9),
            Text(problem, style: koraLabel(Kora.of(context).down, size: 9.5, tracking: 0)),
          ],
          const SizedBox(height: 22),
          KoraButton(
            // The button says why it is unavailable rather than sitting dead. A disabled
            // control with no explanation is the thing people read as "broken".
            label: switch (true) {
              _ when widget.busy => 'SENDING…',
              _ when _selectedFee?.status == FeeStatus.loading => 'WAITING FOR THE FEE…',
              _ when _selectedFee?.status == FeeStatus.unavailable => 'FEE UNAVAILABLE',
              _ => 'REVIEW TRANSACTION',
            },
            tone: KoraButtonTone.primary,
            expand: true,
            onPressed: _ready
                ? () => widget.onReview(
                    SendRequest(
                      asset: selected,
                      recipient: _recipient.text.trim(),
                      amount: _parsedAmount!,
                      fee: _selectedFee!,
                    ),
                  )
                : null,
          ),
          if (widget.failure != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.failure!,
              textAlign: TextAlign.center,
              style: koraLabel(Kora.of(context).down, size: 9.5, tracking: 0),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssetField extends StatelessWidget {
  const _AssetField({
    required this.assets,
    required this.selected,
    required this.money,
    required this.onSelect,
  });

  final List<Asset> assets;
  final Asset selected;
  final CurrencyState money;
  final ValueChanged<Asset> onSelect;

  /// A ticker is only unique on its own chain, so the chain is part of the name here. Native
  /// coins keep the bare ticker: there is one BTC, and "BTC · BITCOIN" would be noise.
  static String _label(Asset asset) =>
      asset.type == AssetType.token ? '${asset.symbol} · ${asset.chain.tag}' : asset.symbol;

  @override
  Widget build(BuildContext context) {
    final available = selected.balanceAsDouble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('ASSET'),
        const SizedBox(height: 7),
        SegmentedControl(
          wrap: true,
          // Labelled by ticker AND chain, because a ticker alone is not unique: USDT exists on
          // Ethereum, Tron and BSC, and the control keys its cells by the label string. Three
          // cells reading "USDT" collapsed to one selectable entry, which is why the picker
          // looked as though most networks were missing.
          options: [for (final a in assets) _label(a)],
          selected: _label(selected),
          disabled: {for (final a in assets.where((a) => a.balanceAsDouble <= 0)) _label(a)},
          onSelect: (label) => onSelect(assets.firstWhere((a) => _label(a) == label)),
        ),
        const SizedBox(height: 7),
        // A greyed-out coin reads as "not supported" when it actually means "you hold none of
        // it". Every chain in the catalogue can be sent from; the only thing stopping these is
        // an empty balance, and saying so is the difference between a limitation and a bug.
        _FieldHint(
          available > 0
              ? 'Available ${quantity(available)} ${selected.symbol} · '
                    '${money.format(selected.balanceInUsd)}'
              : 'No ${selected.symbol} to send. Coins without a balance are greyed out.',
        ),
      ],
    );
  }
}

class _FeeField extends StatelessWidget {
  const _FeeField({
    required this.options,
    required this.selected,
    required this.money,
    required this.onSelect,
  });

  final List<FeeOption> options;
  final FeeOption? selected;
  final CurrencyState money;
  final ValueChanged<FeeOption> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _FieldLabel('NETWORK FEE'),
      const SizedBox(height: 7),
      if (options.isEmpty || selected == null)
        const _FieldHint('Estimating the network fee…')
      else
        FeePicker(options: options, selectedId: selected!.id, money: money, onSelect: onSelect),
    ],
  );
}

/// The field label and hint, matching KoraField exactly — a control that is not a text input
/// still has to sit in the same rhythm as the ones around it.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: koraLabel(Kora.of(context).text3, size: 9.5, tracking: 0.14));
}

class _FieldHint extends StatelessWidget {
  const _FieldHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: koraLabel(Kora.of(context).text3, size: 9.5, tracking: 0));
}

/// Fills the amount with everything that can be sent.
///
/// Inside the amount field rather than beside it: it is not a decision about the transaction,
/// it is a way of typing a number.
class _MaxButton extends StatefulWidget {
  const _MaxButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_MaxButton> createState() => _MaxButtonState();
}

class _MaxButtonState extends State<_MaxButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: AnimatedDefaultTextStyle(
            duration: kControl,
            curve: kEase,
            style: koraLabel(_hover ? p.text : p.text3, size: 9.5, tracking: 0.16),
            child: const Text('MAX'),
          ),
        ),
      ),
    );
  }
}
