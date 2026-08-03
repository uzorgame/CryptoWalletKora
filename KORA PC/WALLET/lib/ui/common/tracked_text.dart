import 'package:flutter/material.dart';

/// Centred text that is actually centred, despite letter-spacing.
///
/// Letter-spacing is applied after every glyph including the last, so a tracked word's box
/// carries one trailing gap that has nothing in it. Centring the box therefore places the
/// visible word half a gap left of centre. At the system's label tracking that is small; at
/// the 0.5em used for the KORA wordmark it is 5.5px on a four-letter word, which is enough to
/// see and enough to make two stacked labels look misaligned with each other.
///
/// The correction is read from the style rather than passed in, so it stays right if the size
/// or the tracking changes.
class TrackedText extends StatelessWidget {
  const TrackedText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // Translate, not pad. Padding of L narrows the box to W−L and the centred line re-centres
    // inside it, so the ink only moves by L/2 — a first attempt padded by ls/2 and therefore
    // corrected half of what was needed. Translating moves the ink by exactly the offset given
    // and consumes no layout width, so a long label cannot start wrapping because of it.
    final shift = (style.letterSpacing ?? 0).clamp(0.0, double.infinity) / 2;
    return Transform.translate(
      offset: Offset(shift, 0),
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
  }
}
