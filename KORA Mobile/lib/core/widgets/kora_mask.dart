import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';

/// A hidden figure: a run of small squares where the number was.
///
/// Squares, not dots — this application has no circles in it.
///
/// [textSize] is the size of the type being replaced, and it is what makes hiding a balance
/// free of consequence: the mask reserves exactly the line box that text occupied, so the
/// rows below do not walk up the screen the moment the eye is closed. The squares themselves
/// are a fraction of that, matching the prototype's `.kmask i { width: .42em }`.
class KoraMask extends StatelessWidget {
  const KoraMask({
    super.key,
    this.count = 4,
    required this.textSize,
    this.color,
  });

  final int count;

  /// The font size of the figure this mask stands in for.
  final double textSize;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? AppColors.textPrimary;
    final box = textSize * 0.42;
    return SizedBox(
      // The line height display numerals carry (kNum uses 1.1); reserving it keeps every
      // element under a hidden balance exactly where it was.
      height: textSize * 1.1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) SizedBox(width: box * 0.55),
            Container(width: box, height: box, color: ink),
          ],
        ],
      ),
    );
  }
}
