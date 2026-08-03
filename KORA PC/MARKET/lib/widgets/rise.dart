import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// The entrance the prototype got for free.
///
/// There, switching tabs re-rendered a view's markup, so its CSS `rise` animation replayed
/// and the grid assembled itself card by card. Flutter keeps the widgets alive across a
/// switch — better for state, but it means nothing replays unless asked. [generation] is the
/// ask: bump it and the element fades and lifts back into place after its stagger.
class Rise extends StatefulWidget {
  const Rise({
    super.key,
    required this.generation,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.travel = 7,
  });

  final int generation;
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double travel;

  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  Timer? _pending;

  @override
  void initState() {
    super.initState();
    _replay();
  }

  @override
  void didUpdateWidget(Rise oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.generation != oldWidget.generation) _replay();
  }

  void _replay() {
    _pending?.cancel();
    // Held at zero through the stagger, matching `animation-fill-mode: both` — otherwise a
    // card would sit fully drawn for its delay and then blink to the start of the animation.
    _controller.value = 0;
    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }
    _pending = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _pending?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = kEase.transform(_controller.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, widget.travel * (1 - t)), child: child),
          );
        },
      );
}
