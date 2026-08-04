import 'package:flutter/material.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeNotifier.instance,
      builder: (_, __) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: koraAppBar(context, 'Privacy Policy',
            backLabel: 'Settings',
            onBack: () => Navigator.of(context).pop()),
        body: const SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: _PolicyContent(),
        ),
      ),
    );
  }
}

class _PolicyContent extends StatelessWidget {
  const _PolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EFFECTIVE MARCH 2026 · VERSION 3.5.0',
          style: kMonoText(AppColors.textTertiary, size: 10),
        ),
        const SizedBox(height: 16),
        const _PolicySection(
          title: 'NON-CUSTODIAL WALLET',
          body:
              'Kora Wallet is fully non-custodial. The developer does NOT have access '
              'to your private keys, seed phrases, PIN codes, or any other credentials '
              'at any time. The developer CANNOT initiate, authorize, or reverse '
              'transactions on your behalf. You retain full and exclusive control over '
              'your digital assets. If you lose your seed phrase or PIN, access to your '
              'funds cannot be recovered by anyone.',
        ),
        const _PolicySection(
          title: 'NO DATA COLLECTION',
          body:
              'Kora Wallet does not collect, transmit, or store any personal data on '
              'external servers. All private keys and credentials are stored exclusively '
              'on your local device using AES-256 encryption. No analytics, telemetry, '
              'usage statistics, or personally identifiable information is ever '
              'transmitted to the developer or any third party.',
        ),
        const _PolicySection(
          title: 'THIRD-PARTY SERVICES',
          body:
              'To provide balance and price information, the app connects to public '
              'blockchain nodes and market data APIs. Only your public wallet addresses '
              'are transmitted — never private keys or credentials. The developer is not '
              'responsible for the availability, accuracy, or security of any '
              'third-party service.',
        ),
        const _PolicySection(
          title: 'YOUR RESPONSIBILITIES',
          body:
              'You are solely responsible for: (1) safeguarding your seed phrase and '
              'PIN — loss means permanent loss of funds; (2) all transactions you '
              'confirm — blockchain transactions are irreversible; (3) compliance with '
              'all applicable laws and tax obligations in your jurisdiction; '
              '(4) maintaining the security of your device.',
        ),
        const _PolicySection(
          title: 'INTELLECTUAL PROPERTY',
          body:
              'Copyright © 2024–2026 Kora. All Rights Reserved.\n\n'
              'The Kora Wallet application — including its source code, design, '
              'branding, and all associated materials — is protected by copyright and '
              'intellectual property law. Unauthorized reproduction, distribution, '
              'modification, reverse engineering, or commercial use is strictly '
              'prohibited without prior written consent.',
        ),
        const _PolicySection(
          title: 'DISCLAIMER OF WARRANTIES',
          body:
              'Kora Wallet is provided "as is" and "as available" without warranties '
              'of any kind. The developer makes no warranty that the application will '
              'be uninterrupted, error-free, or free from harmful components.',
        ),
        const _PolicySection(
          title: 'LIMITATION OF LIABILITY',
          body:
              'To the maximum extent permitted by law, the developer shall not be '
              'liable for any damages arising from your use of the application, '
              'including loss of funds, loss of data, or unauthorized access — even '
              'if advised of the possibility of such damages. Your use of the '
              'application is entirely at your own risk.',
        ),
        const _PolicySection(
          title: 'SECURITY',
          body:
              'Industry-standard encryption is applied to all locally stored data. '
              'However, no system is completely secure. The developer assumes no '
              'liability for losses resulting from unauthorized device access, malware, '
              'phishing attacks, or operating system vulnerabilities. Use a trusted, '
              'secured device for managing cryptocurrency.',
        ),
        const _PolicySection(
          title: 'NO FINANCIAL ADVICE',
          body:
              'Nothing in this application constitutes financial, investment, legal, '
              'or tax advice. Cryptocurrency markets are volatile. The developer bears '
              'no responsibility for any financial decisions made using information '
              'provided by the application.',
        ),
        const _PolicySection(
          title: 'CHANGES TO THIS POLICY',
          body:
              'The developer reserves the right to update this policy at any time. '
              'Continued use of Kora Wallet following any changes constitutes '
              'acceptance of the revised terms.',
        ),
        const SizedBox(height: 8),
        Text(
          'COPYRIGHT © 2024–2026 KORA. ALL RIGHTS RESERVED.',
          style: kLabel(AppColors.textTertiary, size: 9, tracking: 0.12,
              weight: FontWeight.w400),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The heading is a section heading, set exactly as the ones over the wallet's
          // tables. The paragraph under it stays in the reading face — a page of legal
          // prose in tracked monospace is a page nobody finishes.
          Text(
            title,
            style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.18),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: kBody(AppColors.textSecondary, size: 13),
          ),
        ],
      ),
    );
  }
}
