import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';

/// How much weight a button carries.
enum KoraButtonTone {
  /// Inverted — the ink colour as a fill. One per surface, on the action being suggested.
  primary,

  /// A dark face with a hairline. Everything else.
  secondary,

  /// Reserved for the irreversible.
  danger,
}

/// The system's button: square, flat, and legible at a glance about how serious it is.
class KoraButton extends StatefulWidget {
  const KoraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = KoraButtonTone.secondary,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final KoraButtonTone tone;

  /// Fills the width it is given, for buttons that sit in a row of equals.
  final bool expand;

  bool get enabled => onPressed != null;

  @override
  State<KoraButton> createState() => _KoraButtonState();
}

class _KoraButtonState extends State<KoraButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    final (background, ink) = switch ((widget.enabled, widget.tone)) {
      (false, _) => (p.bg, p.text3),
      (true, KoraButtonTone.primary) => (p.text, p.bg),
      (true, KoraButtonTone.danger) => (
        _hover ? p.down : p.surface,
        _hover ? Colors.white : p.down,
      ),
      (true, KoraButtonTone.secondary) => (
        _hover ? p.surfaceHi : p.surface,
        _hover ? p.text : p.text2,
      ),
    };

    final button = MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        // A press is acknowledged the moment the button goes down, not when the work it
        // starts finishes. Without it there is nothing at all between the click and the
        // result — which on a slow action reads as "that did not register", and gets clicked
        // again. On a wallet, a second click is not a harmless thing to invite.
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: kControl,
            curve: kEase,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: background,
              // Every tone carries a border, transparent where it should not be seen. Omitting
              // it on the primary made that button two pixels smaller than the ones beside it,
              // which is exactly the drift the border was meant to prevent.
              border: Border.all(
                color: widget.tone == KoraButtonTone.primary ? background : p.border,
              ),
            ),
            alignment: Alignment.center,
            child: AnimatedDefaultTextStyle(
              duration: kControl,
              curve: kEase,
              style: koraLabel(ink, size: 11, tracking: 0.16),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );

    return widget.expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
