import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

// The in-form number pad the send flow types amounts and PINs on.

class SendNumpad extends StatelessWidget {
  const SendNumpad({super.key, 
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
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _buildRow(['1', '2', '3']),
      const SizedBox(height: 12),
      _buildRow(['4', '5', '6']),
      const SizedBox(height: 12),
      _buildRow(['7', '8', '9']),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        SizedBox(
          width: 72, height: 72,
          child: onBiometric != null
              ? _SendNumBtn(
                  onTap: loading ? null : onBiometric,
                  child: Icon(Icons.fingerprint_rounded,
                      color: AppColors.textSecondary, size: 28),
                )
              : const SizedBox.shrink(),
        ),
        _SendNumBtn(label: '0', onTap: loading ? null : () => onDigit('0')),
        SizedBox(
          width: 72, height: 72,
          child: _SendNumBtn(
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
      ]),
    ]);
  }

  Widget _buildRow(List<String> digits) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: digits
        .map((d) => _SendNumBtn(label: d, onTap: loading ? null : () => onDigit(d)))
        .toList(),
  );
}

class _SendNumBtn extends StatelessWidget {
  const _SendNumBtn({this.label, this.child, this.onTap});
  final String? label;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AnimatedTap(
    onTap: onTap,
    pressScale: 0.88,
    pressOpacity: 0.65,
    child: Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
      ),
      child: Center(
        child: label != null
            ? Text(label!,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w400))
            : child,
      ),
    ),
  );
}
