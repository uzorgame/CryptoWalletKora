import 'package:flutter/material.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/theme/app_theme.dart';

// The PIN pad. Digits, backspace, and an optional biometric slot — the lock screen's
// keyboard, kept in the library so the send flow's twin can fold into it when the redesign
// unifies them.

class Numpad extends StatelessWidget {
  const Numpad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.loading = false,
  });

  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              width: 72, height: 72,
              child: onBiometric != null
                  ? _NumBtn(
                      onTap: loading ? null : onBiometric,
                      child: Icon(Icons.fingerprint_rounded,
                          color: AppColors.textSecondary, size: 28),
                    )
                  : const SizedBox.shrink(),
            ),
            _NumBtn(
              label: '0',
              onTap: loading ? null : () => onDigit('0'),
            ),
            SizedBox(
              width: 72, height: 72,
              child: _NumBtn(
                onTap: loading ? null : onBackspace,
                child: loading
                    ? SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: AppColors.textPrimary, strokeWidth: 2))
                    : Icon(Icons.backspace_outlined,
                        color: AppColors.textSecondary, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((d) => _NumBtn(
                label: d,
                onTap: loading ? null : () => onDigit(d),
              ))
          .toList(),
    );
  }
}

class _NumBtn extends StatelessWidget {
  const _NumBtn({this.label, this.child, this.onTap});
  final String? label;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.88,
      pressOpacity: 0.65,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
        ),
        child: Center(
          child: label != null
              ? Text(
                  label!,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                  ),
                )
              : child,
        ),
      ),
    );
  }
}
