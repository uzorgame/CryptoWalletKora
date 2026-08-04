import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/services/biometric_service.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/state/providers/settings_provider.dart' hide currencyProvider;
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';
import 'package:kora/core/widgets/kora_mark.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/features/home/wallet_switcher/wallet_switcher_sheet.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/repositories/wallet_repository.dart';
import 'package:kora/features/onboarding/onboarding_screen.dart';
import 'package:kora/features/onboarding/wallet_selection_screen.dart';
import 'package:kora/features/settings/show_seed_phrase_screen.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/features/settings/privacy_policy_screen.dart';
import 'package:kora/core/widgets/pin_gate.dart';
import 'package:kora/features/address_book/address_book_screen.dart';
import 'package:kora/features/settings/widgets/change_pin_sheet.dart';
import 'package:kora/features/settings/widgets/section_header.dart';
import 'package:kora/features/settings/widgets/settings_tile.dart';
import 'package:kora/features/settings/tiles/appearance_tile.dart';
import 'package:kora/features/settings/tiles/biometric_tile.dart';
import 'package:kora/features/settings/tiles/auto_lock_tile.dart';
import 'package:kora/features/settings/tiles/currency_tile.dart';
import 'package:kora/features/settings/tiles/about_tile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.onExit});

  /// Living as tab 04, the header still offers the named way back the rest of the app has —
  /// it returns to the wallet rather than popping a route.
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(currentWalletProvider);
    final wallet = walletAsync.value;

    return ListenableBuilder(
      listenable: ThemeNotifier.instance,
      builder: (_, __) => Scaffold(
      backgroundColor: AppColors.background,
      appBar: koraAppBar(context, 'Settings',
          backLabel: 'Wallet',
          onBack: onExit ?? () => Navigator.of(context).maybePop()),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // The open wallet, and the way to another one: the same switcher the home
            // header opens, so the current wallet is changed from either place — and, either
            // way, only behind the app PIN.
            AnimatedTap(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => const WalletSwitcherSheet(),
              ),
              pressScale: 0.98,
              pressOpacity: 0.85,
              child: Container(
                margin: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(color: AppColors.surface, border: kHairline()),
                child: Row(children: [
                  const KoraMark(size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text((wallet?.name ?? 'No Wallet').toUpperCase(),
                        style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.14)),
                  ),
                  Text('▾', style: kLabel(AppColors.textSecondary, size: 9)),
                ]),
              ),
            ),

            // Security — the prototype's order: PIN, phrase, biometrics, auto-lock.
            SectionHeader('Security'),
            SettingsTile(
              icon: Icons.lock_outline_rounded,
              label: 'Change PIN',
              onTap: () { _showChangePinDialog(context, ref); },
            ),
            SettingsTile(
              icon: Icons.key_rounded,
              label: 'Show seed phrase',
              onTap: () { _showSeedPhrase(context, ref); },
            ),
            BiometricTile(),
            AutoLockTile(),

            // General
            SectionHeader('General'),
            AppearanceTile(),
            CurrencyTile(),
            SettingsTile(
              icon: Icons.book_outlined,
              label: 'Address book',
              onTap: () { context.pushSlide(const AddressBookScreen()); },
            ),
            SettingsTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy policy',
              onTap: () { context.pushSlide(const PrivacyPolicyScreen()); },
            ),
            AboutTile(),

            // The group that can lose a wallet is headed in the negative colour.
            SectionHeader('Wallet', color: AppColors.negative),
            SettingsTile(
              icon: Icons.add_circle_outline_rounded,
              label: 'Add / import wallet',
              onTap: () { context.pushSlide(const OnboardingScreen()); },
            ),
            SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Remove wallet',
              labelColor: AppColors.negative,
              onTap: () { _confirmRemoveWallet(context, ref); },
            ),
            SizedBox(height: 34),
          ],
        ),
      ),
    ));
  }

  void _confirmRemoveWallet(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.borderHi, width: 1),
            borderRadius: BorderRadius.zero),
        title: Text('REMOVE WALLET',
            style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.16)),
        content: Text(
            'Make sure you have your recovery phrase before removing this wallet. '
            'Without it the funds cannot be recovered by anyone.',
            style: kBody(AppColors.textSecondary, size: 13)),
        actions: [
          TextButton(
            onPressed: () { Navigator.of(context).pop(); },
            child: Text('CANCEL',
                style: kLabel(AppColors.textSecondary, size: 9.5, tracking: 0.16)),
          ),
          TextButton(
            onPressed: () async {
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
            child: Text('REMOVE',
                style: kLabel(AppColors.negative, size: 9.5, tracking: 0.16)),
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

    // The wallet's own gate, not a Material dialog with a floating label.
    if (!context.mounted) return;
    final pin = await askAppPinValue(
      context,
      title: 'Recovery phrase',
      explanation: 'Enter your app PIN to reveal the words for this wallet.',
    );
    if (pin == null || !context.mounted) return;
    final seed = await KeyManager.getSeedPhrase(pin, walletId: wallet.id);
    if (seed == null || !context.mounted) return;
    context.pushFade(ShowSeedPhraseScreen(seedPhrase: seed));
  }

  Future<void> _showChangePinDialog(BuildContext context, WidgetRef ref) async {
    final changed = await showChangePinSheet(context, ref);
    if (changed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN changed')),
      );
    }
  }
}

// ─── Appearance toggle tile ──────────────────────────────────────────────────

// ─── Biometric toggle tile ───────────────────────────────────────────────────

// ─── Auto-lock tile ──────────────────────────────────────────────────────────

// ─── Currency picker tile ────────────────────────────────────────────────────

// ─── About tile (dynamic version) ────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
