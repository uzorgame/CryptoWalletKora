import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';

/// The wallet's monogram — the launcher icon's exact geometry, drawn live so it inverts with
/// the theme: the tile takes the ink colour, the K takes the background. Black becomes white,
/// white becomes black, the same rule the site's icon follows.
///
/// [radius] is zero by default — inside the app the language is square. The launcher tile's
/// rounding belongs to the launcher.
class KoraMark extends StatelessWidget {
  const KoraMark({super.key, this.size = 30, this.radius = 0});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(
          tile: AppColors.textPrimary,
          glyph: AppColors.background,
          radius: radius,
        ),
      );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.tile, required this.glyph, required this.radius});

  final Color tile;
  final Color glyph;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // The branding source draws on a 64-unit grid; everything scales off it.
    final u = size.width / 64;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      Paint()..color = tile,
    );
    final ink = Paint()..color = glyph;
    // The stem.
    canvas.drawRect(Rect.fromLTWH(17 * u, 16 * u, 7 * u, 32 * u), ink);
    // The chevron cut back toward the stem.
    final chevron = Path()
      ..moveTo(28 * u, 32 * u)
      ..lineTo(45 * u, 16 * u)
      ..lineTo(45 * u, 25 * u)
      ..lineTo(37 * u, 32 * u)
      ..lineTo(45 * u, 39 * u)
      ..lineTo(45 * u, 48 * u)
      ..close();
    canvas.drawPath(chevron, ink);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.tile != tile || old.glyph != glyph || old.radius != radius;
}
