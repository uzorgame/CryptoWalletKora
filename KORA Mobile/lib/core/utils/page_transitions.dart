import 'package:flutter/material.dart';

// ─── 1. Push route — slides from right with spring bounce ─────────────────────

/// Standard forward navigation: new page slides in from the right.
/// The outgoing page slides slightly left (like iOS).
class PushPageRoute<T> extends PageRouteBuilder<T> {
  PushPageRoute({required Widget page, super.settings})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (_, animation, secondaryAnimation, child) => child,
        );
}

// ─── 2. Modal slide-up route — slides from bottom (for Send/Receive) ──────────

/// Modal navigation: new page slides in from the bottom with a slight scale.
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  SlideUpPageRoute({required Widget page, super.settings})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (_, animation, secondaryAnimation, child) => child,
        );
}

// ─── 3. Fade route — cross-fade (for settings / sub-pages) ────────────────────

/// Smooth cross-fade transition for secondary pages.
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  FadeSlidePageRoute({required Widget page, super.settings})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (_, animation, secondaryAnimation, child) => child,
        );
}

// ─── Navigation extensions ────────────────────────────────────────────────────

extension AnimatedNavigation on BuildContext {
  /// Standard push — slides from right (use for detail screens)
  Future<T?> pushSlide<T>(Widget page) =>
      Navigator.of(this).push<T>(PushPageRoute(page: page));

  /// Modal push — slides from bottom (use for Send/Receive/QR)
  Future<T?> pushModal<T>(Widget page) =>
      Navigator.of(this).push<T>(SlideUpPageRoute(page: page));

  /// Fade push — cross-fade (use for settings sub-pages)
  Future<T?> pushFade<T>(Widget page) =>
      Navigator.of(this).push<T>(FadeSlidePageRoute(page: page));
}
