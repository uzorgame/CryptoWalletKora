import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';

/// A scroll position that travels to the wheel's destination instead of teleporting to it.
///
/// A wheel notch on desktop moves the view a fixed distance in a single frame. That is
/// correct, and it is also why a long table reads as stuttering: nothing moves, then
/// everything moves fifty pixels, then nothing moves. The page never travels.
///
/// The smoothing lives here, in the position, rather than in a `Listener` wrapped around the
/// scroll view. That was the first attempt and it did not work: [Scrollable] registers with
/// the [PointerSignalResolver] from deeper in the hit-test path, so it won the same event and
/// its jump replaced the outer animation on the frame it started. Overriding [pointerScroll]
/// is the framework's own seam for this — the wheel arrives here either way.
class _SmoothScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothScrollPosition({required super.physics, required super.context, super.oldPosition});

  /// Where the view is heading, which is not where it is. Null when it is not heading
  /// anywhere, so an idle notch starts from where the eye actually is.
  double? _target;

  /// Below this, a scroll signal is a trackpad's continuous stream rather than a wheel's
  /// discrete notch. Trackpads are already smooth and already under the user's finger;
  /// animating them adds lag to the one input that does not need it.
  static const double _notchThreshold = 20;

  @override
  void pointerScroll(double delta) {
    if (delta.abs() < _notchThreshold || !hasContentDimensions) {
      _target = null;
      super.pointerScroll(delta);
      return;
    }

    final from = _target ?? pixels;
    final target = (from + delta).clamp(minScrollExtent, maxScrollExtent);
    if (target == pixels && _target == null) return;
    if (target == _target) return;
    _target = target;

    animateTo(target, duration: kSmoothScroll, curve: Curves.easeOutCubic).whenComplete(() {
      // Release the anchor only if nothing was added meanwhile; otherwise the next notch
      // would start from the settled position and a fast run would lose its accumulation.
      if (_target == target) _target = null;
    });
  }

  // A drag, a fling or a jump is the user overriding the wheel's destination. Forget it,
  // or the next notch would resume from somewhere the view has long since left.
  @override
  void applyUserOffset(double delta) {
    _target = null;
    super.applyUserOffset(delta);
  }

  @override
  void jumpTo(double value) {
    _target = null;
    super.jumpTo(value);
  }
}

/// A [ScrollController] whose positions smooth the wheel.
///
/// Usable with any scrollable — pass it to a [ListView], a [CustomScrollView], anything that
/// takes a controller — so the behaviour is not tied to one widget's shape.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({super.initialScrollOffset, super.debugLabel});

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SmoothScrollPosition(physics: physics, context: context, oldPosition: oldPosition);
}

/// A scroll view that travels instead of teleporting.
///
/// A drop-in replacement for [SingleChildScrollView]; it owns its controller, because binding
/// to whatever [PrimaryScrollController] happens to be in scope is the kind of coupling that
/// works until a dialog puts a different one in the way.
///
/// Use [SmoothScrollView.slivers] where the content is a long list: a box child is laid out
/// and painted in full however little of it is on screen, and at a few hundred rows that is
/// the whole frame budget.
class SmoothScrollView extends StatefulWidget {
  const SmoothScrollView({super.key, required Widget this.child, this.padding}) : slivers = null;

  /// The lazy form. Only the slivers overlapping the viewport are built.
  const SmoothScrollView.slivers({super.key, required List<Widget> this.slivers, this.padding})
    : child = null;

  final Widget? child;
  final List<Widget>? slivers;
  final EdgeInsetsGeometry? padding;

  @override
  State<SmoothScrollView> createState() => _SmoothScrollViewState();
}

class _SmoothScrollViewState extends State<SmoothScrollView> {
  final _controller = SmoothScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child case final child?) {
      return SingleChildScrollView(controller: _controller, padding: widget.padding, child: child);
    }
    return CustomScrollView(
      controller: _controller,
      slivers: [
        SliverPadding(
          padding: widget.padding ?? EdgeInsets.zero,
          sliver: SliverMainAxisGroup(slivers: widget.slivers!),
        ),
      ],
    );
  }
}
