import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';

/// A row of square choices with one selected — ranges, currencies, fee tiers, coin pickers.
///
/// The selected option inverts rather than tinting, because inversion is the only emphasis
/// available in a monochrome system that does not borrow the up/down colours.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.wrap = false,
    this.disabled = const {},
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  /// Wrapping rather than scrolling: twenty tickers will not fit one row on a narrow window,
  /// and a second row is honest where a clipped row hides half the list.
  final bool wrap;

  /// Options that are visible but not choosable — a coin with no balance, for instance.
  final Set<String> disabled;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    final children = [
      for (final option in options)
        _Segment(
          label: option,
          selected: option == selected,
          enabled: !disabled.contains(option),
          onTap: () => onSelect(option),
        ),
    ];

    return Container(
      color: p.border, // shows through the one-pixel gaps as hairlines
      child: wrap
          ? Wrap(spacing: 1, runSpacing: 1, children: children)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) const SizedBox(width: 1),
                  child,
                ],
              ],
            ),
    );
  }
}

class _Segment extends StatefulWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final background = widget.selected ? p.text : (_hover && widget.enabled ? p.surfaceHi : p.surface);
    final ink = widget.selected ? p.bg : (_hover && widget.enabled ? p.text : p.text3);

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.4,
          child: AnimatedContainer(
            duration: kControl,
            curve: kEase,
            color: background,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            // The label travels with the fill rather than snapping ahead of it.
            child: AnimatedDefaultTextStyle(
              duration: kControl,
              curve: kEase,
              style: koraLabel(ink, size: 10, tracking: 0.08),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}
