import 'package:flutter/material.dart';

/// The approved K monogram, drawn rather than loaded.
///
/// As geometry it takes the theme's ink and stays sharp at any size, which a bitmap asset
/// would not: the same shape serves an eighteen-pixel titlebar and a sixty-two-pixel splash.
class KoraMark extends StatelessWidget {
  const KoraMark({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _MarkPainter(color)),
      );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Authored on a 64-unit canvas; everything else is a scale of that.
    final k = size.width / 64;
    final paint = Paint()..color = color;

    canvas.drawRect(Rect.fromLTWH(17 * k, 16 * k, 7 * k, 32 * k), paint);

    final arm = Path()
      ..moveTo(28 * k, 32 * k)
      ..lineTo(45 * k, 16 * k)
      ..lineTo(45 * k, 25 * k)
      ..lineTo(37 * k, 32 * k)
      ..lineTo(45 * k, 39 * k)
      ..lineTo(45 * k, 48 * k)
      ..close();
    canvas.drawPath(arm, paint);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
