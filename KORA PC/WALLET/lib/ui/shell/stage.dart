import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';
import 'nav_destination.dart';

/// The area the rail navigates, and the transition between its views.
///
/// Three rules, all learned the hard way:
///
/// A view is not built until it is first visited. The shell this replaces used an
/// IndexedStack, which builds and lays out every child immediately — so the transactions
/// screen issued its network calls before the first frame of the portfolio had been painted.
///
/// Once built, a view stays alive. Rebuilding it on every visit would throw away a loaded
/// chart and a scroll position for no gain.
///
/// And only the view being looked at is rebuilt. This one was written down here before it was
/// true: the build method re-invoked every visited builder on every pass, so one click on the
/// rail rebuilt all four screens — the three at zero opacity included — and so did every
/// balance poll, every price tick and every currency change. With a full portfolio and a
/// merged history that is upwards of a thousand widgets and as many text layouts in a single
/// frame. It is the reason the app felt heavy.
///
/// Caching the widget is safe because every screen is a `ConsumerWidget`: Riverpod marks its
/// element dirty directly when the providers it watches change, whatever the parent hands
/// back. The cache is only about who does the work, never about whether the screen is current.
class Stage extends StatefulWidget {
  const Stage({super.key, required this.current, required this.builders});

  final NavDestination current;

  /// One builder per destination. Invoked for the current destination, and for any other
  /// destination that has not been built yet.
  final Map<NavDestination, WidgetBuilder> builders;

  @override
  State<Stage> createState() => _StageState();
}

class _StageState extends State<Stage> {
  late final Set<NavDestination> _visited = {widget.current};

  /// The last widget built for each visited destination.
  final Map<NavDestination, Widget> _built = {};

  double _direction = 1;

  @override
  void didUpdateWidget(Stage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      // A view arrives from the side its destination sits on, so the movement matches the
      // rail rather than being an arbitrary direction.
      _direction = widget.current.index > oldWidget.current.index ? 1 : -1;
      _visited.add(widget.current);
      // Arriving somewhere is exactly when its constructor arguments matter — the entrance
      // counter that replays the row stagger, above all — so the incoming view is rebuilt
      // once, here, rather than on every frame it is not being looked at.
      _built.remove(widget.current);
    }
  }

  /// The widget for a destination: freshly built if it is the one on screen, otherwise the
  /// one from last time.
  Widget _view(NavDestination destination) {
    if (destination == widget.current || !_built.containsKey(destination)) {
      _built[destination] = widget.builders[destination]!(context);
    }
    return _built[destination]!;
  }

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return ColoredBox(
      color: p.bg,
      child: ClipRect(
        child: Stack(
          children: [
            for (final destination in NavDestination.values)
              if (_visited.contains(destination))
                _StageLayer(
                  key: ValueKey(destination),
                  active: destination == widget.current,
                  direction: _direction,
                  child: _view(destination),
                ),
          ],
        ),
      ),
    );
  }
}

class _StageLayer extends StatelessWidget {
  const _StageLayer({
    super.key,
    required this.active,
    required this.direction,
    required this.child,
  });

  final bool active;
  final double direction;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: IgnorePointer(
          ignoring: !active,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: kViewFade,
            curve: kEase,
            // Twenty pixels, not a fraction of the width: the offset is absolute, and a
            // proportional one would travel further on a maximised window.
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: active ? 0.0 : kViewTravel * direction),
              duration: kViewSlide,
              curve: kEase,
              builder: (context, dx, inner) =>
                  Transform.translate(offset: Offset(dx, 0), child: inner),
              // The boundary means the cross-fade composites a cached raster of each view
              // instead of re-rasterising its whole contents on every frame — the layer an
              // opacity animation forces has to come from somewhere.
              child: RepaintBoundary(child: child),
            ),
          ),
        ),
      );
}
