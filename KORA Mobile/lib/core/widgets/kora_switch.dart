import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

/// A two-state switch in this wallet's language.
///
/// Material's switch is a pill with a travelling circle — two shapes this application does
/// not contain. This is the same idea drawn with the parts everything else is drawn with: a
/// hairline track and a square of ink that moves from one end to the other, inverting the
/// track when it lands. Off, the track is a plain hairline with a hollow square; on, the
/// track fills and the square becomes the background showing through. It travels over
/// [kControl] on the house curve, so switching reads as a movement rather than a repaint.
class KoraSwitch extends StatelessWidget {
  const KoraSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  static const double _w = 40;
  static const double _h = 22;
  static const double _knob = 14;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: () => onChanged(!value),
      pressScale: 0.92,
      child: AnimatedContainer(
        duration: kControl,
        curve: kEase,
        width: _w,
        height: _h,
        decoration: BoxDecoration(
          color: value ? AppColors.textPrimary : Colors.transparent,
          border: Border.all(
            color: value ? AppColors.textPrimary : AppColors.borderHi,
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: kControl,
          curve: kEase,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: kControl,
              curve: kEase,
              width: _knob,
              height: _knob,
              decoration: BoxDecoration(
                color: value ? AppColors.background : Colors.transparent,
                border: Border.all(
                  color: value ? AppColors.background : AppColors.textTertiary,
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
