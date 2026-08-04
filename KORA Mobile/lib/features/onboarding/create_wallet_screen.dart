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
  bool   _pinObscure      = true;
  bool   _hasAppPin       = false;
  String? _pinError;
  int _step = 0; // 0=name, 1=backup, 2=confirm, 3=pin

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
      setState(() { _step = 2; _confirmed = false; });
    } else if (_step == 2) {
      if (!_confirmed) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please confirm you have saved your recovery phrase')));
        return;
      }
      setState(() { _step = 3; _pinCtrl.clear(); _pinConfCtrl.clear(); _pinError = null; });
    } else {
      _createWallet();
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
        : _step == 2 ? 'Confirm Backup'
        : _hasAppPin ? 'Enter App PIN' : 'Set PIN';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: koraAppBar(context, title,
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
              : _step == 2 ? _buildConfirmStep()
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
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: AnimatedTap(
            onTap: () => setState(() => _mnemonicRevealed = !_mnemonicRevealed),
            pressScale: 0.99,
            child: Stack(children: [
              // The word grid: cells separated by one-pixel gaps of the border colour — the
              // same construction as the numpad, because it is the same language.
              Container(
                decoration: BoxDecoration(color: AppColors.border, border: kHairline()),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, childAspectRatio: 2.9,
                    crossAxisSpacing: 1, mainAxisSpacing: 1,
                  ),
                  itemCount: 12,
                  itemBuilder: (_, i) => Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: Row(children: [
                      Text((i + 1).toString().padLeft(2, '0'),
                          style: kMonoText(AppColors.textTertiary, size: 8.5)),
                      const SizedBox(width: 7),
                      Expanded(child: Text(
                        _mnemonicRevealed ? _words[i] : '····',
                        overflow: TextOverflow.ellipsis,
                        style: kMonoText(
                            _mnemonicRevealed
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                            size: 10.5, weight: FontWeight.w500),
                      )),
                    ]),
                  ),
                ),
              ),
              if (!_mnemonicRevealed)
                Positioned.fill(
                  child: Container(
                    color: AppColors.background.withValues(alpha: 0.82),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_outlined,
                            color: AppColors.textPrimary, size: 22),
                        const SizedBox(height: 10),
                        Text('TAP TO REVEAL',
                            style: kLabel(AppColors.textPrimary, size: 10, tracking: 0.16)),
                      ],
                    ),
                  ),
                ),
            ]),
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
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
          child: KoraCta(label: "I've saved my phrase", onTap: _next),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
          child: Text(
            'Confirm that you have saved your recovery phrase securely.',
            style: kBody(AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: AnimatedTap(
            onTap: () => setState(() => _confirmed = !_confirmed),
            pressScale: 0.98,
            child: AnimatedContainer(
              duration: kControl,
              curve: kEase,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _confirmed ? AppColors.borderHi : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(children: [
                // A square checkbox — filled ink when set, hairline when not.
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
                    'I have securely saved my 12-word recovery phrase.',
                    style: kBody(AppColors.textPrimary, size: 13),
                  ),
                ),
              ]),
            ),
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

  Widget _buildPinStep() {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
          child: Text(
            _hasAppPin
                ? 'Enter your 6-digit app PIN to add this wallet.'
                : 'Choose a 6-digit PIN to protect your wallet. Never share it with anyone.',
            style: kBody(AppColors.textSecondary),
          ),
        ),
        KoraSlabel(_hasAppPin ? 'App PIN' : 'PIN'),
        KoraField(
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _pinCtrl,
                obscureText: _pinObscure,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: kNum(AppColors.textPrimary, size: 18).copyWith(letterSpacing: 8),
                decoration: koraInputDecoration(_hasAppPin ? 'APP PIN' : 'PIN')
                    .copyWith(counterText: ''),
                onChanged: (_) => setState(() => _pinError = null),
              ),
            ),
            AnimatedTap(
              onTap: () => setState(() => _pinObscure = !_pinObscure),
              child: Icon(
                _pinObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textTertiary, size: 17),
            ),
          ]),
        ),
        if (!_hasAppPin) ...[
          const KoraSlabel('Confirm PIN'),
          KoraField(
            child: TextField(
              controller: _pinConfCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: kNum(AppColors.textPrimary, size: 18).copyWith(letterSpacing: 8),
              decoration: koraInputDecoration('CONFIRM PIN').copyWith(counterText: ''),
              onChanged: (_) => setState(() => _pinError = null),
            ),
          ),
        ],
        if (_pinError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
            child: Text(_pinError!.toUpperCase(),
                style: kLabel(AppColors.negative, size: 9.5, tracking: 0.1)),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
          child: KoraCta(label: 'Create Wallet', onTap: _createWallet, busy: _loading),
        ),
      ],
    );
  }
}
