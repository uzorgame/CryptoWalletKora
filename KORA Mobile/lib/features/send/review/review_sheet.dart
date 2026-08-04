import 'package:flutter/material.dart';
import 'package:kora/features/send/chain_labels.dart';
import 'package:flutter/services.dart';
import 'package:kora/core/services/biometric_service.dart';
import 'package:kora/core/services/storage_service.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/numpad.dart';
import 'package:kora/features/send/fee/models/fee_estimate.dart';

// The confirmation sheet: what is being sent, to whom, at what fee — and the PIN pad
// that signs it. The pad is the library's one Numpad; the send flow's private twin folded
// into it when the redesign unified the two.

class ReviewSheet extends StatefulWidget {
  const ReviewSheet({super.key,
    required this.asset,
    required this.to,
    required this.amount,
    required this.onConfirm,
    required this.onSuccess,
    this.feeEstimate,
  });
  final Asset asset;
  final String to;
  final String amount;
  final FeeEstimate? feeEstimate;
  final Future<(String?, String?)> Function(String pin) onConfirm;
  final void Function(String txHash) onSuccess;

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  String  _pin             = '';
  bool    _loading         = false;
  String? _error;
  bool    _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final enabled = await StorageService.readBool(StorageService.KEY_BIOMETRIC_ENABLED) ?? false;
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled);
    if (enabled) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    final result = await BiometricService.authenticate(
      reason: 'Confirm transaction in Kora Wallet',
      biometricOnly: false,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      final pin = await KeyManager.getPinForBiometric();
      if (!mounted) return;
      if (pin != null) {
        await _executeWithPin(pin);
      } else {
        setState(() {
          _loading = false;
          _error = 'Biometric PIN not set up. Please enter PIN manually.';
        });
      }
    } else if (result == BiometricResult.cancelled) {
      setState(() { _loading = false; });
    } else {
      setState(() { _loading = false; _error = result.message; });
    }
  }

  void _onDigit(String d) {
    if (_pin.length >= 6 || _loading) return;
    HapticFeedback.lightImpact();
    setState(() { _pin += d; _error = null; });
    if (_pin.length == 6) _executeWithPin(_pin);
  }

  void _onBackspace() {
    if (_pin.isEmpty || _loading) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _executeWithPin(String pin) async {
    setState(() { _loading = true; _error = null; });
    final (txHash, errMsg) = await widget.onConfirm(pin);
    if (mounted) {
      if (txHash != null) {
        Navigator.of(context).pop();
        widget.onSuccess(txHash);
      } else {
        setState(() {
          _loading = false;
          _pin = '';
          _error = errMsg ?? 'Incorrect PIN. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    final short = widget.to.length > 20
        ? '${widget.to.substring(0, 10)}…${widget.to.substring(widget.to.length - 8)}'
        : widget.to;

    // Format fee for display
    String feeText = '';
    if (widget.feeEstimate != null) {
      final fee = widget.feeEstimate!;
      final sym = feeSymbol(a.blockchain);
      String native;
      if (fee.feeInNative >= 1) {
        native = fee.feeInNative.toStringAsFixed(2);
      } else if (fee.feeInNative >= 0.001) {
        native = fee.feeInNative.toStringAsFixed(4);
      } else {
        native = fee.feeInNative.toStringAsFixed(8)
            .replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      }
      feeText = '$native $sym';
      if (fee.feeInUsd > 0) {
        final String usd;
        if (fee.feeInUsd >= 0.01) {
          usd = '\$${fee.feeInUsd.toStringAsFixed(2)}';
        } else if (fee.feeInUsd >= 0.0001) {
          usd = '\$${fee.feeInUsd.toStringAsFixed(4)}';
        } else {
          usd = '\$${fee.feeInUsd.toStringAsFixed(6)}'
              .replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
        }
        feeText += '  ($usd)';
      }
    }

    // Square, on a hairline: the sheet arrives as a surface of the same language, not as a
    // rounded Material card.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderHi, width: 1)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 22, right: 22, top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 30,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 24, height: 2, color: AppColors.textTertiary)),
          const SizedBox(height: 18),
          Text('CONFIRM TRANSACTION',
              style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.18)),
          const SizedBox(height: 18),

          // ── Static transaction summary ────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(border: kHairline()),
            child: Column(children: [
              _ReviewRow('Asset',  '${a.symbol} · ${netLabel(a.blockchain)}'),
              _ReviewRow('To',     short),
              _ReviewRow('Amount', '${widget.amount} ${a.symbol}',
                  last: feeText.isEmpty),
              if (feeText.isNotEmpty)
                _ReviewRow('Network Fee', feeText, last: true),
            ]),
          ),
          const SizedBox(height: 12),

          // The warning bar: hairline box, two pixels of amber down the left.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.warning, width: 2),
                top: kHairlineSide(), right: kHairlineSide(), bottom: kHairlineSide(),
              ),
            ),
            child: Text(
              'TRANSACTIONS ARE IRREVERSIBLE. VERIFY THE ADDRESS BEFORE CONFIRMING.',
              style: kLabel(AppColors.warning, size: 8.5, tracking: 0.08,
                      weight: FontWeight.w400)
                  .copyWith(height: 1.8),
            ),
          ),
          const SizedBox(height: 22),

          // ── Auth section ──────────────────────────────────────────────────
          Text(
            (_biometricEnabled ? 'Confirm with biometrics or PIN' : 'Enter PIN to confirm')
                .toUpperCase(),
            style: kLabel(AppColors.textTertiary, size: 9.5, tracking: 0.14),
          ),
          const SizedBox(height: 18),

          // PIN squares, as on the lock screen.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              final filled = i < _pin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: filled ? AppColors.textPrimary : Colors.transparent,
                  border: Border.all(
                    color: filled ? AppColors.textPrimary : AppColors.borderHi,
                    width: 1,
                  ),
                ),
              );
            }),
          ),

          // Error or spacer
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!.toUpperCase(),
                style: kLabel(AppColors.negative, size: 9, tracking: 0.08),
                textAlign: TextAlign.center),
          ] else
            const SizedBox(height: 24),

          const SizedBox(height: 8),

          Numpad(
            onDigit: _onDigit,
            onBackspace: _onBackspace,
            onBiometric: _biometricEnabled ? _tryBiometric : null,
            loading: _loading,
          ),
        ]),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value, {this.last = false});
  final String label, value;
  final bool last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(border: last ? null
        : Border(bottom: kHairlineSide())),
    child: Row(children: [
      Text(label.toUpperCase(),
          style: kMonoText(AppColors.textSecondary, size: 9.5)),
      const Spacer(),
      Flexible(child: Text(value, textAlign: TextAlign.right,
          style: kMonoText(AppColors.textPrimary, size: 11, weight: FontWeight.w500))),
    ]),
  );
}
