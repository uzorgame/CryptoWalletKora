import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/crypto/mnemonic.dart';
import '../../core/theme/kora_design.dart';
import '../common/kora_button.dart';
import '../common/kora_field.dart';
import 'onboarding_controller.dart';
import 'onboarding_scaffold.dart';
import 'word_grid.dart';

/// The result of a completed flow, handed to whoever asked for it.
class OnboardingResult {
  const OnboardingResult({
    required this.name,
    required this.mnemonic,
    required this.mode,
    this.passphrase,
  });

  final String name;
  final String mnemonic;
  final OnboardingMode mode;

  /// Set only on a first run, where the flow also establishes the app passphrase.
  final String? passphrase;
}

/// Creating or restoring a wallet, and the very first launch when there is nothing to open.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.firstRun,
    required this.existingNames,
    required this.onDone,
    this.onCancel,
  });

  final bool firstRun;
  final List<String> existingNames;
  final ValueChanged<OnboardingResult> onDone;

  /// Absent on a first run: there is nowhere to cancel to.
  final VoidCallback? onCancel;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final OnboardingController _flow = OnboardingController(
    firstRun: widget.firstRun,
    existingNames: widget.existingNames,
  );

  final _name = TextEditingController();
  final _passphrase = TextEditingController();
  final _repeat = TextEditingController();
  final _checks = List.generate(3, (_) => TextEditingController());
  final _restore = List.generate(12, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _flow.addListener(_onFlow);
    _name.text = _flow.name;
  }

  void _onFlow() => setState(() {});

  @override
  void dispose() {
    _flow.removeListener(_onFlow);
    _flow.dispose();
    _name.dispose();
    _passphrase.dispose();
    _repeat.dispose();
    for (final c in [..._checks, ..._restore]) {
      c.dispose();
    }
    super.dispose();
  }

  void _finish() => widget.onDone(
        OnboardingResult(
          name: _flow.name,
          mnemonic: _flow.mnemonic,
          mode: _flow.mode ?? OnboardingMode.create,
          passphrase: widget.firstRun ? _passphrase.text : null,
        ),
      );

  /// A phrase pasted into any box fills the rest, because that is how one arrives from a
  /// password manager — as twelve words at once, not typed one at a time.
  void _spreadPaste(int index, String value) {
    final parts = value.trim().toLowerCase().split(RegExp(r'\s+'));
    if (parts.length < 2) return;
    for (var i = 0; i < parts.length && index + i < _restore.length; i++) {
      _restore[index + i].text = parts[i];
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => switch (_flow.step) {
        OnboardingStep.choose => _choose(),
        OnboardingStep.name => _nameStep(),
        OnboardingStep.phrase => _phraseStep(),
        OnboardingStep.verify => _verifyStep(),
        OnboardingStep.restore => _restoreStep(),
        OnboardingStep.passphrase => _passphraseStep(),
        OnboardingStep.done => _doneStep(),
      };

  Widget _choose() {
    final p = Kora.of(context);
    return OnboardingScaffold(
      showMark: true,
      title: widget.firstRun ? 'Welcome to KORA' : 'Add a wallet',
      note: widget.firstRun
          ? 'There is no wallet on this computer yet. Create one, or restore a wallet you '
              'already own from its recovery phrase.'
          : 'A new key set under the same app passphrase. Every wallet in KORA is unlocked '
              'by the one you already use.',
      step: _flow.stepIndex,
      stepCount: _flow.stepCount,
      // Shown only when there is somewhere to go back to, and wired to it. It used to be
      // rendered with a null handler, so adding a second wallet put the user on a screen whose
      // only way out was to pick one of the two options or close the app.
      actions: widget.onCancel == null
          ? const []
          : [
              const OnboardingSpacer(),
              KoraButton(label: 'CANCEL', expand: true, onPressed: widget.onCancel),
            ],
      child: SizedBox(
        width: 460,
        child: Container(
          decoration: BoxDecoration(color: p.border, border: Border.all(color: p.border)),
          child: Column(
            children: [
              _Choice(
                title: 'CREATE A NEW WALLET',
                note: 'Generates a fresh recovery phrase. Write it down — it is the only '
                    'way back in.',
                onTap: () => _flow.choose(OnboardingMode.create),
              ),
              const SizedBox(height: 1),
              _Choice(
                title: 'RESTORE FROM A RECOVERY PHRASE',
                note: 'Twelve words from a wallet you already have, here or in another app.',
                onTap: () => _flow.choose(OnboardingMode.restore),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nameStep() => OnboardingScaffold(
        title: 'Name this wallet',
        note: 'Only you see this. It is how the wallet is labelled in the switcher and on '
            'the portfolio.',
        step: _flow.stepIndex,
        stepCount: _flow.stepCount,
        actions: [
          OnboardingActions.back(_flow.back),
          const OnboardingSpacer(),
          OnboardingActions.next('CONTINUE', () => _flow.submitName(_name.text)),
        ],
        child: SizedBox(
          width: 460,
          child: KoraField(
            label: 'WALLET NAME',
            controller: _name,
            autofocus: true,
            error: _flow.error.isNotEmpty,
            hint: _flow.error.isEmpty ? null : _flow.error,
            onSubmitted: (value) => _flow.submitName(value),
          ),
        ),
      );

  Widget _phraseStep() => OnboardingScaffold(
        title: 'Your recovery phrase',
        note: 'Write these twelve words down in order and keep them offline. Anyone who has '
            'them owns this wallet. KORA cannot show them again.',
        step: _flow.stepIndex,
        stepCount: _flow.stepCount,
        actions: [
          OnboardingActions.back(_flow.back),
          _CopyPhrase(mnemonic: _flow.mnemonic),
          OnboardingActions.next('I HAVE WRITTEN IT DOWN', _flow.phraseWritten),
        ],
        child: WordGrid.display(words: _flow.words),
      );

  Widget _verifyStep() => OnboardingScaffold(
        title: 'Confirm the phrase',
        note: 'Type the words at these positions. This is the only check that the phrase '
            'left the screen.',
        step: _flow.stepIndex,
        stepCount: _flow.stepCount,
        actions: [
          OnboardingActions.back(_flow.back),
          const OnboardingSpacer(),
          OnboardingActions.next(
            'CONTINUE',
            () => _flow.submitVerification([for (final c in _checks) c.text]),
          ),
        ],
        child: SizedBox(
          width: 460,
          child: Column(
            children: [
              for (final (i, index) in _flow.checkIndices.indexed) ...[
                if (i > 0) const SizedBox(height: 16),
                KoraField(
                  label: 'WORD ${(index + 1).toString().padLeft(2, '0')}',
                  controller: _checks[i],
                  autofocus: i == 0,
                ),
              ],
              if (_flow.error.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Error(_flow.error),
              ],
            ],
          ),
        ),
      );

  Widget _restoreStep() => OnboardingScaffold(
        title: 'Enter your recovery phrase',
        note: 'Twelve words, in order. Paste into the first box to fill them all at once.',
        step: _flow.stepIndex,
        stepCount: _flow.stepCount,
        actions: [
          OnboardingActions.back(_flow.back),
          const OnboardingSpacer(),
          OnboardingActions.next(
            'CONTINUE',
            () => _flow.submitRestoredPhrase([for (final c in _restore) c.text]),
          ),
        ],
        child: Column(
          children: [
            WordGrid.input(
              controllers: _restore,
              onPaste: _spreadPaste,
              highlight: _flow.error.isEmpty
                  ? const {}
                  : {
                      for (final (i, c) in _restore.indexed)
                        if (c.text.trim().isEmpty ||
                            !MnemonicService.validate(
                              MnemonicService.joinWords(
                                [for (final x in _restore) x.text.trim().toLowerCase()],
                              ),
                            ))
                          i,
                    },
            ),
            if (_flow.error.isNotEmpty) ...[
              const SizedBox(height: 14),
              _Error(_flow.error),
            ],
          ],
        ),
      );

  Widget _passphraseStep() => OnboardingScaffold(
        title: 'Set the app passphrase',
        note: 'One passphrase unlocks KORA and everything in it. It is not the recovery '
            'phrase, and it never leaves this computer.',
        step: _flow.stepIndex,
        stepCount: _flow.stepCount,
        actions: [
          OnboardingActions.back(_flow.back),
          const OnboardingSpacer(),
          OnboardingActions.next(
            'FINISH',
            () => _flow.submitPassphrase(_passphrase.text, _repeat.text),
          ),
        ],
        child: SizedBox(
          width: 460,
          child: Column(
            children: [
              KoraField(
                label: 'PASSPHRASE',
                controller: _passphrase,
                obscure: true,
                autofocus: true,
                placeholder: '••••••••',
              ),
              const SizedBox(height: 16),
              KoraField(
                label: 'REPEAT',
                controller: _repeat,
                obscure: true,
                placeholder: '••••••••',
                error: _flow.error.isNotEmpty,
                hint: _flow.error.isEmpty ? null : _flow.error,
              ),
            ],
          ),
        ),
      );

  Widget _doneStep() => OnboardingScaffold(
        showMark: true,
        title: '${_flow.name} is ready',
        note: _flow.mode == OnboardingMode.restore
            ? 'Balances appear as the networks are scanned.'
            : 'Receive to any of its addresses to fund it.',
        step: _flow.stepIndex,
        stepCount: _flow.stepCount,
        actions: [
          const OnboardingSpacer(),
          OnboardingActions.next('OPEN WALLET', _finish),
        ],
        child: const SizedBox.shrink(),
      );
}

class _Choice extends StatefulWidget {
  const _Choice({required this.title, required this.note, required this.onTap});

  final String title;
  final String note;
  final VoidCallback onTap;

  @override
  State<_Choice> createState() => _ChoiceState();
}

class _ChoiceState extends State<_Choice> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: kControl,
          curve: kEase,
          width: double.infinity,
          color: _hover ? p.surfaceHi : p.surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Colour is set explicitly: a button does not inherit the page's ink, it starts
              // at the platform's own button text, which on a dark panel is invisible.
              Text(widget.title, style: koraLabel(p.text, size: 11, tracking: 0.16)),
              const SizedBox(height: 6),
              Text(widget.note, style: koraBody(p.text2, size: 11).copyWith(height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
        message,
        textAlign: TextAlign.center,
        style: koraLabel(Kora.of(context).down, size: 9.5, tracking: 0),
      );
}

class _CopyPhrase extends StatefulWidget {
  const _CopyPhrase({required this.mnemonic});

  final String mnemonic;

  @override
  State<_CopyPhrase> createState() => _CopyPhraseState();
}

class _CopyPhraseState extends State<_CopyPhrase> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) => KoraButton(
        label: _copied ? 'COPIED' : 'COPY',
        expand: true,
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: widget.mnemonic));
          if (!mounted) return;
          setState(() => _copied = true);
          await Future<void>.delayed(const Duration(milliseconds: 1400));
          if (mounted) setState(() => _copied = false);
        },
      );
}
