import 'package:flutter/material.dart';

import 'curve_painter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kora_design.dart';
import '../../core/services/portfolio_chart_service.dart';
import '../common/kora_button.dart';
import '../format/moment.dart' as moment;
import '../format/money.dart';

/// The wallet's value over time.
///
/// Every point is the wallet as it actually stood: the quantity held then, at that day's
/// close. A deposit steps the line up because the wallet really did gain value, and before
/// the first deposit the line does not exist — an empty wallet is not a data point about a
/// wallet's performance.
class PortfolioChart extends StatefulWidget {
  const PortfolioChart({
    super.key,
    required this.series,
    required this.currencySymbol,
    this.onRetry,
    this.height = 172,
  });

  /// The curve as the provider holds it, loading and failure included.
  ///
  /// Deliberately not a plain list. There are three separate reasons this frame can have no
  /// line in it — the curve has not arrived, the request for it failed, or the wallet really
  /// has no history — and unwrapped at the screen all three arrived here as an empty list and
  /// were captioned NO HISTORY. Only the third of those is true.
  final AsyncValue<List<ChartPoint>> series;

  final String currencySymbol;

  /// Invalidates whatever provider produced [series].
  final VoidCallback? onRetry;

  final double height;

  @override
  State<PortfolioChart> createState() => _PortfolioChartState();
}

class _PortfolioChartState extends State<PortfolioChart> with SingleTickerProviderStateMixin {
  /// The line draws itself in, so a change of range reads as a redraw rather than a swap —
  /// the eye follows the change instead of hunting for what moved.
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  Path? _cached;
  Size? _cachedSize;
  List<ChartPoint>? _cachedFor;

  /// The series if there is one, and the same instance each time it is asked for — the path
  /// cache below is keyed on its identity.
  List<ChartPoint> get _points => widget.series.valueOrNull ?? const [];

  @override
  void didUpdateWidget(PortfolioChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Compared by content, not by identity.
    //
    // Identity was enough for a rebuild that hands back the list it was already holding, but
    // not for a recomputed one: the chart service builds a fresh List of fresh ChartPoints
    // every run, and ChartPoint carries no `==`, so two identical curves were never the same
    // curve. The three-minute balance poll republishes the wallet, the series recomputes to
    // the same shape, and the line erased itself and swept back in over a second — while the
    // user was doing nothing but reading the page.
    if (!_sameCurve(oldWidget.series.valueOrNull, widget.series.valueOrNull)) {
      _draw.forward(from: 0);
    }
  }

  /// Whether two series describe the same line.
  ///
  /// Endpoints and length rather than every point: the curve is a running total sampled at
  /// fixed intervals, so a change anywhere in it moves the last value, and the cases this has
  /// to separate are "the same window recomputed" from "a different range or newer data".
  static bool _sameCurve(List<ChartPoint>? a, List<ChartPoint>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    if (a.isEmpty) return true;
    return a.first.time == b.first.time &&
        a.last.time == b.last.time &&
        a.first.value == b.first.value &&
        a.last.value == b.last.value;
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  /// Built once per series and size rather than once per frame. Rebuilding a several-hundred
  /// point path sixty times a second is the whole cost of this animation.
  Path _pathFor(Size size, double min, double span) {
    final points = _points;
    if (_cached != null && _cachedSize == size && identical(_cachedFor, points)) {
      return _cached!;
    }
    const pad = 8.0;
    final inner = size.height - pad * 2;
    final step = size.width / (points.length - 1);
    double y(double v) => pad + inner - ((v - min) / span) * inner;

    final path = Path()..moveTo(0, y(points.first.value));
    for (var i = 1; i < points.length; i++) {
      path.lineTo(i * step, y(points[i].value));
    }
    _cached = path;
    _cachedSize = size;
    _cachedFor = points;
    return path;
  }

  /// What goes in the frame when there is no line to put there, and null when there is.
  Widget? _insteadOfCurve() {
    final series = widget.series;

    // A reload that still holds a curve keeps drawing it. A line that blinks out to a message
    // on every poll cannot be read, and the line it would be replacing is still true — this is
    // the one case where the last known answer beats the truth about the request.
    if (!(series.isLoading && series.hasValue)) {
      if (series.isLoading) return const _Notice(label: 'LOADING HISTORY…');
      if (series.hasError) {
        return _Notice(
          label: 'EXPLORER UNREACHABLE',
          body:
              'The value history could not be fetched. This is not a wallet without a past '
              '— it is a wallet that could not ask about one.',
          action: KoraButton(label: 'TRY AGAIN', onPressed: widget.onRetry),
        );
      }
    }

    // Checked whatever the state, and not only where the branches above fall through: a stale
    // single-point curve held through a reload would otherwise reach the painter, where one
    // point is a division by zero and none at all is a read off the end of the list.
    if (_points.length < 2) return const _Notice(label: 'NO HISTORY');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    if (_insteadOfCurve() case final notice?) {
      return _Frame(height: widget.height, child: notice);
    }

    final p = Kora.of(context);
    var min = points.first.value;
    var max = min;
    for (final point in points) {
      if (point.value < min) min = point.value;
      if (point.value > max) max = point.value;
    }
    final span = (max - min) == 0 ? 1.0 : max - min;
    final rising = points.last.value >= points.first.value;

    return _Frame(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, widget.height);
          return Stack(
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: CurvePainter(
                    path: _pathFor(size, min, span),
                    draw: _draw,
                    colour: rising ? p.up : p.down,
                    grid: p.border,
                  ),
                ),
              ),
              Positioned(
                top: 7,
                right: 10,
                child: Text(
                  money(max, widget.currencySymbol),
                  style: koraLabel(p.text3, size: 9.5, tracking: 0),
                ),
              ),
              Positioned(
                bottom: 7,
                right: 10,
                child: Text(
                  money(min, widget.currencySymbol),
                  style: koraLabel(p.text3, size: 9.5, tracking: 0),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 7,
                child: Text(
                  '${moment.day(points.first.time)} → ${moment.day(points.last.time)}',
                  style: koraLabel(p.text3, size: 9, tracking: 0.12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return Container(
      // A floor rather than a fixed height. The chart sizes itself to exactly this, but a
      // failure notice carries a sentence that wraps to three lines in a narrow window, and
      // under a fixed height that third line is painted outside the frame and clipped.
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }
}

/// What the frame says when it has no line to draw.
class _Notice extends StatelessWidget {
  const _Notice({required this.label, this.body, this.action});

  final String label;

  /// A sentence, for the states a label on its own would misstate.
  final String? body;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    // A bare label is a caption and stays quiet; one with a sentence under it is a failure the
    // user has to actually read, so it takes the brighter ink.
    final quiet = body == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: koraLabel(quiet ? p.text3 : p.text2, size: quiet ? 10 : 11, tracking: 0.18),
          ),
          if (body case final body?) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: koraBody(p.text3, size: 12).copyWith(height: 1.6),
              ),
            ),
          ],
          if (action case final action?) ...[const SizedBox(height: 18), action],
        ],
      ),
    );
  }
}
