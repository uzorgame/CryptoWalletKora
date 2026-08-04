import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';
import 'package:kora/core/widgets/kora_button.dart';

class ShowSeedPhraseScreen extends ConsumerStatefulWidget {
  const ShowSeedPhraseScreen({super.key, required this.seedPhrase});

  final String seedPhrase;

  @override
  ConsumerState<ShowSeedPhraseScreen> createState() => _ShowSeedPhraseScreenState();
}

class _ShowSeedPhraseScreenState extends ConsumerState<ShowSeedPhraseScreen> with ThemeAwareMixin {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    final words = widget.seedPhrase.split(' ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: koraAppBar(context, 'Recovery Phrase',
          onBack: () => Navigator.of(context).pop()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.negative, width: 2),
                  top: kHairlineSide(), right: kHairlineSide(), bottom: kHairlineSide(),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEVER SHARE YOUR RECOVERY PHRASE',
                      style: kLabel(AppColors.negative, size: 9.5, tracking: 0.12)),
                  const SizedBox(height: 6),
                  Text(
                    'ANYONE WITH YOUR RECOVERY PHRASE CAN ACCESS YOUR WALLET AND STEAL YOUR FUNDS.',
                    style: kLabel(AppColors.textTertiary, size: 8.5, tracking: 0.08,
                            weight: FontWeight.w400)
                        .copyWith(height: 1.8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Seed phrase display
            Container(
              padding: EdgeInsets.all(_isRevealed ? 0 : 26),
              decoration: BoxDecoration(
                border: _isRevealed ? null : kHairline(),
              ),
              child: Column(
                children: [
                  if (!_isRevealed)
                    Column(
                      children: [
                        Icon(Icons.visibility_off_rounded,
                            color: AppColors.textTertiary, size: 22),
                        const SizedBox(height: 14),
                        Text('TAP TO REVEAL YOUR RECOVERY PHRASE',
                            textAlign: TextAlign.center,
                            style: kLabel(AppColors.textTertiary, size: 9.5,
                                tracking: 0.14)),
                        const SizedBox(height: 18),
                        KoraCta(
                          label: 'Reveal Phrase',
                          onTap: () => setState(() => _isRevealed = true),
                        ),
                      ],
                    )
                  else
                    Container(
                      decoration:
                          BoxDecoration(color: AppColors.border, border: kHairline()),
                      child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.9,
                        crossAxisSpacing: 1,
                        mainAxisSpacing: 1,
                      ),
                      itemCount: words.length,
                      itemBuilder: (context, index) {
                        return Container(
                          color: AppColors.background,
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          child: Row(
                            children: [
                              Text((index + 1).toString().padLeft(2, '0'),
                                  style: kMonoText(AppColors.textTertiary, size: 8.5)),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(words[index],
                                    style: kMonoText(AppColors.textPrimary, size: 10.5,
                                        weight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    ),
                ],
              ),
            ),

            if (_isRevealed) ...[
              const SizedBox(height: 20),
              // Copy button
              KoraGhost(
                label: 'Copy to Clipboard',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.seedPhrase));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Recovery phrase copied to clipboard'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 24),

            // Instructions
            Text('How to keep your recovery phrase safe:',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildInstruction('1', 'Write it down on paper and store it in a safe place'),
            _buildInstruction('2', 'Never store it digitally (screenshots, cloud, etc.)'),
            _buildInstruction('3', 'Never share it with anyone, including support staff'),
            _buildInstruction('4', 'Keep multiple copies in different secure locations'),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: AppColors.surface),
            alignment: Alignment.center,
            child: Text(number,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
