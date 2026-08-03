import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/services/lock_service.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/features/lock/lock_screen.dart';
import 'package:kora/features/splash/splash_screen.dart';
import 'package:kora/core/services/binance_price_stream.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // A release build does not silence debugPrint on its own, and the app logs generously —
  // startup, refreshes, sends. None of that belongs on the console of a shipped wallet.
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  if (kDebugMode) debugPrint('[App] ===== Kora Wallet starting (DEBUG) =====');
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);
  BinancePriceStream.instance.start();
  runApp(const ProviderScope(child: KoraApp()));
}

class KoraApp extends ConsumerWidget {
  const KoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: ThemeNotifier.instance,
      builder: (_, __) {
        SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);
        return MaterialApp(
          title: 'Kora Wallet',
          debugShowCheckedModeBanner: false,
          theme:     AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeNotifier.instance.mode,
          // Disable built-in Material animation — our overlay handles the transition
          themeAnimationDuration: Duration.zero,
          home: const SplashScreen(),
          builder: (context, child) {
            return Consumer(
              builder: (context, ref, _) {
                final locked = ref.watch(lockProvider);
                if (kDebugMode) debugPrint('[App] lockState=$locked');
                return _ThemeFadeOverlay(
                  child: Stack(
                    children: [
                      child ?? const SizedBox.shrink(),
                      if (locked) const LockScreen(),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── Smooth theme-change fade overlay ────────────────────────────────────────

class _ThemeFadeOverlay extends StatefulWidget {
  const _ThemeFadeOverlay({required this.child});
  final Widget child;

  @override
  State<_ThemeFadeOverlay> createState() => _ThemeFadeOverlayState();
}

class _ThemeFadeOverlayState extends State<_ThemeFadeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  // Freeze the overlay color at the moment transition starts
  Color _overlayColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    ThemeNotifier.instance.addListener(_onThemeChange);
  }

  void _onThemeChange() {
    // Snapshot the NEW theme's background so the fade blends into it naturally
    _overlayColor = ThemeNotifier.instance.isDark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFF2F2F7);
    // Start smooth fade transition
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChange);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            if (_ctrl.value == 0) return const SizedBox.shrink();
            // Smooth triangle wave with easeInOut for both halves
            final t = _ctrl.value <= 0.5
                ? Curves.easeInOut.transform(_ctrl.value * 2)
                : Curves.easeInOut.transform((1 - _ctrl.value) * 2);
            if (t == 0) return const SizedBox.shrink();
            return IgnorePointer(
              child: Opacity(
                opacity: t * 0.95, // Slightly reduce max opacity for smoother blend
                child: ColoredBox(
                  color: _overlayColor,
                  child: const SizedBox.expand(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
