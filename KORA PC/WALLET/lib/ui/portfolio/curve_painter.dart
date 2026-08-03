import 'package:flutter/material.dart';

// The painter behind the portfolio curve.
//
// Split out of portfolio_chart.dart, which had grown past the point where one file held one
// idea: the chart is a frame, a range control and a set of states, and this is a path and two
// colours. It is coupled to nothing else — give it a Path and an Animation and it draws.

class CurvePainter extends CustomPainter {
  CurvePainter({required this.path, required this.draw, required this.colour, required this.grid})
    : super(repaint: draw);

  final Path path;
  final Animation<double> draw;
  final Color colour, grid;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = Curves.easeOutCubic.transform(draw.value);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in const [0.33, 0.66]) {
      final y = (size.height * f).roundToDouble();
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (progress > 0.2) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colour.withValues(alpha: 0.16 * progress),
              colour.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = colour;

    if (progress >= 1) {
      canvas.drawPath(path, stroke);
      return;
    }
    // A sweeping clip rather than path extraction. computeMetrics rebuilds and re-tessellates
    // the whole polyline every frame; because x only ever increases here, a clip is the same
    // reveal at a fraction of the cost.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    canvas.drawPath(path, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CurvePainter old) =>
      !identical(old.path, path) || old.colour != colour || old.grid != grid;
}
