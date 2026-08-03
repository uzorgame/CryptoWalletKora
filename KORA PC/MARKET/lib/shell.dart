import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'format.dart';
import 'services/market_service.dart';
import 'theme.dart';
import 'views/chart_view.dart';
import 'views/market_grid.dart';
import 'views/table_view.dart';
import 'widgets/mark.dart';

enum MarketTab { market, chart, table }

/// The window: title bar with the tabs, the stage, and the status bar.
class MarketShell extends StatefulWidget {
  const MarketShell({super.key});

  @override
  State<MarketShell> createState() => _MarketShellState();
}

class _MarketShellState extends State<MarketShell> {
  MarketTab _tab = MarketTab.market;
  String _selected = kSymbols.first;

  /// Bumped every time a tab is entered. The prototype re-rendered a view's markup on each
  /// switch, which replayed its staggered entrance; keeping the widgets alive means the
  /// replay has to be asked for, and this counter is the ask.
  final Map<MarketTab, int> _entrance = {for (final t in MarketTab.values) t: 0};

  /// Which way the last navigation travelled, so a view always arrives from its own side.
  double _direction = 1;

  void _go(MarketTab next, {String? symbol}) {
    if (symbol != null) _selected = symbol;
    if (next == _tab) {
      if (symbol != null) setState(() {});
      return;
    }
    setState(() {
      _direction = next.index > _tab.index ? 1 : -1;
      _tab = next;
      _entrance[next] = _entrance[next]! + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          _TitleBar(tab: _tab, onTab: _go),
          Expanded(
            child: ClipRect(
              child: Stack(
                children: [
                  _stage(
                    MarketTab.market,
                    (beat) => MarketGrid(
                      beat: beat,
                      entrance: _entrance[MarketTab.market]!,
                      onOpen: (s) => _go(MarketTab.chart, symbol: s),
                    ),
                  ),
                  _stage(
                    MarketTab.chart,
                    (_) => ChartView(
                      symbol: _selected,
                      entrance: _entrance[MarketTab.chart]!,
                      onPick: (s) => setState(() => _selected = s),
                    ),
                  ),
                  _stage(
                    MarketTab.table,
                    (beat) => TableView(
                      beat: beat,
                      entrance: _entrance[MarketTab.table]!,
                      onOpen: (s) => _go(MarketTab.chart, symbol: s),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _StatusBar(),
        ],
      ),
    );
  }

  /// All three views stay alive so switching tabs never refetches a chart already loaded.
  /// Opacity and travel run on different clocks, exactly as the prototype's transition list
  /// does — the fade lands first and the slide settles after it.
  Widget _stage(MarketTab tab, Widget Function(int beat) build) {
    final on = _tab == tab;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !on,
        child: AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          curve: kEase,
          // Twenty pixels, not a fraction of the width — the prototype's offset is absolute,
          // and a proportional one would travel further on a maximised window.
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: on ? 0.0 : 20.0 * _direction),
            duration: const Duration(milliseconds: 420),
            curve: kEase,
            builder: (context, dx, inner) =>
                Transform.translate(offset: Offset(dx, 0), child: inner),
            // The boundary means the cross-fade composites a cached raster of each view
            // instead of re-rasterising twenty cards and a chart on every frame of the
            // transition — the layer an opacity animation forces has to come from somewhere.
            child: RepaintBoundary(child: _FeedBuilder(active: on, build: build)),
          ),
        ),
      ),
    );
  }
}

/// Rebuilds its view on the beat, but only while that view is the one on screen.
///
/// A single listener over all three views meant every ten-second commit rebuilt the grid, the
/// chart and the table together — two thirds of that work painting nothing anybody could see,
/// and all of it landing in the same frame as the flash animation starting. A view that comes
/// back into sight catches up once, on entry.
class _FeedBuilder extends StatefulWidget {
  const _FeedBuilder({required this.active, required this.build});

  final bool active;
  final Widget Function(int beat) build;

  @override
  State<_FeedBuilder> createState() => _FeedBuilderState();
}

class _FeedBuilderState extends State<_FeedBuilder> {
  int _beat = -1;

  @override
  void initState() {
    super.initState();
    _beat = MarketService.instance.beat;
    MarketService.instance.addListener(_onFeed);
  }

  @override
  void didUpdateWidget(_FeedBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _sync();
  }

  void _onFeed() {
    if (widget.active) _sync();
  }

  void _sync() {
    final beat = MarketService.instance.beat;
    if (beat == _beat || !mounted) return;
    setState(() => _beat = beat);
  }

  @override
  void dispose() {
    MarketService.instance.removeListener(_onFeed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.build(_beat);
}

// ── Title bar ─────────────────────────────────────────────────────────────────

class _TitleBar extends StatefulWidget {
  const _TitleBar({required this.tab, required this.onTab});

  final MarketTab tab;
  final void Function(MarketTab) onTab;

  @override
  State<_TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<_TitleBar> {
  final _rowKey = GlobalKey();
  final _tabKeys = {for (final t in MarketTab.values) t: GlobalKey()};
  final _rects = <MarketTab, Rect>{};

  static const _titles = {
    MarketTab.market: ('01', 'MARKET'),
    MarketTab.chart: ('02', 'CHART'),
    MarketTab.table: ('03', 'TABLE'),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// One element travels between tabs of different widths, rather than a border toggling on
  /// each — so its geometry has to come from the laid-out tabs, not from guessed constants.
  void _measure() {
    if (!mounted) return;
    final row = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (row == null || !row.hasSize) return;
    var changed = false;
    for (final entry in _tabKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero, ancestor: row) & box.size;
      if (_rects[entry.key] != rect) {
        _rects[entry.key] = rect;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final active = _rects[widget.tab];

    return Container(
      height: kTitlebarHeight,
      decoration: BoxDecoration(
        color: p.bgAlt,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          // The drag region deliberately stops at the tabs and picks up again after them.
          // Wrapping the whole bar made every tab a drag handle instead of a button — the
          // same trap `-webkit-app-region: no-drag` exists to solve in the prototype.
          DragToMoveArea(
            child: Row(
              children: [
                const SizedBox(width: 16),
                KoraMark(size: 18, color: p.text),
                const SizedBox(width: 10),
                Text('KORA MARKET', style: label(p.text, size: 11, tracking: 0.18)),
                const SizedBox(width: 18),
              ],
            ),
          ),
          Stack(
            key: _rowKey,
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tab in MarketTab.values)
                    _Tab(
                      key: _tabKeys[tab],
                      number: _titles[tab]!.$1,
                      title: _titles[tab]!.$2,
                      active: widget.tab == tab,
                      onTap: () => widget.onTab(tab),
                    ),
                ],
              ),
              if (active != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 380),
                  curve: kEase,
                  left: active.left,
                  width: active.width,
                  bottom: -1,
                  child: Container(height: 1, color: p.text),
                ),
            ],
          ),
          Expanded(child: DragToMoveArea(child: const SizedBox.expand())),
          // Theme first, then the window controls: one belongs to the app, the others to the
          // operating system, and the grouping should say so.
          _WinButton(onTap: ThemeNotifier.instance.toggle, builder: _ContrastIcon.new),
          _WinButton(
            onTap: windowManager.minimize,
            builder: (ink) => Container(width: 10, height: 1, color: ink),
          ),
          _WinButton(
            onTap: () async => await windowManager.isMaximized()
                ? windowManager.unmaximize()
                : windowManager.maximize(),
            builder: (ink) => Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(border: Border.all(color: ink)),
            ),
          ),
          _WinButton(
            danger: true,
            onTap: windowManager.close,
            builder: (ink) => _CloseIcon(color: ink),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    super.key,
    required this.number,
    required this.title,
    required this.active,
    required this.onTap,
  });

  final String number, title;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final ink = widget.active ? p.text : (_hover ? p.text2 : p.text3);
    // The number brightens with the tab but stays a step behind it, so the pair reads as
    // label and index rather than as two equal words.
    final numberInk = widget.active ? p.text2 : p.text3;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: kTitlebarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: kEase,
                  style: label(numberInk, size: 11, tracking: 0.12),
                  child: Text(widget.number),
                ),
                const SizedBox(width: 7),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: kEase,
                  style: label(ink, size: 11, tracking: 0.12),
                  child: Text(widget.title),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A window control.
///
/// The icon takes its colour from the button's own hover state, which is why the glyph is a
/// builder rather than a widget: an earlier version fixed the ink at construction, so the
/// mark stayed grey on a red close button. A Tooltip used to wrap this and swallowed exit
/// events between adjacent buttons, leaving two of them lit at once.
class _WinButton extends StatefulWidget {
  const _WinButton({required this.builder, required this.onTap, this.danger = false});

  final Widget Function(Color ink) builder;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final background = _hover ? (widget.danger ? p.down : p.surfaceHi) : Colors.transparent;
    final ink = _hover ? (widget.danger ? Colors.white : p.text) : p.text2;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: background),
          duration: const Duration(milliseconds: 180),
          curve: kEase,
          builder: (context, colour, child) => ColoredBox(
            color: colour ?? Colors.transparent,
            child: SizedBox(
              width: 44,
              height: kTitlebarHeight,
              child: Center(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: ink),
                  duration: const Duration(milliseconds: 180),
                  curve: kEase,
                  builder: (context, glyph, _) => widget.builder(glyph ?? ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two hairlines crossed, matching the prototype's ::before/::after construction rather than
/// a font glyph, so the stroke weight is the same one pixel as the minimise and maximise marks.
class _CloseIcon extends StatelessWidget {
  const _CloseIcon({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 12,
        height: 12,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(angle: 0.7854, child: Container(width: 12, height: 1, color: color)),
            Transform.rotate(angle: -0.7854, child: Container(width: 12, height: 1, color: color)),
          ],
        ),
      );
}

/// A circle filled on one side — the clearest two-state mark for a theme, and one that needs
/// no second asset for the opposite state.
class _ContrastIcon extends StatelessWidget {
  const _ContrastIcon(this.color, {super.key});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 12,
        height: 12,
        child: CustomPaint(painter: _ContrastPainter(color)),
      );
}

class _ContrastPainter extends CustomPainter {
  const _ContrastPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    canvas.drawArc(rect, -1.5708, 3.1416, true, Paint()..color = color);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ContrastPainter old) => old.color != color;
}

// ── Status bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatefulWidget {
  const _StatusBar();

  @override
  State<_StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<_StatusBar> with TickerProviderStateMixin {
  /// Two speeds, because the dot reports a state and not just a colour: a settled connection
  /// breathes slowly, one still trying beats at more than twice the rate, and a dead one does
  /// not move at all.
  static const _pulseLive = Duration(seconds: 2);
  static const _pulseTrying = Duration(milliseconds: 800);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _pulseLive,
  )..repeat(reverse: true);

  /// Fills across the beat, so the ten-second rhythm is visible rather than something the
  /// user has to infer from numbers that appear to have stopped.
  late final AnimationController _beat = AnimationController(vsync: this, duration: kBeat)
    ..repeat();

  Timer? _clock;
  DateTime _now = DateTime.now();
  int _seenBeat = -1;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    MarketService.instance.addListener(_onFeed);
  }

  void _onFeed() {
    final service = MarketService.instance;
    if (service.beat != _seenBeat) {
      _seenBeat = service.beat;
      _beat.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    MarketService.instance.removeListener(_onFeed);
    _clock?.cancel();
    _pulse.dispose();
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final service = MarketService.instance;
    final status = service.status;
    final live = status == FeedStatus.live;

    final dotColour = switch (status) {
      FeedStatus.live => p.up,
      FeedStatus.offline => p.down,
      // Amber for anything still trying — loading, connecting, reconnecting are the same
      // fact to a reader: there is no confirmed feed behind this number yet.
      _ => const Color(0xFFB58900),
    };

    final wantedPulse = status == FeedStatus.live ? _pulseLive : _pulseTrying;
    if (_pulse.duration != wantedPulse) {
      _pulse
        ..stop()
        ..duration = wantedPulse
        ..repeat(reverse: true);
    }
    if (status == FeedStatus.offline && _pulse.isAnimating) _pulse.stop();

    return Container(
      height: kStatusbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: p.bgAlt,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          // The indicator reports the socket, never an assumption: no stream, no LIVE.
          FadeTransition(
            opacity: status == FeedStatus.offline
                ? const AlwaysStoppedAnimation(1)
                : Tween<double>(begin: 1, end: 0.25)
                    .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
            child: Container(width: 5, height: 5, color: dotColour),
          ),
          const SizedBox(width: 9),
          Text(status.label, style: label(p.text3, size: 10)),
          const Spacer(),
          if (live) ...[
            // Painted rather than rebuilt: the bar advances every frame for as long as the
            // app is open, and a widget rebuild per frame forever is a poor way to move one
            // pixel row.
            SizedBox(
              width: 46,
              height: 1,
              child: CustomPaint(
                painter: _BeatPainter(progress: _beat, track: p.border, fill: p.text3),
              ),
            ),
            const SizedBox(width: 9),
            // Raw message count: the proof the connection is alive in the nine seconds when
            // nothing on screen is moving.
            Text('${service.rate}/s', style: label(p.text3, size: 10)),
            const SizedBox(width: 9),
          ],
          Text(clockOf(_now), style: label(p.text3, size: 10)),
        ],
      ),
    );
  }
}

/// The ten-second heartbeat, as one pixel row that fills and resets.
class _BeatPainter extends CustomPainter {
  _BeatPainter({required this.progress, required this.track, required this.fill})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color track, fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * progress.value, size.height),
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(_BeatPainter old) => old.track != track || old.fill != fill;
}
