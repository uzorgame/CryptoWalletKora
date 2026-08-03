import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kora/core/widgets/animated_tap.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/services/biometric_service.dart';
import 'package:kora/core/services/lock_service.dart';
import 'package:kora/core/services/storage_service.dart';
import 'package:kora/core/theme/app_theme.dart';

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
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.background, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kora',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter PIN to unlock',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const Spacer(flex: 2),
                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    final filled = i < _pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? AppColors.textPrimary : Colors.transparent,
                        border: Border.all(
                          color: filled ? AppColors.textPrimary : AppColors.textTertiary,
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
                if (_error != null) ...[  
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: AppColors.negative, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ] else
                  const SizedBox(height: 12 + 16), // keep layout stable
                const Spacer(flex: 2),
                // Numpad
                _Numpad(
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

class _Numpad extends StatelessWidget {
  const _Numpad({
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.loading = false,
  });

  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              width: 72, height: 72,
              child: onBiometric != null
                  ? _NumBtn(
                      onTap: loading ? null : onBiometric,
                      child: Icon(Icons.fingerprint_rounded,
                          color: AppColors.textSecondary, size: 28),
                    )
                  : const SizedBox.shrink(),
            ),
            _NumBtn(
              label: '0',
              onTap: loading ? null : () => onDigit('0'),
            ),
            SizedBox(
              width: 72, height: 72,
              child: _NumBtn(
                onTap: loading ? null : onBackspace,
                child: loading
                    ? SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: AppColors.textPrimary, strokeWidth: 2))
                    : Icon(Icons.backspace_outlined,
                        color: AppColors.textSecondary, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((d) => _NumBtn(
                label: d,
                onTap: loading ? null : () => onDigit(d),
              ))
          .toList(),
    );
  }
}

class _NumBtn extends StatelessWidget {
  const _NumBtn({this.label, this.child, this.onTap});
  final String? label;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.88,
      pressOpacity: 0.65,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
        ),
        child: Center(
          child: label != null
              ? Text(
                  label!,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                  ),
                )
              : child,
        ),
      ),
    );
  }
}
