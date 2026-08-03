import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/kora_design.dart';

/// Theme, minimise, maximise and close.
///
/// One implementation. The screens this replaces each carried their own copy of the drag
/// strip and two macOS-style dots — three verbatim duplicates that had already drifted apart.
class WindowControls extends StatelessWidget {
  const WindowControls({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Theme first, then the system controls: one belongs to the app, the others to the
          // operating system, and the grouping should say so.
          _WindowButton(onTap: onToggleTheme, builder: ContrastMark.new),
          _WindowButton(
            onTap: windowManager.minimize,
            builder: (ink) => Container(width: 10, height: 1, color: ink),
          ),
          _WindowButton(
            onTap: () async => await windowManager.isMaximized()
                ? windowManager.unmaximize()
                : windowManager.maximize(),
            builder: (ink) => Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(border: Border.all(color: ink)),
            ),
          ),
          _WindowButton(
            danger: true,
            onTap: windowManager.close,
            builder: (ink) => CloseMark(color: ink),
          ),
        ],
      );
}

/// The glyph is a builder rather than a widget because its colour belongs to the button's
/// hover state. Fixing the ink at construction left the mark grey on a red close button.
class _WindowButton extends StatefulWidget {
  const _WindowButton({required this.builder, required this.onTap, this.danger = false});

  final Widget Function(Color ink) builder;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    // The wash fades its own alpha rather than crossing to `Colors.transparent`, which is
    // transparent *black*: lerping the close button's red to it walked through a dusty mauve
    // before the red arrived, and the neutral buttons through mid-grey. Since the buttons tile
    // edge to edge, an ordinary sweep across the caption starts an enter and an exit in the
    // same frame — so two of them showed that dirty midpoint at once.
    final wash = widget.danger ? p.down : p.hover;
    final background = _hover ? wash : wash.withAlpha(0);
    final ink = _hover ? (widget.danger ? Colors.white : p.text) : p.text2;

    // No Tooltip here on purpose: its own mouse region swallows exit events between adjacent
    // buttons, which left two of them lit at once.
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
          duration: kControl,
          // easeOut, not the house kEase: kEase is a near-step curve that reaches 90% in two
          // frames, which is right for something travelling but reads as a snap on a fade.
          curve: Curves.easeOut,
          builder: (context, colour, child) => ColoredBox(
            color: colour ?? Colors.transparent,
            child: SizedBox(
              width: 44,
              height: kTitlebarHeight,
              child: Center(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: ink),
                  duration: kControl,
                  curve: Curves.easeOut,
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

/// Two hairlines crossed, so the stroke weight matches the minimise and maximise marks
/// rather than whatever a font glyph happens to be.
class CloseMark extends StatelessWidget {
  const CloseMark({super.key, required this.color});

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
class ContrastMark extends StatelessWidget {
  const ContrastMark(this.color, {super.key});

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
