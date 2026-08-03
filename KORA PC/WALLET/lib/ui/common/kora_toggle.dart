import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';

/// A track with a knob. Square, like everything else, and sized so both states are legible
/// without reading the label beside them.
class KoraToggle extends StatelessWidget {
  const KoraToggle({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  static const double _width = 38;
  static const double _height = 20;
  static const double _knob = 12;
  static const double _inset = 3;
  static const double _border = 1;

  /// The stack sits inside the border, so the travel is measured against the content box.
  /// Measuring it against the outer box left the knob one pixel off centre at rest and three
  /// pixels short of the far edge when on.
  static const double _trackWidth = _width - _border * 2;
  static const double _knobEnd = _trackWidth - _knob - _inset;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return Semantics(
      label: semanticLabel,
      toggled: value,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: kHover,
            curve: kEase,
            width: _width,
            height: _height,
            decoration: BoxDecoration(
              color: value ? p.text : p.bg,
              border: Border.all(color: value ? p.text : p.border, width: _border),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: kHover,
                  curve: kEase,
                  left: value ? _knobEnd : _inset,
                  top: (_height - _border * 2 - _knob) / 2,
                  child: Container(
                    width: _knob,
                    height: _knob,
                    color: value ? p.bg : p.text3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
