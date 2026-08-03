import 'package:flutter/material.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
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
  bool    _pinObscure = true;
  bool    _hasAppPin  = false;
  String? _error;
  String? _pinError;

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
    setState(() { _step = 1; _error = null; _pinCtrl.clear(); _pinConfCtrl.clear(); _pinError = null; });
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(_step == 0 ? 'Import Wallet' : _hasAppPin ? 'Enter App PIN' : 'Set PIN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _step == 0
              ? () => Navigator.of(context).pop()
              : () => setState(() { _step = 0; _pinError = null; }),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _step == 0 ? _buildPhraseStep() : _buildPinStep(),
        ),
      ),
    );
  }

  Widget _buildPhraseStep() {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          'Enter your 12 or 24-word recovery phrase to restore your wallet.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameCtrl,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: _inputDecor('Wallet name'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _phraseCtrl,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.6),
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          onChanged: (_) => setState(() => _error = null),
          decoration: _inputDecor('Enter recovery phrase (12 or 24 words)').copyWith(
            alignLabelWithHint: true,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: AppColors.negative, fontSize: 13)),
        ],
        const Spacer(),
        FilledButton(
          onPressed: _nextStep,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.background,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Next', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ]),
    );
  }

  Widget _buildPinStep() {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          _hasAppPin
              ? 'Enter your 6-digit app PIN to add this wallet.'
              : 'Choose a 6-digit PIN to protect your wallet. Never share it with anyone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _pinCtrl,
          obscureText: _pinObscure,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: TextStyle(color: AppColors.textPrimary, letterSpacing: 8, fontSize: 22),
          decoration: _inputDecor(_hasAppPin ? 'App PIN' : 'PIN').copyWith(
            counterText: '',
            suffixIcon: IconButton(
              icon: Icon(_pinObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textTertiary),
              onPressed: () => setState(() => _pinObscure = !_pinObscure),
            ),
          ),
          onChanged: (_) => setState(() => _pinError = null),
        ),
        if (!_hasAppPin) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _pinConfCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: TextStyle(color: AppColors.textPrimary, letterSpacing: 8, fontSize: 22),
            decoration: _inputDecor('Confirm PIN').copyWith(counterText: ''),
            onChanged: (_) => setState(() => _pinError = null),
          ),
        ],
        if (_pinError != null) ...[
          const SizedBox(height: 10),
          Text(_pinError!, style: TextStyle(color: AppColors.negative, fontSize: 13)),
        ],
        const Spacer(),
        FilledButton(
          onPressed: _loading ? null : _import,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.background,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _loading
              ? SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: AppColors.background, strokeWidth: 2))
              : const Text('Import Wallet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ]),
    );
  }

  InputDecoration _inputDecor(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textTertiary),
    filled: true,
    fillColor: AppColors.card,
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.textSecondary, width: 1.5)),
  );
}
