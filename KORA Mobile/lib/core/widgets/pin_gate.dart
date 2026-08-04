import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/numpad.dart';

/// Asks for the app PIN and verifies it. Returns true only when the six digits entered
/// matched; false when the sheet was dismissed.
///
/// One gate for every action that must not happen by accident. It is deliberately not
/// dismissible by tapping outside: an action worth guarding is worth an explicit decision to
/// abandon.
Future<bool> askAppPin(
  BuildContext context, {
  required String title,
  required String explanation,
}) async =>
    (await askAppPinValue(context, title: title, explanation: explanation)) != null;

/// The same gate, returning the PIN that was verified rather than only whether it was.
///
/// Only for the callers that must hand the PIN onward — enabling biometric unlock stores it
/// so a fingerprint can decrypt the seed later. Everything else should use [askAppPin] and
/// never hold the digits at all.
Future<String?> askAppPinValue(
  BuildContext context, {
  required String title,
  required String explanation,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _PinGateSheet(title: title, explanation: explanation),
  );
}

class _PinGateSheet extends StatefulWidget {
  const _PinGateSheet({required this.title, required this.explanation});

  final String title;
  final String explanation;

  @override
  State<_PinGateSheet> createState() => _PinGateSheetState();
}

class _PinGateSheetState extends State<_PinGateSheet> {
  // Popped as the sheet's result once verified — see askAppPinValue.
  String _pin = '';
  bool _busy = false;
  String? _error;

  Future<void> _verify() async {
    setState(() => _busy = true);
    final ok = await KeyManager.verifyAppPin(_pin);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop(_pin);
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _busy = false;
        _pin = '';
        _error = 'Incorrect PIN. Try again.';
      });
    }
  }

  void _onDigit(String d) {
    if (_pin.length >= 6 || _busy) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 6) _verify();
  }

  void _onBackspace() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderHi, width: 1)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 30,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 24, height: 2, color: AppColors.textTertiary)),
          const SizedBox(height: 18),
          Text(widget.title.toUpperCase(),
              style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.18)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(widget.explanation.toUpperCase(),
                textAlign: TextAlign.center,
                style: kLabel(AppColors.textTertiary, size: 9, tracking: 0.12,
                        weight: FontWeight.w400)
                    .copyWith(height: 1.7)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              final filled = i < _pin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 10,
                height: 10,
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!.toUpperCase(),
                style: kLabel(AppColors.negative, size: 9, tracking: 0.08)),
          ] else
            const SizedBox(height: 24),
          const SizedBox(height: 8),
          Numpad(onDigit: _onDigit, onBackspace: _onBackspace, loading: _busy),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Text('CANCEL',
                style: kLabel(AppColors.textSecondary, size: 9.5, tracking: 0.16)),
          ),
        ]),
      ),
    );
  }
}
