import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';
import 'kora_button.dart';
import 'kora_field.dart';
import 'kora_sheet.dart';

/// Asks for the app passphrase before something irreversible.
///
/// One passphrase guards the app, so everything destructive or outgoing asks for the same
/// one — deleting a wallet, revealing a recovery phrase, signing a transaction. Presenting
/// them identically is the point: the moment of being asked should feel the same every time,
/// so it stays a moment of attention rather than a reflex.
///
/// Returns the entered passphrase, or null if the user backed out. Verification belongs to
/// the caller, which is the code that knows what it is about to do.
Future<String?> askPassphrase(
  BuildContext context, {
  required String title,
  required String explanation,
  String confirmLabel = 'CONFIRM',
  bool danger = false,
}) {
  return showKoraSheet<String>(
    context,
    builder: (context) => _PassphraseSheet(
      title: title,
      explanation: explanation,
      confirmLabel: confirmLabel,
      danger: danger,
    ),
  );
}

class _PassphraseSheet extends StatefulWidget {
  const _PassphraseSheet({
    required this.title,
    required this.explanation,
    required this.confirmLabel,
    required this.danger,
  });

  final String title;
  final String explanation;
  final String confirmLabel;
  final bool danger;

  @override
  State<_PassphraseSheet> createState() => _PassphraseSheetState();
}

class _PassphraseSheetState extends State<_PassphraseSheet> {
  final _controller = TextEditingController();
  bool _empty = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _empty = true);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return KoraSheet(
      title: widget.title,
      subtitle: 'APP PASSPHRASE',
      body: [
        Text(
          widget.explanation,
          textAlign: TextAlign.center,
          style: koraLabel(p.text3, size: 9.5, tracking: 0).copyWith(height: 1.6),
        ),
        const SizedBox(height: 18),
        KoraField(
          label: 'PASSPHRASE',
          controller: _controller,
          obscure: true,
          autofocus: true,
          placeholder: '••••••••',
          error: _empty,
          hint: _empty
              ? 'Enter the app passphrase to continue.'
              : 'One passphrase covers every wallet in KORA.',
          onSubmitted: (_) => _submit(),
        ),
      ],
      actions: [
        KoraButton(
          label: 'CANCEL',
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        KoraButton(
          label: widget.confirmLabel,
          expand: true,
          tone: widget.danger ? KoraButtonTone.danger : KoraButtonTone.primary,
          onPressed: _submit,
        ),
      ],
    );
  }
}
