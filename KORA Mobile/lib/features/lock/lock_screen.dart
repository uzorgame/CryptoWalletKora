import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/services/biometric_service.dart';
import 'package:kora/core/services/lock_service.dart';
import 'package:kora/core/services/storage_service.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_mark.dart';
import 'package:kora/core/widgets/input/numpad.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  String _pin = '';
  bool _loading = false;
  String? _error;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (kDebugMode) debugPrint('[LockScreen] _init START');
    final biometricEnabled =
        await StorageService.readBool(StorageService.KEY_BIOMETRIC_ENABLED) ?? false;
    if (kDebugMode) debugPrint('[LockScreen] biometricEnabled=$biometricEnabled');
    if (!mounted) return;
    setState(() => _biometricEnabled = biometricEnabled);
    if (biometricEnabled) {
      if (kDebugMode) debugPrint('[LockScreen] Auto-triggering biometric after 400ms delay');
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _tryBiometric();
    } else {
      if (kDebugMode) debugPrint('[LockScreen] Biometric disabled — showing PIN pad only');
    }
  }

  Future<void> _tryBiometric() async {
    if (_loading) return;
    if (kDebugMode) debugPrint('[LockScreen] _tryBiometric START');
    setState(() { _loading = true; _error = null; });

    final result = await BiometricService.authenticate(
      reason: 'Unlock Kora Wallet',
      biometricOnly: false,
    );
    if (kDebugMode) debugPrint('[LockScreen] biometric result=${result.name}');

    if (!mounted) return;

    if (result.isSuccess) {
      if (kDebugMode) debugPrint('[LockScreen] ✅ Biometric unlock SUCCESS');
      ref.read(lockProvider.notifier).unlock();
    } else if (result == BiometricResult.cancelled) {
      if (kDebugMode) debugPrint('[LockScreen] User cancelled biometric — PIN pad shown');
      setState(() { _loading = false; });
    } else {
      if (kDebugMode) debugPrint('[LockScreen] ❌ Biometric failed: ${result.message}');
      setState(() {
        _loading = false;
        _error = result.message;
      });
    }
  }

  void _onDigit(String d) {
    if (_pin.length >= 6 || _loading) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (kDebugMode) debugPrint('[LockScreen] PIN digit entered: ${_pin.length}/6');
    if (_pin.length == 6) _verifyPin();
  }

  void _onBackspace() {
    if (_pin.isEmpty || _loading) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verifyPin() async {
    if (kDebugMode) debugPrint('[LockScreen] _verifyPin START');
    setState(() { _loading = true; _error = null; });
    final sw = Stopwatch()..start();
    final ok = await KeyManager.verifyAppPin(_pin);
    sw.stop();
    if (kDebugMode) debugPrint('[LockScreen] _verifyPin result=$ok  in ${sw.elapsedMilliseconds}ms');
    if (!mounted) return;
    if (ok) {
      if (kDebugMode) debugPrint('[LockScreen] ✅ PIN correct — unlocking');
      HapticFeedback.lightImpact();
      ref.read(lockProvider.notifier).unlock();
    } else {
      if (kDebugMode) debugPrint('[LockScreen] ❌ PIN incorrect');
      HapticFeedback.mediumImpact();
      setState(() {
        _loading = false;
        _pin = '';
        _error = 'Incorrect PIN. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const KoraMark(size: 64),
                const SizedBox(height: 26),
                Text('ENTER PIN',
                    style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.2)),
                const SizedBox(height: 8),
                Text('UNLOCK YOUR WALLET',
                    style: kLabel(AppColors.textTertiary, size: 9.5, tracking: 0.14)),
                const Spacer(flex: 2),
                // PIN squares — this application has no circles in it.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    final filled = i < _pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: filled ? AppColors.textPrimary : Colors.transparent,
                        border: Border.all(
                          color: filled ? AppColors.textPrimary : AppColors.borderHi,
                          width: 1,
                        ),
                      ),
                    );
                  }),
                ),
                if (_error != null) ...[  
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: kBody(AppColors.negative, size: 12),
                    textAlign: TextAlign.center,
                  ),
                ] else
                  const SizedBox(height: 12 + 16), // keep layout stable
                const Spacer(flex: 2),
                // Numpad
                Numpad(
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  onBiometric: _biometricEnabled ? _tryBiometric : null,
                  loading: _loading,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── PIN Numpad ───────────────────────────────────────────────────────────────
