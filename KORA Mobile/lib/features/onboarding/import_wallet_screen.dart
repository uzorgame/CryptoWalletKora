import 'package:flutter/material.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';
import 'package:kora/core/widgets/kora_button.dart';
import 'package:kora/core/widgets/kora_field.dart';
import 'package:kora/core/widgets/input/numpad.dart';
import 'package:kora/features/home/home_screen.dart';

class ImportWalletScreen extends ConsumerStatefulWidget {
  const ImportWalletScreen({super.key});
  @override
  ConsumerState<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends ConsumerState<ImportWalletScreen> with ThemeAwareMixin {
  final _nameCtrl    = TextEditingController(text: 'My Wallet');
  final _phraseCtrl  = TextEditingController();
  final _pinCtrl     = TextEditingController();
  final _pinConfCtrl = TextEditingController();
  int     _step       = 0; // 0=phrase, 1=pin
  bool    _loading    = false;
  bool    _hasAppPin  = false;
  String? _error;
  String? _pinError;

  // The PIN comes in through the square keypad, dot by dot — the same entry the create
  // flow and the lock screen use.
  String _pinEntry   = '';
  bool   _confirming = false;

  @override
  void initState() {
    super.initState();
    KeyManager.hasAppPin().then((v) => setState(() => _hasAppPin = v));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phraseCtrl.dispose();
    _pinCtrl.dispose();
    _pinConfCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    final mnemonic = _phraseCtrl.text.trim().toLowerCase();
    if (!bip39.validateMnemonic(mnemonic)) {
      setState(() => _error = 'Invalid recovery phrase. Check for typos.');
      return;
    }
    setState(() {
      _step = 1;
      _error = null;
      _pinCtrl.clear();
      _pinConfCtrl.clear();
      _pinError = null;
      _pinEntry = '';
      _confirming = false;
    });
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
      await _import();
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
    await _import();
    if (mounted && _pinError != null) {
      setState(() {
        _pinEntry = '';
        _confirming = false;
        _pinCtrl.clear();
        _pinConfCtrl.clear();
      });
    }
  }

  Future<void> _import() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length != 6 || int.tryParse(pin) == null) {
      setState(() => _pinError = 'PIN must be exactly 6 digits');
      return;
    }
    if (_hasAppPin) {
      final valid = await KeyManager.verifyAppPin(pin);
      if (!valid) {
        setState(() => _pinError = 'Incorrect PIN');
        return;
      }
    } else {
      if (pin != _pinConfCtrl.text.trim()) {
        setState(() => _pinError = 'PINs do not match');
        return;
      }
    }
    setState(() { _loading = true; _pinError = null; });
    try {
      final mnemonic = _phraseCtrl.text.trim().toLowerCase();
      await ref.read(currentWalletProvider.notifier).importWallet(
        name: _nameCtrl.text.trim().isEmpty ? 'My Wallet' : _nameCtrl.text.trim(),
        mnemonic: mnemonic,
        pin: pin,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (r) => false,
      );
    } catch (e) {
      if (mounted) setState(() { _loading = false; _pinError = 'Failed to import: $e'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: koraAppBar(
        context,
        _step == 0 ? 'Import Wallet' : _hasAppPin ? 'Enter App PIN' : 'Set PIN',
        backLabel: 'Back',
          onBack: _step == 0
            ? () => Navigator.of(context).pop()
            : () => setState(() { _step = 0; _pinError = null; }),
      ),
      body: SafeArea(
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
          child: _step == 0 ? _buildPhraseStep() : _buildPinStep(),
        ),
      ),
    );
  }

  Widget _buildPhraseStep() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: Text(
            'Enter your 12 or 24-word recovery phrase to restore your wallet.',
            style: kBody(AppColors.textSecondary, size: 13).copyWith(height: 1.55),
          ),
        ),
        const KoraSlabel('Name'),
        KoraField(
          child: TextField(
            controller: _nameCtrl,
            style: koraInputStyle(),
            decoration: koraInputDecoration('WALLET NAME'),
          ),
        ),
        const KoraSlabel('Recovery phrase'),
        KoraField(
          child: TextField(
            controller: _phraseCtrl,
            style: koraInputStyle().copyWith(height: 1.7),
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() => _error = null),
            decoration: koraInputDecoration('ENTER RECOVERY PHRASE (12 OR 24 WORDS)'),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
            child: Text(_error!.toUpperCase(),
                style: kLabel(AppColors.negative, size: 9.5, tracking: 0.1)),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 34),
          child: KoraCta(label: 'Import', onTap: _nextStep),
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
      key: const ValueKey(1),
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

/// Six square dots that fill as the PIN is typed — the prototype's kdots.
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
