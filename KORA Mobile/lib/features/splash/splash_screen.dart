import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/services/lock_service.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/features/home/home_screen.dart';
import 'package:kora/core/crypto/encryption.dart';
import 'package:kora/core/widgets/coin_icon.dart';
import 'package:kora/features/onboarding/onboarding_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Start JVM crypto warmup ASAP — before even the first frame
    EncryptionService.warmupCrypto().ignore();
    _navigate();
  }

  Future<void> _navigate() async {
    if (kDebugMode) debugPrint('[Splash] _navigate START');
    // Run minimum splash animation AND wallet init in parallel.
    // Show next screen as soon as BOTH complete (min 700 ms for animation).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        preloadCoinIcons(context).ignore();
        ref.read(currentWalletProvider);
      });
    });
    final hasWallets = await Future.wait<dynamic>([
      Future<void>.delayed(const Duration(milliseconds: 700)),
      ref.read(hasWalletsProvider.future),
    ]).then((results) => results[1] as bool);
    if (!mounted) return;
    if (kDebugMode) debugPrint('[Splash] hasWallets=$hasWallets');
    if (!mounted) return;

    if (hasWallets) {
      // Always lock on every app launch if a PIN has been set
      final hasPin = await KeyManager.hasAppPin();
      if (kDebugMode) debugPrint('[Splash] hasPin=$hasPin');
      if (hasPin) {
        if (kDebugMode) debugPrint('[Splash] → HomeScreen (locked) — LockScreen overlay will show');
        ref.read(lockProvider.notifier).lock();
        // LockScreen overlay in main.dart will handle PIN / biometric auth
        _goTo(true);
        return;
      }
    }

    // No wallet yet or no PIN — go to destination unlocked
    if (kDebugMode) debugPrint('[Splash] → ${hasWallets ? 'HomeScreen (unlocked)' : 'OnboardingScreen'}');
    ref.read(lockProvider.notifier).unlock();
    _goTo(hasWallets);
  }

  void _goTo(bool hasWallets) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            hasWallets ? const HomeScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'KORA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }
}
