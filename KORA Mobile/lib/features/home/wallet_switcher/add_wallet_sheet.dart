import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/features/onboarding/create_wallet_screen.dart';
import 'package:kora/features/onboarding/import_wallet_screen.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

// The sheet offering the two ways to add a wallet: create new, or import from a phrase.

class AddWalletSheet extends StatelessWidget {
  const AddWalletSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.zero,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.zero),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Add Wallet',
              style: kNum(AppColors.textPrimary, size: 17, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Create a brand-new wallet or restore one from a recovery phrase.',
              style: kBody(AppColors.textSecondary, size: 14),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              _AddWalletOption(
                icon: Icons.add_circle_outline_rounded,
                title: 'Create New Wallet',
                subtitle: 'Generate a fresh wallet with a new recovery phrase',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateWalletScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _AddWalletOption(
                icon: Icons.file_download_outlined,
                title: 'Import Existing Wallet',
                subtitle: 'Restore a wallet using your 12-word recovery phrase',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ImportWalletScreen(),
                    ),
                  );
                },
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AddWalletOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AddWalletOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: kBody(AppColors.textPrimary, size: 15, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: kBody(AppColors.textSecondary, size: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary, size: 20),
        ]),
      ),
    );
  }
}
