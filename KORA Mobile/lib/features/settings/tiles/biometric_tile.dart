import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/services/biometric_service.dart';
import 'package:kora/core/state/providers/settings_provider.dart' hide currencyProvider;
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

// The biometric unlock toggle, with the availability checks behind it.

class BiometricTile extends ConsumerWidget {
  const BiometricTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(biometricEnabledProvider);
    return AnimatedTap(
      onTap: () => _toggle(context, ref, enabled),
      pressScale: 0.97,
      child: Container(
        margin: EdgeInsets.only(bottom: 2),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.separator, width: 1),
        ),
        child: Row(children: [
          Icon(Icons.fingerprint_rounded, color: AppColors.textSecondary, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text('Biometric Auth',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w400)),
          ),
          Switch(
            value: enabled,
            onChanged: (v) => _toggle(context, ref, !v),
            activeThumbColor: AppColors.background,
            activeTrackColor: AppColors.textPrimary,
            inactiveThumbColor: AppColors.textTertiary,
            inactiveTrackColor: AppColors.separator,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool currentEnabled) async {

    if (!currentEnabled) {
      // Check if device supports any biometric or device credentials
      final deviceSupported = await BiometricService.isDeviceSupported();
      debugPrint('[Biometric] isDeviceSupported=$deviceSupported (settings_screen.dart)');

      if (!deviceSupported) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Biometric authentication is not supported on this device')),
          );
        }
        return;
      }

      final result = await BiometricService.authenticate(
        reason: 'Enable biometric unlock for Kora Wallet',
        biometricOnly: false,
      );
      debugPrint('[Biometric] authenticate result: ${result.name} — ${result.message} (settings_screen.dart)');

      if (result.isSuccess) {
        // Prompt for PIN to store it for future biometric-based decryption
        if (context.mounted) {
          final pin = await _askForPin(context);
          if (pin == null) return; // user cancelled
          final valid = await KeyManager.verifyAppPin(pin);
          if (!valid) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Incorrect PIN — biometric not enabled')),
            );
            return;
          }
          await KeyManager.storePinForBiometric(pin);
        }
        await ref.read(settingsProvider.notifier).setBiometricEnabled(true);
        debugPrint('[Biometric] Enabled ✓ (settings_screen.dart)');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication enabled')),
          );
        }
      } else if (context.mounted && !result.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } else {
      await KeyManager.deletePinForBiometric();
      await ref.read(settingsProvider.notifier).setBiometricEnabled(false);
      debugPrint('[Biometric] Disabled ✓ (settings_screen.dart)');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication disabled')),
        );
      }
    }
  }

  /// Shows a simple PIN-entry dialog and returns the entered PIN or null.
  static Future<String?> _askForPin(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('Confirm PIN',
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary, letterSpacing: 4),
          decoration: InputDecoration(
            labelText: 'Enter your PIN',
            labelStyle: TextStyle(color: AppColors.textSecondary),
            counterText: '',
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.separator)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.textPrimary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text('Confirm',
                style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
