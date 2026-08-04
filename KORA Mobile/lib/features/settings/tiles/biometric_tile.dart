import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/services/biometric_service.dart';
import 'package:kora/core/state/providers/settings_provider.dart' hide currencyProvider;
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/widgets/kora_rows.dart';
import 'package:kora/core/widgets/kora_switch.dart';
import 'package:kora/core/widgets/pin_gate.dart';

// The biometric unlock toggle, with the availability checks behind it.

class BiometricTile extends ConsumerWidget {
  const BiometricTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(biometricEnabledProvider);
    return KoraRow(
      onTap: () => _toggle(context, ref, enabled),
      children: [
        Text('Biometric Unlock', style: kBody(AppColors.textPrimary, size: 13.5)),
        const Spacer(),
        KoraSwitch(
          value: enabled,
          onChanged: (_) => _toggle(context, ref, enabled),
        ),
      ],
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

      // biometricOnly: the fingerprint or face, and nothing else. Allowing the device
      // credential here is what made Android put up its own PIN sheet in the middle of our
      // flow — a system dialog asking for a system passcode, right where the wallet is
      // about to ask for its own. The app PIN is this application's business and is asked
      // for in this application's language, below.
      final result = await BiometricService.authenticate(
        reason: 'Enable biometric unlock for Kora Wallet',
        biometricOnly: true,
      );
      debugPrint('[Biometric] authenticate result: ${result.name} — ${result.message} (settings_screen.dart)');

      if (result.isSuccess) {
        // Then our own gate, for the PIN that will decrypt the seed after a fingerprint.
        if (context.mounted) {
          final pin = await askAppPinValue(
            context,
            title: 'Enable biometrics',
            explanation:
                'Enter your app PIN once so a fingerprint can unlock this wallet.',
          );
          if (pin == null) return; // cancelled — nothing changes
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
}
