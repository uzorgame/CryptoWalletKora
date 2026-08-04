import 'package:flutter/material.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';

// The PIN pad — a hairline grid whose one-pixel gaps are the border colour showing through,
// the same construction as every joined control in this language. Digits set in the display
// face. The API is untouched: digits, backspace, an optional biometric slot, and a loading
// flag that deadens the keys while a verification is in flight.
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(color: AppColors.border, border: kHairline()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(['1', '2', '3']),
          const SizedBox(height: 1),
          _row(['4', '5', '6']),
          const SizedBox(height: 1),
          _row(['7', '8', '9']),
          const SizedBox(height: 1),
          Row(children: [
            Expanded(
              child: onBiometric != null
                  ? _Key(
                      onTap: loading ? null : onBiometric,
                      child: Icon(Icons.fingerprint_rounded,
                          color: AppColors.textSecondary, size: 22),
                    )
                  : const _Key(onTap: null, child: SizedBox.shrink()),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: _Key(
                onTap: loading ? null : () => onDigit('0'),
                child: Text('0', style: kNum(AppColors.textPrimary, size: 19)),
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: _Key(
                onTap: loading ? null : onBackspace,
                child: Icon(Icons.backspace_outlined,
                    color: AppColors.textPrimary, size: 19),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _row(List<String> digits) => Row(children: [
        for (final (i, d) in digits.indexed) ...[
          if (i > 0) const SizedBox(width: 1),
          Expanded(
            child: _Key(
              onTap: loading ? null : () => onDigit(d),
              child: Text(d, style: kNum(AppColors.textPrimary, size: 19)),
            ),
          ),
        ],
      ]);
}

class _Key extends StatelessWidget {
  const _Key({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final key = Container(
      height: 54,
      color: AppColors.background,
      alignment: Alignment.center,
      child: child,
    );
    if (onTap == null) return key;
    return AnimatedTap(onTap: onTap, pressScale: 0.94, pressOpacity: 0.75, child: key);
  }
}
