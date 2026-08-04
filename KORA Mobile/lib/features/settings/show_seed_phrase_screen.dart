import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';

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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Recovery Phrase',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.negative.withValues(alpha: 0.1),
                borderRadius: BorderRadius.zero,
                border: Border.all(color: AppColors.negative.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_rounded, color: AppColors.negative, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Never share your recovery phrase',
                            style: TextStyle(
                                color: AppColors.negative,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          'Anyone with your recovery phrase can access your wallet and steal your funds. Never share it with anyone.',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Seed phrase display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.zero,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                children: [
                  if (!_isRevealed)
                    Column(
                      children: [
                        Icon(Icons.visibility_off_rounded,
                            color: AppColors.textSecondary, size: 48),
                        const SizedBox(height: 16),
                        Text('Tap to reveal your recovery phrase',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() => _isRevealed = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textPrimary,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero),
                          ),
                          child: Text('Reveal Phrase',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: words.length,
                      itemBuilder: (context, index) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(
                                color: AppColors.border, width: 1),
                          ),
                          child: Row(
                            children: [
                              Text('${index + 1}.',
                                  style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(words[index],
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            if (_isRevealed) ...[
              const SizedBox(height: 20),
              // Copy button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.seedPhrase));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Recovery phrase copied to clipboard'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(Icons.copy_rounded, size: 18),
                  label: Text('Copy to Clipboard',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.card,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                      side: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                ),
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
