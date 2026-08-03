import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/services/biometric_service.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/core/state/providers/settings_provider.dart' hide currencyProvider;
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/repositories/wallet_repository.dart';
import 'package:kora/features/onboarding/onboarding_screen.dart';
import 'package:kora/features/onboarding/wallet_selection_screen.dart';
import 'package:kora/features/settings/currency_selector_screen.dart';
import 'package:kora/features/settings/auto_lock_selector_screen.dart';
import 'package:kora/features/settings/show_seed_phrase_screen.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/core/widgets/animated_tap.dart';
import 'package:kora/features/settings/privacy_policy_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(currentWalletProvider);
    final wallet = walletAsync.value;

    return ListenableBuilder(
      listenable: ThemeNotifier.instance,
      builder: (_, __) => Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Wallet info card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.textPrimary),
                  child: Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.background, size: 24),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(wallet?.name ?? 'No Wallet',
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text(wallet != null ? 'Seed Phrase Wallet' : 'Create or import a wallet',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
            SizedBox(height: 24),

            // Security section
            _SectionHeader('Security'),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              label: 'Change PIN',
              onTap: () { debugPrint('[TAP] Change PIN (settings_screen.dart)'); _showChangePinDialog(context, ref); },
            ),
            _BiometricTile(),
            _AutoLockTile(),
            _SettingsTile(
              icon: Icons.key_rounded,
              label: 'Show Seed Phrase',
              onTap: () { debugPrint('[TAP] Show Seed Phrase (settings_screen.dart)'); _showSeedPhrase(context, ref); },
            ),
            SizedBox(height: 20),


            // General section
            _SectionHeader('General'),
            _AppearanceTile(),
            _CurrencyTile(),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () { debugPrint('[TAP] Privacy Policy (settings_screen.dart)'); context.pushSlide(const PrivacyPolicyScreen()); },
            ),
            _AboutTile(),
            SizedBox(height: 20),

            // Danger zone
            _SectionHeader('Wallet', color: AppColors.negative),
            _SettingsTile(
              icon: Icons.add_circle_outline_rounded,
              label: 'Add / Import Wallet',
              iconColor: AppColors.accent,
              onTap: () { debugPrint('[TAP] Add/Import Wallet (settings_screen.dart)'); context.pushSlide(const OnboardingScreen()); },
            ),
            _SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Remove Wallet',
              iconColor: AppColors.negative,
              labelColor: AppColors.negative,
              onTap: () { debugPrint('[TAP] Remove Wallet (settings_screen.dart)'); _confirmRemoveWallet(context, ref); },
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    ));
  }

  void _confirmRemoveWallet(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Wallet',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
            'Make sure you have your recovery phrase before removing this wallet.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () { debugPrint('[TAP] Remove Wallet: Cancel (settings_screen.dart)'); Navigator.of(context).pop(); },
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              debugPrint('[TAP] Remove Wallet: Confirm (settings_screen.dart)');
              final wallet = ref.read(currentWalletProvider).value;
              if (wallet != null) {
                await ref.read(currentWalletProvider.notifier).deleteWallet(wallet.id);
              }
              if (context.mounted) {
                // Check if there are other wallets
                final hasWallets = await WalletRepository().hasWallets();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => hasWallets 
                        ? const WalletSelectionScreen() 
                        : const OnboardingScreen(),
                  ),
                  (r) => false,
                );
              }
            },
            child: Text('Remove', style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSeedPhrase(BuildContext context, WidgetRef ref) async {
    final wallet = ref.read(currentWalletProvider).value;
    if (wallet == null) return;

    // Try biometric first if enabled
    final biometricEnabled = ref.read(biometricEnabledProvider);
    if (biometricEnabled) {
      final result = await BiometricService.authenticate(
        reason: 'Authenticate to view your recovery phrase',
      );
      if (!result.isSuccess) return;
      // Retrieve stored PIN to decrypt seed — skip PIN dialog entirely
      final storedPin = await KeyManager.getPinForBiometric();
      if (storedPin != null) {
        final seed = await KeyManager.getSeedPhrase(storedPin, walletId: wallet.id);
        if (seed != null && context.mounted) {
          context.pushFade(ShowSeedPhraseScreen(seedPhrase: seed));
        }
        return;
      }
      // If no stored PIN (legacy), fall through to PIN dialog
    }

    // Show PIN dialog that stays open on wrong PIN
    final pinCtrl = TextEditingController();
    String? errMsg;
    bool    obscure = true;
    bool    loading = false;

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('View Recovery Phrase',
              style: TextStyle(color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 16)),
          content: TextField(
            controller: pinCtrl,
            obscureText: obscure,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            style: TextStyle(color: AppColors.textPrimary, letterSpacing: 4),
            decoration: InputDecoration(
              labelText: 'PIN',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              counterText: '',
              errorText: errMsg,
              errorStyle: TextStyle(color: AppColors.negative, fontSize: 11),
              suffixIcon: IconButton(
                icon: Icon(obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                    color: AppColors.textTertiary, size: 18),
                onPressed: () => setS(() => obscure = !obscure),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.separator)),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.textPrimary)),
              errorBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.negative)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: loading ? null : () async {
                final pin = pinCtrl.text.trim();
                if (pin.isEmpty) return;
                setS(() { loading = true; errMsg = null; });
                final seed = await KeyManager.getSeedPhrase(
                    pin, walletId: wallet.id);
                if (!ctx.mounted) return;
                if (seed != null) {
                  Navigator.of(ctx).pop();
                  if (context.mounted) {
                    context.pushFade(ShowSeedPhraseScreen(seedPhrase: seed));
                  }
                } else {
                  setS(() { loading = false; errMsg = 'Incorrect PIN'; });
                }
              },
              child: Text('Confirm',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, WidgetRef ref) {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String? errorMessage;
    bool isLoading = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => PopScope(
          canPop: !isLoading,
          child: AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Change PIN',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !isLoading,
                  style: TextStyle(color: AppColors.textPrimary, letterSpacing: 4),
                  decoration: InputDecoration(
                    labelText: 'Current PIN',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    counterText: '',
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.separator),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                  ),
                  onChanged: (_) => setState(() => errorMessage = null),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: newPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !isLoading,
                  style: TextStyle(color: AppColors.textPrimary, letterSpacing: 4),
                  decoration: InputDecoration(
                    labelText: 'New PIN',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    counterText: '',
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.separator),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                  ),
                  onChanged: (_) => setState(() => errorMessage = null),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: confirmPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !isLoading,
                  style: TextStyle(color: AppColors.textPrimary, letterSpacing: 4),
                  decoration: InputDecoration(
                    labelText: 'Confirm New PIN',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    counterText: '',
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.separator),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                  ),
                  onChanged: (_) => setState(() => errorMessage = null),
                ),
                if (isLoading) ...[
                  SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: AppColors.textSecondary)),
                    SizedBox(width: 10),
                    Text('Changing PIN…',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ]),
                ],
                if (errorMessage != null) ...[
                  SizedBox(height: 12),
                  Text(errorMessage!,
                      style: TextStyle(color: AppColors.negative, fontSize: 13)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: isLoading ? null : () async {
                  final oldPin = oldPinController.text;
                  final newPin = newPinController.text;
                  final confirmPin = confirmPinController.text;

                  if (oldPin.length != 6) {
                    setState(() => errorMessage = 'Current PIN must be 6 digits');
                    return;
                  }
                  if (newPin.length != 6) {
                    setState(() => errorMessage = 'New PIN must be 6 digits');
                    return;
                  }
                  if (newPin != confirmPin) {
                    setState(() => errorMessage = 'New PINs do not match');
                    return;
                  }
                  if (oldPin == newPin) {
                    setState(() => errorMessage = 'New PIN must be different');
                    return;
                  }

                  setState(() => isLoading = true);

                  final walletsAsync = await ref.read(allWalletsProvider.future);
                  final walletIds = walletsAsync.map((w) => w.id).toList();

                  final success = await KeyManager.changePin(oldPin, newPin, walletIds: walletIds);

                  if (context.mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(context).pop();
                    messenger.showSnackBar(SnackBar(
                      content: Text(success
                          ? 'PIN changed successfully'
                          : 'Failed to change PIN. Check your current PIN.'),
                    ));
                  }
                },
                child: Text('Change', style: TextStyle(color: isLoading
                    ? AppColors.textTertiary : AppColors.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Appearance toggle tile ──────────────────────────────────────────────────

class _AppearanceTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeNotifier.instance,
      builder: (_, __) {
        final isDark = ThemeNotifier.instance.isDark;
        return _SettingsTile(
          icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          label: 'Appearance',
          value: isDark ? 'Dark' : 'Light',
          onTap: () { debugPrint('[TAP] Appearance toggle → ${isDark ? 'Light' : 'Dark'} (settings_screen.dart)'); ThemeNotifier.instance.setTheme(isDark ? 'Light' : 'Dark'); },
        );
      },
    );
  }
}

// ─── Biometric toggle tile ───────────────────────────────────────────────────

class _BiometricTile extends ConsumerWidget {
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.separator, width: 0.5),
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
    debugPrint('[TAP] Biometric Auth toggle → ${currentEnabled ? "disable" : "enable"} (settings_screen.dart)');

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

// ─── Auto-lock tile ──────────────────────────────────────────────────────────

class _AutoLockTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(autoLockTimeoutProvider);
    return _SettingsTile(
      icon: Icons.timer_outlined,
      label: 'Auto-Lock',
      value: current.displayName,
      onTap: () { debugPrint('[TAP] Auto-Lock picker (settings_screen.dart)'); _showPicker(context, ref, current); },
    );
  }

  void _showPicker(
      BuildContext context, WidgetRef ref, AutoLockTimeout current) {
    context.pushSlide(const AutoLockSelectorScreen());
  }
}

// ─── Currency picker tile ────────────────────────────────────────────────────

class _CurrencyTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(currencyProvider);
    return _SettingsTile(
      icon: Icons.currency_exchange_rounded,
      label: 'Currency',
      value: '${cur.currency.symbol}  ${cur.currency.code.toUpperCase()}',
      onTap: () => _showPicker(context, ref, cur.currency),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref, AppCurrency selected) {
    debugPrint('[TAP] Currency picker (settings_screen.dart)');
    context.pushSlide(const CurrencySelectorScreen());
  }
}

// ─── About tile (dynamic version) ────────────────────────────────────────────

class _AboutTile extends StatefulWidget {
  @override
  State<_AboutTile> createState() => _AboutTileState();
}

class _AboutTileState extends State<_AboutTile> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.info_outline_rounded,
      label: 'About',
      value: _version,
      onTap: () => debugPrint('[TAP] About (version=$_version) (settings_screen.dart)'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.color});
  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Text(title,
        style: TextStyle(
            color: color ?? AppColors.textSecondary,
            fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon, required this.label, required this.onTap,
    this.value, this.iconColor, this.labelColor,
  });
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final Color? iconColor, labelColor;

  @override
  Widget build(BuildContext context) => AnimatedTap(
    onTap: onTap,
    pressScale: 0.97,
    child: Container(
      margin: EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: labelColor ?? AppColors.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w400)),
        ),
        if (value != null)
          Text(value!, style: TextStyle(color: AppColors.textSecondary, fontSize: 14))
        else
          Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
      ]),
    ),
  );
}
