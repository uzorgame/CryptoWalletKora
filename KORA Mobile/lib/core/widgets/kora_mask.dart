import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';

/// A hidden figure: a run of small squares where the number was.
///
/// Squares, not dots — this application has no circles in it. Sized in fractions of the text
/// they replace so the mask reads at the same weight as the figure it hides.
class KoraMask extends StatelessWidget {
  const KoraMask({super.key, this.count = 4, this.size = 6, this.color});

  final int count;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(width: size * 0.8),
          Container(width: size, height: size, color: ink),
        ],
      ],
    );
  }
}
