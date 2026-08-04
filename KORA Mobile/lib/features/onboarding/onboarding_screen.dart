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
              const Spacer(flex: 2),
              const Center(child: KoraMark(size: 64)),
              const SizedBox(height: 28),
              Text(
                'Welcome to\nKora Wallet',
                textAlign: TextAlign.center,
                style: kNum(AppColors.textPrimary, size: 30, weight: FontWeight.w600)
                    .copyWith(height: 1.15),
              ),
              const SizedBox(height: 14),
              Text(
                'The secure, self-custody crypto wallet.\nYour keys, your coins.',
                textAlign: TextAlign.center,
                style: kBody(AppColors.textSecondary, size: 14),
              ),
              const Spacer(flex: 2),
              const _FeatureRow(),
              const SizedBox(height: 36),
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
              const SizedBox(height: 32),
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
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
      decoration: BoxDecoration(border: kHairline()),
      child: Text(label.toUpperCase(),
          style: kLabel(AppColors.textSecondary, size: 8.5, tracking: 0.12)),
    );
  }
}
