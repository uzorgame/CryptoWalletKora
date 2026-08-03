import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';
import 'nav_destination.dart';

/// The left rail: numbered destinations and one marker that travels between them.
///
/// The marker is measured from the laid-out items rather than positioned by arithmetic,
/// because the items are sized by their translated labels and those change length per
/// language.
class NavRail extends StatefulWidget {
  const NavRail({
    super.key,
    required this.current,
    required this.onSelect,
    required this.footer,
  });

  final NavDestination current;
  final ValueChanged<NavDestination> onSelect;

  /// The wallet switcher and lock, which belong to the session rather than to a place.
  final Widget footer;

  @override
  State<NavRail> createState() => _NavRailState();
}

class _NavRailState extends State<NavRail> {
  final _itemKeys = {for (final d in NavDestination.values) d: GlobalKey()};
  final _railKey = GlobalKey();
  Rect? _markerRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(NavRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Item widths follow their translated labels, so a language change moves the marker
    // without the destination changing at all. Measuring only on selection left it stranded
    // over the wrong item until the next click.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final rail = _railKey.currentContext?.findRenderObject() as RenderBox?;
    final item = _itemKeys[widget.current]?.currentContext?.findRenderObject() as RenderBox?;
    if (rail == null || item == null || !rail.hasSize || !item.hasSize) return;
    final rect = item.localToGlobal(Offset.zero, ancestor: rail) & item.size;
    if (rect != _markerRect) setState(() => _markerRect = rect);
  }

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return Container(
      key: _railKey,
      width: kRailWidth,
      decoration: BoxDecoration(
        color: p.bgAlt,
        border: Border(right: BorderSide(color: p.border)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              for (final destination in NavDestination.values)
                _RailItem(
                  key: _itemKeys[destination],
                  destination: destination,
                  active: destination == widget.current,
                  onTap: () => widget.onSelect(destination),
                ),
              const Spacer(),
              widget.footer,
            ],
          ),
          if (_markerRect != null)
            AnimatedPositioned(
              duration: kMarkerTravel,
              curve: kEase,
              // top:0 is load-bearing. Positioned without it starts after the rail's own
              // padding while the measured offset already counts it, which put the marker
              // ten pixels below every item it was meant to mark.
              top: _markerRect!.top,
              left: 0,
              height: _markerRect!.height,
              child: Container(width: 2, color: p.text),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({
    super.key,
    required this.destination,
    required this.active,
    required this.onTap,
  });

  final NavDestination destination;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final ink = widget.active ? p.text : (_hover ? p.text2 : p.text3);
    // The number brightens with the label but stays a step behind, so the pair reads as
    // index and label rather than as two equal words.
    final numberInk = widget.active ? p.text2 : p.text3;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: kHover,
          curve: Curves.easeOut,
          // One ink, fading its own alpha. Crossing to `Colors.transparent` — which is
          // transparent *black* — dragged r, g and b up from zero as alpha rose, so the row
          // flashed a grey block halfway through and two adjacent rows flashed together on
          // every move between them. Selection is still carried by the marker and the ink
          // alone, as in the prototype; the active row simply does not take a hover.
          color: _hover && !widget.active ? p.hover : p.hover.withAlpha(0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            children: [
              AnimatedDefaultTextStyle(
                duration: kInk,
                curve: kEase,
                style: koraLabel(numberInk, size: 9.5, tracking: 0.1),
                child: Text(widget.destination.number),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: kInk,
                  curve: kEase,
                  style: koraLabel(ink, size: 10.5, tracking: 0.14),
                  child: Text(widget.destination.label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
