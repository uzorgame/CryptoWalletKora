import 'package:flutter/material.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';
import 'package:kora/core/widgets/kora_button.dart';
import 'package:kora/core/widgets/kora_field.dart';
import 'package:kora/core/widgets/input/numpad.dart';
import 'package:kora/core/widgets/word_grid.dart';
import 'package:kora/features/home/home_screen.dart';

class CreateWalletScreen extends ConsumerStatefulWidget {
  const CreateWalletScreen({super.key});
  @override
  ConsumerState<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends ConsumerState<CreateWalletScreen> with ThemeAwareMixin {
  final _nameCtrl    = TextEditingController(text: 'My Wallet');
  final _pinCtrl      = TextEditingController();
  final _pinConfCtrl  = TextEditingController();
  String _mnemonic        = '';
  bool   _mnemonicRevealed = false;
  bool   _confirmed       = false;
  bool   _loading         = false;
  bool   _hasAppPin       = false;
  String? _pinError;
  int _step = 0; // 0=name, 1=backup, 2=confirm, 3=pin

  // The PIN arrives through the wallet's own keypad — six square dots filling as it is
  // typed, exactly the prototype. Entered once to set, once more to confirm.
  String _pinEntry   = '';
  bool   _confirming = false;

  @override
  void initState() {
    super.initState();
    _mnemonic = bip39.generateMnemonic();
    KeyManager.hasAppPin().then((v) => setState(() => _hasAppPin = v));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    _pinConfCtrl.dispose();
    super.dispose();
  }

  List<String> get _words => _mnemonic.split(' ');

  void _next() {
    if (_step == 0) {
      if (_nameCtrl.text.trim().isEmpty) return;
      setState(() => _step = 1);
    } else if (_step == 1) {
      // The confirmation lives on the phrase screen now — you tick it while the words are
      // in front of you, not on a page of its own after they are gone. A separate screen
      // asking "did you write them down?" is a screen you learn to tap through.
      if (!_confirmed) return;
      setState(() {
        _step = 2;
        _pinCtrl.clear();
        _pinConfCtrl.clear();
        _pinError = null;
        _pinEntry = '';
        _confirming = false;
      });
    } else {
      _createWallet();
    }
  }

  // ─── The keypad fills the dots ───────────────────────────────────────────────

  void _pinDigit(String d) {
    if (_loading || _pinEntry.length >= 6) return;
    setState(() { _pinEntry += d; _pinError = null; });
    if (_pinEntry.length == 6) {
      Future.delayed(const Duration(milliseconds: 220), _pinFull);
    }
  }

  void _pinBackspace() {
    if (_loading || _pinEntry.isEmpty) return;
    setState(() => _pinEntry = _pinEntry.substring(0, _pinEntry.length - 1));
  }

  Future<void> _pinFull() async {
    if (!mounted || _pinEntry.length != 6) return;
    if (_hasAppPin) {
      _pinCtrl.text = _pinEntry;
      await _createWallet();
      if (mounted && _pinError != null) setState(() => _pinEntry = '');
      return;
    }
    if (!_confirming) {
      setState(() {
        _pinCtrl.text = _pinEntry;
        _pinEntry = '';
        _confirming = true;
      });
      return;
    }
    _pinConfCtrl.text = _pinEntry;
    await _createWallet();
    // A mismatch or a storage failure starts the entry over, from the first dot.
    if (mounted && _pinError != null) {
      setState(() {
        _pinEntry = '';
        _confirming = false;
        _pinCtrl.clear();
        _pinConfCtrl.clear();
      });
    }
  }

  Future<void> _createWallet() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length != 6 || int.tryParse(pin) == null) {
      setState(() => _pinError = 'PIN must be exactly 6 digits');
      return;
    }
    if (_hasAppPin) {
      setState(() { _loading = true; _pinError = null; });
      final valid = await KeyManager.verifyAppPin(pin);
      if (!valid) {
        if (mounted) setState(() { _loading = false; _pinError = 'Incorrect PIN'; });
        return;
      }
    } else {
      if (pin != _pinConfCtrl.text.trim()) {
        setState(() => _pinError = 'PINs do not match');
        return;
      }
      setState(() { _loading = true; _pinError = null; });
    }
    try {
      await ref.read(currentWalletProvider.notifier).createWallet(
        name: _nameCtrl.text.trim(),
        mnemonic: _mnemonic,
        pin: pin,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (r) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _step == 0 ? 'Create Wallet'
        : _step == 1 ? 'Recovery Phrase'
        : _hasAppPin ? 'Enter App PIN' : 'Set PIN';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: koraAppBar(context, title,
          backLabel: 'Back',
          onBack: _step == 0
              ? () => Navigator.of(context).pop()
              : () => setState(() => _step--)),
      body: SafeArea(
        // The step change travels: a fade with a short rise, on the house curve. An instant
        // swap reads as a glitch in a flow this deliberate.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: kEase,
          switchOutCurve: kEase,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.012), end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          ),
          child: _step == 0 ? _buildNameStep()
              : _step == 1 ? _buildPhraseStep()
              : _buildPinStep(),
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
          child: Text('Give your wallet a name',
              style: kBody(AppColors.textPrimary, size: 14, weight: FontWeight.w500)),
        ),
        const KoraSlabel('Name'),
        KoraField(
          child: TextField(
            controller: _nameCtrl,
            style: koraInputStyle(),
            decoration: koraInputDecoration('WALLET NAME'),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
          child: KoraCta(label: 'Continue', onTap: _next),
        ),
      ],
    );
  }

  Widget _buildPhraseStep() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
          child: Text(
            'Write down these 12 words in order and store them somewhere safe. Never share them with anyone.',
            style: kBody(AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: WordGrid(
            words: _words,
            revealed: _mnemonicRevealed,
            onReveal: () => setState(() => _mnemonicRevealed = true),
          ),
        ),
        const SizedBox(height: 16),
        if (_mnemonicRevealed)
          AnimatedTap(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _mnemonic));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')));
            },
            child: Center(
              child: Text('COPY TO CLIPBOARD',
                  style: kLabel(AppColors.textSecondary, size: 9.5, tracking: 0.14)),
            ),
          ),

        // The confirmation sits with the words it is about. The prototype's kcheckrow: a
        // bare square check and the sentence, no box around them — the check is the state.
        // It only appears once the phrase has been revealed; ticking "I saved it" over a
        // blur would be a promise about something never seen.
        if (_mnemonicRevealed)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
            child: AnimatedTap(
              onTap: () => setState(() => _confirmed = !_confirmed),
              pressScale: 0.99,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: kControl,
                  curve: kEase,
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: _confirmed ? AppColors.textPrimary : Colors.transparent,
                    border: Border.all(
                        color: _confirmed ? AppColors.textPrimary : AppColors.borderHi,
                        width: 1),
                  ),
                  child: _confirmed
                      ? Icon(Icons.check_rounded, color: AppColors.background, size: 13)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I have securely saved my recovery phrase.',
                    style: kBody(AppColors.textPrimary, size: 13),
                  ),
                ),
              ]),
            ),
          ),

        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
          child: KoraCta(label: 'Continue', onTap: _confirmed ? _next : null),
        ),
      ],
    );
  }

  Widget _buildPinStep() {
    final prompt = _hasAppPin
        ? 'Enter your 6-digit app PIN to add this wallet.'
        : _confirming
            ? 'Enter the same PIN once more to confirm.'
            : 'Create a 6-digit PIN to protect your wallet.';
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
          child: Text(prompt,
              textAlign: TextAlign.center,
              style: kBody(AppColors.textSecondary).copyWith(height: 1.55)),
        ),
        const SizedBox(height: 18),
        _PinDots(filled: _pinEntry.length),
        if (_pinError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: Text(_pinError!.toUpperCase(),
                textAlign: TextAlign.center,
                style: kLabel(AppColors.negative, size: 9.5, tracking: 0.1)),
          ),
        const Spacer(),
        Numpad(
          onDigit: _pinDigit,
          onBackspace: _pinBackspace,
          loading: _loading,
        ),
        const SizedBox(height: 26),
      ],
    );
  }
}

/// Six square dots that fill as the PIN is typed — the prototype's kdots, shared by the
/// lock screen and every place a PIN is set.
class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled});
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 6; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          AnimatedContainer(
            duration: kControl,
            curve: kEase,
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: i < filled ? AppColors.textPrimary : Colors.transparent,
              border: Border.all(
                  color: i < filled ? AppColors.textPrimary : AppColors.borderHi,
                  width: 1),
            ),
          ),
        ],
      ],
    );
  }
}
