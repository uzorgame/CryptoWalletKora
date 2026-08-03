import 'package:flutter/material.dart';

/// A month of daily closes, with the final point live.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.up,
    required this.down,
    this.width = 66,
    this.height = 20,
  });

  final List<double> values;
  final Color up;
  final Color down;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _SparkPainter(values, up, down)),
      );
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.values, this.up, this.down);

  final List<double> values;
  final Color up;
  final Color down;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final mid = (max + min) / 2;

    /*
     * A floor under the vertical scale, because pure auto-scaling turns nothing into drama:
     * USDC is pinned to a dollar, and stretching its hundredth-of-a-cent wobble to full
     * height drew a violent sawtooth on the calmest asset on the grid. Below a quarter
     * percent of range the line stays flat, which is what actually happened.
     */
    var span = max - min;
    final floor = mid.abs() * 0.0025;
    if (span < floor) span = floor;
    if (span <= 0) span = 1;

    final step = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final y = size.height / 2 - ((values[i] - mid) / span) * size.height;
      if (i == 0) {
        path.moveTo(0, y);
      } else {
        path.lineTo(i * step, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = (values.last >= values.first ? up : down).withValues(alpha: 0.85),
    );
  }

  /// Identity is not enough here. The beat writes the live price into the last slot of the
  /// existing list — `history[length - 1] = price` — so the reference never changes and a
  /// reference check reported "nothing moved" forever. Every sparkline in the grid was frozen
  /// on the shape it had at first paint.
  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.up != up ||
      old.down != down ||
      old.values.length != values.length ||
      (values.isNotEmpty && old.values.last != values.last) ||
      (values.isNotEmpty && old.values.first != values.first);
}
