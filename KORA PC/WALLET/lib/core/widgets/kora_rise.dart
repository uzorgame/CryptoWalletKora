import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/kora_design.dart';

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

class _RiseState extends State<Rise> with TickerProviderStateMixin {
  /// Null once the entrance is over.
  ///
  /// An entrance is a second of a widget's life, and this one is used per row of a table that
  /// can run to several hundred rows. Holding the controller afterwards meant holding that
  /// many tickers, each registered with the scheduler, for as long as the app was open — the
  /// animation was finished but the app kept paying for it. Now the ticker is handed back the
  /// moment it has nothing left to do, and what remains is the child itself: at t = 1 the
  /// opacity and the offset are both identities, so nothing about the result changes.
  AnimationController? _controller;
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
    _controller?.dispose();

    final controller = AnimationController(vsync: this, duration: widget.duration);
    _controller = controller;

    void start() {
      if (!mounted || _controller != controller) return;
      controller.forward().then((_) => _settle(controller));
    }

    // Held at zero through the stagger, matching `animation-fill-mode: both` — otherwise a
    // card would sit fully drawn for its delay and then blink to the start of the animation.
    if (widget.delay == Duration.zero) {
      start();
    } else {
      _pending = Timer(widget.delay, start);
    }
  }

  void _settle(AnimationController controller) {
    // Not the live controller any more means a newer generation already replaced and disposed
    // it; not completed means it was interrupted rather than finished.
    if (_controller != controller || controller.status != AnimationStatus.completed) return;
    _controller = null;
    controller.dispose();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pending?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;

    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        final t = kEase.transform(controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, widget.travel * (1 - t)), child: child),
        );
      },
    );
  }
}
