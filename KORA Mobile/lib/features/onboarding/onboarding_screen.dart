import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_button.dart';
import 'package:kora/core/widgets/kora_mark.dart';
import 'package:kora/features/onboarding/create_wallet_screen.dart';
import 'package:kora/features/onboarding/import_wallet_screen.dart';

// The first screen a new install shows: the mark, the promise, the two ways in.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The prototype's order: mark, words, then the three claims right under
              // them — one composed block, with all the air below it.
              const SizedBox(height: 84),
              const Center(child: KoraMark(size: 64)),
              const SizedBox(height: 26),
              Text(
                'Welcome to\nKora Wallet',
                textAlign: TextAlign.center,
                style: kNum(AppColors.textPrimary, size: 30, weight: FontWeight.w600)
                    .copyWith(height: 1.15),
              ),
              const SizedBox(height: 12),
              Text(
                'The secure, self-custody crypto wallet.\nYour keys, your coins.',
                textAlign: TextAlign.center,
                style: kBody(AppColors.textSecondary, size: 13).copyWith(height: 1.55),
              ),
              const SizedBox(height: 26),
              const _FeatureRow(),
              const Spacer(),
              KoraCta(
                label: 'Create New Wallet',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const CreateWalletScreen()),
                ),
              ),
              const SizedBox(height: 10),
              KoraGhost(
                label: 'Import Existing Wallet',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const ImportWalletScreen()),
                ),
              ),
              const SizedBox(height: 44),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three claims in three hairline tags — text is the ornament here, not icons.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _FeatureTag('Self-custody'),
        SizedBox(width: 8),
        _FeatureTag('Multi-chain'),
        SizedBox(width: 8),
        _FeatureTag('Secure'),
      ],
    );
  }
}

class _FeatureTag extends StatelessWidget {
  const _FeatureTag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(border: kHairline()),
      child: Text(label.toUpperCase(),
          style: kLabel(AppColors.textSecondary, size: 8, tracking: 0.1)),
    );
  }
}
