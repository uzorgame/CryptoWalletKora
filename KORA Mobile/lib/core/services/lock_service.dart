import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/state/providers/settings_provider.dart';

// ─── Lock state provider ──────────────────────────────────────────────────────

final lockProvider = StateNotifierProvider<LockNotifier, bool>((ref) {
  return LockNotifier(ref);
});

// ─── LockNotifier ─────────────────────────────────────────────────────────────

class LockNotifier extends StateNotifier<bool> with WidgetsBindingObserver {
  final Ref _ref;
  DateTime? _backgroundedAt;

  LockNotifier(this._ref) : super(false) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Call after successful authentication to mark the session as active.
  void unlock() {
    if (kDebugMode) debugPrint('[Lock] ✅ UNLOCKED');
    state = false;
  }

  /// Manually lock (e.g. from settings or biometric failure).
  void lock() {
    if (kDebugMode) debugPrint('[Lock] 🔒 LOCKED (manual/launch)');
    state = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (kDebugMode) debugPrint('[Lock] Lifecycle → ${lifecycle.name}');
    final timeout = _ref.read(autoLockTimeoutProvider);

    // "On launch only" — never lock in background
    if (timeout == AutoLockTimeout.onLaunchOnly) {
      if (kDebugMode) debugPrint('[Lock] AutoLock=onLaunchOnly — background locking disabled');
      return;
    }

    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt = DateTime.now();
        if (kDebugMode) debugPrint('[Lock] App backgrounded at $_backgroundedAt  threshold=${timeout.displayName}');
        break;

      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt == null) {
          if (kDebugMode) debugPrint('[Lock] Resumed — no background timestamp, skip lock check');
          return;
        }

        final threshold = timeout.backgroundDuration;
        if (threshold == null) return;

        final elapsed = DateTime.now().difference(backgroundedAt);
        if (kDebugMode) debugPrint('[Lock] Resumed after ${elapsed.inSeconds}s  threshold=${threshold.inSeconds}s  → lock=${elapsed >= threshold}');
        if (elapsed >= threshold) {
          if (kDebugMode) debugPrint('[Lock] 🔒 LOCKED (background timeout exceeded)');
          state = true;
        }
        break;

      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
