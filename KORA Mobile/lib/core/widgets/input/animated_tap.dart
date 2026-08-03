import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps any child with a satisfying spring press animation:
///   • scales to [pressScale] on tap-down (default 0.94)
///   • dims to [pressOpacity] on tap-down (default 0.72)
///   • springs back with [Curves.elasticOut] on release
///
/// Usage:
///   AnimatedTap(onTap: () {}, child: MyWidget())
class AnimatedTap extends StatefulWidget {
  const AnimatedTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressScale = 0.94,
    this.pressOpacity = 0.72,
    this.duration = const Duration(milliseconds: 70),
    this.releaseDuration = const Duration(milliseconds: 320),
    this.borderRadius,
    this.enableHaptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressScale;
  final double pressOpacity;
  final Duration duration;
  final Duration releaseDuration;
  final BorderRadius? borderRadius;
  final bool enableHaptic;

  @override
  State<AnimatedTap> createState() => _AnimatedTapState();
}

class _AnimatedTapState extends State<AnimatedTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.releaseDuration,
      lowerBound: 0,
      upperBound: 1,
    );

    _scale = Tween<double>(begin: 1.0, end: widget.pressScale).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOut,
        reverseCurve: const ElasticOutCurve(0.6),
      ),
    );

    _opacity = Tween<double>(begin: 1.0, end: widget.pressOpacity).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (widget.enableHaptic) HapticFeedback.lightImpact();
    _ctrl.forward();
  }

  void _onTapUp(TapUpDetails _) => _ctrl.reverse();
  void _onTapCancel() => _ctrl.reverse();

  void _onTap() => widget.onTap?.call();
  void _onLongPress() {
    if (widget.enableHaptic) HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap != null ? _onTap : null,
      onLongPress: widget.onLongPress != null ? _onLongPress : null,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: Opacity(opacity: _opacity.value, child: child),
        ),
        child: widget.child,
      ),
    );
  }
}
