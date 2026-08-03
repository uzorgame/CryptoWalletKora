import 'package:flutter/material.dart';

import '../format.dart';
import '../services/market_service.dart';
import '../theme.dart';

/// The chart, its range control, the coin picker and the stats band.
class ChartView extends StatefulWidget {
  const ChartView({
    super.key,
    required this.symbol,
    required this.entrance,
    required this.onPick,
  });

  final String symbol;

  /// Bumped when the tab is entered. The prototype redrew the chart on every switch, and the
  /// line redrawing itself is the whole reason the transition reads as arriving somewhere.
  final int entrance;

  final void Function(String symbol) onPick;

  @override
  State<ChartView> createState() => ChartViewState();
}

class ChartViewState extends State<ChartView> with TickerProviderStateMixin {
  /// The hint is scaffolding: it appears when the pointer is over the plot and retires the
  /// moment the gesture it describes is under way.
  late final AnimationController _hintFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  /// The line draws itself in, so switching coin or range reads as a redraw rather than a
  /// swap — the eye follows the change instead of hunting for what moved.
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  ChartRange _range = kRanges[2]; // 24H
  List<Candle> _series = const [];
  double _min = 0, _max = 0, _span = 1;
  bool _loading = true;
  int _load = 0; // guards against a slow response overwriting a newer one

  int? _scrubIndex;

  /// The plotted line, built once per series and size rather than once per frame.
  ///
  /// Nine hundred points on the fifteen-minute range meant nine hundred lineTo calls sixty
  /// times a second for the whole draw-in, rebuilding a path whose shape never changed.
  Path? _linePath;
  Size? _pathSize;
  List<Candle>? _pathFor;

  Path _pathAt(Size size) {
    if (_linePath != null && _pathSize == size && identical(_pathFor, _series)) {
      return _linePath!;
    }
    final step = size.width / (_series.length - 1);
    double y(double v) => size.height - ((v - _min) / _span) * size.height;
    final path = Path()..moveTo(0, y(_series.first.close));
    for (var i = 1; i < _series.length; i++) {
      path.lineTo(i * step, y(_series[i].close));
    }
    _linePath = path;
    _pathSize = size;
    _pathFor = _series;
    return path;
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(ChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      _fetch();
    } else if (widget.entrance != oldWidget.entrance && !_loading) {
      // Re-entering the tab replays the draw against data already in hand — no refetch, so
      // the animation costs a frame budget rather than a network round trip.
      _draw.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _hintFade.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final token = ++_load;
    setState(() {
      _loading = true;
      _scrubIndex = null;
    });
    final candles = await MarketService.instance
        .fetchCandles(widget.symbol, interval: _range.interval, limit: _range.limit);
    if (!mounted || token != _load) return;

    var min = double.infinity, max = -double.infinity;
    for (final c in candles) {
      if (c.close < min) min = c.close;
      if (c.close > max) max = c.close;
    }
    setState(() {
      _series = candles;
      _min = candles.isEmpty ? 0 : min;
      _max = candles.isEmpty ? 0 : max;
      _span = (max - min) == 0 ? 1 : max - min;
      _loading = false;
    });
    _draw.forward(from: 0);
  }

  void _pickRange(ChartRange r) {
    if (r.label == _range.label) return;
    setState(() => _range = r);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final coin = MarketService.instance.coins[widget.symbol]!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _head(p, coin),
          const SizedBox(height: 18),
          // The plot takes the room the fixed elements leave rather than a fixed 300, so the
          // window can be resized — or opened on a shorter display — without the stats band
          // being pushed off the bottom edge.
          Expanded(child: _plot(p)),
          const SizedBox(height: 18),
          _picker(p),
          const SizedBox(height: 18),
          // A fixed band under a flexible plot: the six figures need a constant amount of
          // room, and it is the chart that should absorb whatever is left over.
          SizedBox(height: 96, child: _stats(p, coin)),
        ],
      ),
    );
  }

  // ── Head ───────────────────────────────────────────────────────────────────

  Widget _head(Palette p, Coin coin) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(money(coin.price),
              style: numeric(p.text, size: 40, weight: FontWeight.w700)),
          const SizedBox(width: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(coin.symbol, style: label(p.text, size: 12, tracking: 0.1)),
              const SizedBox(height: 3),
              Text(coin.name, style: body(p.text3)),
            ],
          ),
          const SizedBox(width: 18),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(pct(coin.delta),
                style: label(p.direction(coin.delta), size: 12, tracking: 0)),
          ),
          const Spacer(),
          _segmented(
            p,
            kRanges.map((r) => r.label).toList(),
            _range.label,
            (label) => _pickRange(kRanges.firstWhere((r) => r.label == label)),
          ),
        ],
      );

  // ── Plot ───────────────────────────────────────────────────────────────────

  Widget _plot(Palette p) {
    if (_loading) {
      return _frame(p, Center(child: Text('LOADING', style: label(p.text3, size: 11, tracking: 0.18))));
    }
    if (_series.length < 2) {
      return _frame(p, Center(child: Text('NO DATA', style: label(p.text3, size: 11, tracking: 0.18))));
    }

    return _frame(
      p,
      LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;

          void scrub(Offset local) {
            final t = (local.dx / w).clamp(0.0, 1.0);
            final i = (t * (_series.length - 1)).round();
            if (i != _scrubIndex) setState(() => _scrubIndex = i);
          }

          return MouseRegion(
            cursor: SystemMouseCursors.precise,
            onEnter: (_) => _hintFade.forward(),
            onExit: (_) => _hintFade.reverse(),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              // Raw pointer events rather than a pan gesture: a pan only begins after the
              // pointer has travelled far enough to win the arena, so a press that means
              // "read here" would show nothing until the hand moved.
              onPointerDown: (e) => scrub(e.localPosition),
              onPointerMove: (e) => scrub(e.localPosition),
              onPointerUp: (_) => setState(() => _scrubIndex = null),
              onPointerCancel: (_) => setState(() => _scrubIndex = null),
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size(w, h),
                      painter: _ChartPainter(
                        path: _pathAt(Size(w, h)),
                        // Driving the painter from the animation directly repaints without
                        // rebuilding the widget above it every frame.
                        draw: _draw,
                        colour: _series.last.close >= _series.first.close ? p.up : p.down,
                        grid: p.border,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 8,
                    child: Text(money(_max), style: label(p.text3, size: 10, tracking: 0)),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 8,
                    child: Text(money(_min), style: label(p.text3, size: 10, tracking: 0)),
                  ),
                  if (_scrubIndex != null) ..._crosshair(p, w, h, _scrubIndex!),
                  Positioned(
                    left: 10,
                    bottom: 8,
                    child: AnimatedBuilder(
                      animation: _hintFade,
                      builder: (context, _) => Opacity(
                        opacity: _scrubIndex != null ? 0 : _hintFade.value * 0.6,
                        child: Text('HOLD AND DRAG TO INSPECT',
                            style: label(p.text3, size: 8.5, tracking: 0.16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _frame(Palette p, Widget child) => Container(
        decoration: BoxDecoration(color: p.surface, border: Border.all(color: p.border)),
        child: child,
      );

  /// Press and drag reads the series back out: the moment under the cursor, the price there,
  /// and how far it had moved from the start of the range by that point. The last part is the
  /// reason to scrub at all — a price alone says nothing without something to measure from.
  List<Widget> _crosshair(Palette p, double w, double h, int i) {
    final point = _series[i];
    final x = (i / (_series.length - 1)) * w;
    final y = ((_max - point.close) / _span) * h;
    final first = _series.first.close;
    final diff = point.close - first;
    final share = first == 0 ? 0.0 : (diff / first) * 100;
    final tone = p.direction(diff);

    // Flip rather than clamp: a panel pinned to the edge would sit on top of the very part
    // of the line the user dragged to.
    final flipX = x > w * 0.62;
    final flipY = y < h / 2;

    return [
      Positioned(
        left: x,
        top: 0,
        bottom: 0,
        child: Container(width: 1, color: p.text3.withValues(alpha: 0.5)),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: y,
        child: Container(height: 1, color: p.text3.withValues(alpha: 0.22)),
      ),
      Positioned(
        left: x - 3.5,
        top: y - 3.5,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: tone,
            border: Border.all(color: p.surface, width: 3),
          ),
        ),
      ),
      Positioned(
        left: flipX ? null : x + 13,
        right: flipX ? w - x + 13 : null,
        top: flipY ? null : 10,
        bottom: flipY ? 10 : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 132),
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 8),
          decoration: BoxDecoration(color: p.bg, border: Border.all(color: p.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(stamp(point.time, _range.label).toUpperCase(),
                  style: label(p.text3, size: 9.5, tracking: 0.1)),
              const SizedBox(height: 3),
              Text(money(point.close), style: numeric(p.text, size: 19)),
              const SizedBox(height: 4),
              Text('${pct(share)} · ${moneyDiff(diff, point.close)}',
                  style: label(tone, size: 10.5, tracking: 0)),
              const SizedBox(height: 3),
              Text('SINCE ${_range.label} OPEN', style: label(p.text3, size: 8.5, tracking: 0.14)),
            ],
          ),
        ),
      ),
    ];
  }

  // ── Picker and ranges ──────────────────────────────────────────────────────

  Widget _picker(Palette p) => _segmented(
        p,
        kSymbols,
        widget.symbol,
        widget.onPick,
        expand: true,
      );

  Widget _segmented(
    Palette p,
    List<String> items,
    String active,
    void Function(String) onTap, {
    bool expand = false,
  }) {
    final buttons = [
      for (final item in items)
        _SegButton(text: item, active: item == active, onTap: () => onTap(item)),
    ];
    return Container(
      color: p.border,
      // Wrapping, not scrolling: twenty tickers will not fit one row on a narrower window,
      // and a second row is honest where a clipped row would hide half the market.
      child: expand
          ? Wrap(spacing: 1, runSpacing: 1, children: buttons)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, b) in buttons.indexed) ...[
                  if (i > 0) const SizedBox(width: 1),
                  b,
                ],
              ],
            ),
    );
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  /// Six figures, and no more: the ones that change what you think about a coin you are
  /// already looking at. Four are recomputed from the live price on every beat, so the band
  /// is part of the quote rather than a static footnote under it.
  Widget _stats(Palette p, Coin coin) {
    final cap = coin.marketCap;
    final fromAth = coin.fromAth;
    final tiles = <(String, String, Color?)>[
      ('MARKET CAP', cap == null ? '—' : '\$${compact(cap)}', null),
      ('24H VOLUME', coin.volume > 0 ? '\$${compact(coin.volume)}' : '—', null),
      ('24H HIGH', money(coin.high), null),
      ('24H LOW', money(coin.low), null),
      ('CIRCULATING', coin.supply == null ? '—' : '${compact(coin.supply)} ${coin.symbol}', null),
      ('FROM ATH', fromAth == null ? '—' : pct(fromAth),
          fromAth == null ? null : p.direction(fromAth)),
    ];

    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      decoration: BoxDecoration(color: p.border, border: Border.all(color: p.border)),
      child: Row(
        children: [
          for (final (i, tile) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: 1),
            Expanded(
              child: Container(
                color: p.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(tile.$1, style: label(p.text3, size: 9, tracking: 0.14)),
                    const SizedBox(height: 8),
                    // FROM ATH can cross zero and change colour; easing that keeps the band
                    // from blinking on a beat where the sign happened to flip.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        curve: kEase,
                        style: numeric(tile.$3 ?? p.text, size: 21),
                        child: Text(tile.$2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Segmented button ──────────────────────────────────────────────────────────

class _SegButton extends StatefulWidget {
  const _SegButton({required this.text, required this.active, required this.onTap});

  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_SegButton> createState() => _SegButtonState();
}

class _SegButtonState extends State<_SegButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final background = widget.active ? p.text : (_hover ? p.surfaceHi : p.surface);
    final ink = widget.active ? p.bg : (_hover ? p.text : p.text3);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: kEase,
          color: background,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          // The label travels with the fill rather than snapping ahead of it, which is what
          // the prototype's paired colour/background transition does.
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: kEase,
            style: label(ink, size: 10, tracking: 0.08),
            child: Text(widget.text),
          ),
        ),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.path,
    required this.draw,
    required this.colour,
    required this.grid,
  }) : super(repaint: draw);

  /// Built by the view and reused across the whole animation.
  final Path path;
  final Animation<double> draw;
  final Color colour, grid;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = Curves.easeOutCubic.transform(draw.value);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in const [0.25, 0.5, 0.75]) {
      final y = (size.height * f).roundToDouble();
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // The fill fades in behind the stroke as it draws, so the area never leads the line.
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
            colors: [colour.withValues(alpha: 0.14 * progress), colour.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = colour;

    /*
     * The reveal is a clip, not a path extraction.
     *
     * computeMetrics + extractPath rebuilds and re-tessellates the whole polyline on every
     * frame of the animation — up to nine hundred points, sixty times a second, allocating a
     * fresh Path each time. That is the stutter felt on opening the chart. Because x is
     * strictly increasing here, sweeping a clip rectangle left to right is visually the same
     * reveal at a fraction of the cost; only the pacing differs, and then only where a
     * segment is near-vertical.
     */
    if (progress >= 1) {
      canvas.drawPath(path, strokePaint);
      return;
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    canvas.drawPath(path, strokePaint);
    canvas.restore();
  }

  /// The animation is wired through `repaint:`, so it drives frames on its own; this only has
  /// to catch the things the animation does not know about.
  @override
  bool shouldRepaint(_ChartPainter old) =>
      !identical(old.path, path) || old.colour != colour || old.grid != grid;
}
