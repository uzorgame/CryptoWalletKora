import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';
import 'package:kora/core/widgets/kora_button.dart';
import 'package:kora/core/widgets/kora_rows.dart';
import 'package:kora/core/widgets/word_grid.dart';

/// The recovery phrase, exactly the prototype's: a red-edged warning, the numbered word
/// grid, and one ghost button to copy. The words arrive blurred behind a TAP TO REVEAL
/// veil — they are the wallet, and a phrase should not be readable over a shoulder the
/// instant the screen opens.
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
          backLabel: 'Settings',
          onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KoraWarn(
              'Never share your recovery phrase. Anyone with these words can take your funds.',
              danger: true,
              margin: EdgeInsets.fromLTRB(22, 14, 22, 0),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
              child: WordGrid(
                words: words,
                revealed: _isRevealed,
                onReveal: () => setState(() => _isRevealed = true),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 34),
              child: KoraGhost(
                label: 'Copy to Clipboard',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.seedPhrase));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recovery phrase copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
