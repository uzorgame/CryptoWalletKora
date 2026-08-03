import 'package:flutter/material.dart';

import '../../core/crypto/key_manager.dart';
import '../../core/theme/kora_design.dart';
import '../common/kora_button.dart';
import '../common/kora_field.dart';
import '../common/tracked_text.dart';

/// The app passphrase, on a page of its own.
///
/// Verification happens here rather than at the point of use so that a wrong passphrase costs
/// nothing: nothing has been decrypted, no request has gone out, and the user simply types it
/// again. The count is shown because silently allowing unlimited attempts and silently
/// limiting them look identical until the moment you are locked out.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _controller = TextEditingController();
  bool _checking = false;
  bool _wrong = false;
  int _attempts = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final entered = _controller.text.trim();
    if (entered.isEmpty || _checking) return;

    setState(() {
      _checking = true;
      _wrong = false;
    });

    final ok = await KeyManager.verifyAppPin(entered);
    if (!mounted) return;

    if (ok) {
      widget.onUnlocked();
      return;
    }
    _controller.clear();
    setState(() {
      _checking = false;
      _wrong = true;
      _attempts++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TrackedText('KORA', style: koraLabel(p.text, size: 22, tracking: 0.5)),
              const SizedBox(height: 10),
              TrackedText('LOCKED', style: koraLabel(p.text3, size: 9.5, tracking: 0.3)),
              const SizedBox(height: 32),
              KoraField(
                label: 'PASSPHRASE',
                controller: _controller,
                obscure: true,
                autofocus: true,
                // No placeholder. Centred text puts the caret in the middle of the field, and
                // a centred row of placeholder dots then has the caret sitting inside it. The
                // label above and the hint below already say what goes here.
                centred: true,
                error: _wrong,
                hint: _wrong
                    ? 'That is not the passphrase.'
                    '${_attempts > 2 ? ' Attempt $_attempts.' : ''}'
                    : 'Nothing is decrypted until this is right.',
                onSubmitted: (_) => _unlock(),
              ),
              const SizedBox(height: 18),
              KoraButton(
                label: _checking ? 'CHECKING…' : 'UNLOCK',
                tone: KoraButtonTone.primary,
                expand: true,
                onPressed: _checking ? null : _unlock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
