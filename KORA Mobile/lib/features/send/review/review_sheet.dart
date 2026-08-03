import 'package:flutter/material.dart';
import 'package:kora/features/send/chain_labels.dart';
import 'package:flutter/services.dart';
import 'package:kora/core/services/biometric_service.dart';
import 'package:kora/core/services/storage_service.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/features/send/fee/models/fee_estimate.dart';
import 'package:kora/features/send/widgets/send_numpad.dart';

// The confirmation sheet: what is being sent, to whom, at what fee — and the PIN pad
// that signs it.

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

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Center(child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: AppColors.border, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 20),
        Text('Review Transaction',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        // ── Static transaction summary ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(children: [
            _ReviewRow('Asset',  '${a.symbol}  ·  ${netLabel(a.blockchain)}'),
            _ReviewRow('To',     short),
            _ReviewRow('Amount', '${widget.amount} ${a.symbol}',
                last: feeText.isEmpty),
            if (feeText.isNotEmpty)
              _ReviewRow('Network Fee', feeText, last: true),
          ]),
        ),
        const SizedBox(height: 12),

        // Warning
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.25), width: 0.5),
          ),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Transactions are irreversible. Verify the address before confirming.',
              style: TextStyle(color: AppColors.warning, fontSize: 11, height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Auth section ──────────────────────────────────────────────────
        Text(
          _biometricEnabled ? 'Confirm with biometrics or PIN' : 'Enter PIN to confirm',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            final filled = i < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.textPrimary : Colors.transparent,
                border: Border.all(
                  color: filled ? AppColors.textPrimary : AppColors.textTertiary,
                  width: 1.5,
                ),
              ),
            );
          }),
        ),

        // Error or spacer
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: AppColors.negative, fontSize: 12),
              textAlign: TextAlign.center),
        ] else
          const SizedBox(height: 28),

        const SizedBox(height: 8),

        // PIN numpad
        SendNumpad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          onBiometric: _biometricEnabled ? _tryBiometric : null,
          loading: _loading,
        ),
      ]),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value, {this.last = false});
  final String label, value;
  final bool last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(border: last ? null
        : Border(bottom: BorderSide(color: AppColors.separator, width: 0.5))),
    child: Row(children: [
      Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const Spacer(),
      Flexible(child: Text(value, textAlign: TextAlign.right,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
}
