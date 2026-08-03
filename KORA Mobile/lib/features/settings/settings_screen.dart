import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/services/biometric_service.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/state/providers/settings_provider.dart' hide currencyProvider;
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/repositories/wallet_repository.dart';
import 'package:kora/features/onboarding/onboarding_screen.dart';
import 'package:kora/features/onboarding/wallet_selection_screen.dart';
import 'package:kora/features/settings/show_seed_phrase_screen.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/features/settings/privacy_policy_screen.dart';
import 'package:kora/features/settings/widgets/section_header.dart';
import 'package:kora/features/settings/widgets/settings_tile.dart';
import 'package:kora/features/settings/tiles/appearance_tile.dart';
import 'package:kora/features/settings/tiles/biometric_tile.dart';
import 'package:kora/features/settings/tiles/auto_lock_tile.dart';
import 'package:kora/features/settings/tiles/currency_tile.dart';
import 'package:kora/features/settings/tiles/about_tile.dart';

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
            SectionHeader('Security'),
            SettingsTile(
              icon: Icons.lock_outline_rounded,
              label: 'Change PIN',
              onTap: () { debugPrint('[TAP] Change PIN (settings_screen.dart)'); _showChangePinDialog(context, ref); },
            ),
            BiometricTile(),
            AutoLockTile(),
            SettingsTile(
              icon: Icons.key_rounded,
              label: 'Show Seed Phrase',
              onTap: () { debugPrint('[TAP] Show Seed Phrase (settings_screen.dart)'); _showSeedPhrase(context, ref); },
            ),
            SizedBox(height: 20),

            // General section
            SectionHeader('General'),
            AppearanceTile(),
            CurrencyTile(),
            SettingsTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () { debugPrint('[TAP] Privacy Policy (settings_screen.dart)'); context.pushSlide(const PrivacyPolicyScreen()); },
            ),
            AboutTile(),
            SizedBox(height: 20),

            // Danger zone
            SectionHeader('Wallet', color: AppColors.negative),
            SettingsTile(
              icon: Icons.add_circle_outline_rounded,
              label: 'Add / Import Wallet',
              iconColor: AppColors.accent,
              onTap: () { debugPrint('[TAP] Add/Import Wallet (settings_screen.dart)'); context.pushSlide(const OnboardingScreen()); },
            ),
            SettingsTile(
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

// ─── Biometric toggle tile ───────────────────────────────────────────────────

// ─── Auto-lock tile ──────────────────────────────────────────────────────────

// ─── Currency picker tile ────────────────────────────────────────────────────

// ─── About tile (dynamic version) ────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
