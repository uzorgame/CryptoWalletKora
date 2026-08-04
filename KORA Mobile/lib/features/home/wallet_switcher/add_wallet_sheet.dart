import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_rows.dart';
import 'package:kora/features/onboarding/create_wallet_screen.dart';
import 'package:kora/features/onboarding/import_wallet_screen.dart';

// The sheet offering the two ways to add a wallet: create new, or import from a phrase.
//
// The prototype's k-addwallet: a square sheet, one sentence of explanation, then the two
// ways as hairline rows — a heading and the line under it saying what each will do.

class AddWalletSheet extends StatelessWidget {
  const AddWalletSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderHi, width: 1)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(width: 24, height: 2, color: AppColors.textTertiary),
          const SizedBox(height: 18),
          Text('ADD WALLET',
              style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.18)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'Create a brand-new wallet or restore one from a recovery phrase.',
              textAlign: TextAlign.center,
              style: kBody(AppColors.textSecondary, size: 13),
            ),
          ),
          const SizedBox(height: 16),
          _Option(
            title: 'Create new wallet',
            subtitle: 'Generate a fresh recovery phrase',
            topLine: true,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CreateWalletScreen()),
              );
            },
          ),
          _Option(
            title: 'Import existing wallet',
            subtitle: 'Restore from your 12-word phrase',
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ImportWalletScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.topLine = false,
  });
  final String title, subtitle;
  final VoidCallback onTap;
  final bool topLine;

  @override
  Widget build(BuildContext context) => KoraRow(
        onTap: onTap,
        topLine: topLine,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title.toUpperCase(),
                  style: kLabel(AppColors.textPrimary, size: 12.5, tracking: 0.06)),
              const SizedBox(height: 4),
              Text(subtitle.toUpperCase(),
                  style: kMonoText(AppColors.textSecondary, size: 10)),
            ]),
          ),
          Text('›', style: kMonoText(AppColors.textSecondary, size: 13)),
        ],
      );
}
