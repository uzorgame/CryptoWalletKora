import 'package:flutter/material.dart';
import 'package:kora/core/widgets/animated_tap.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(_step == 0 ? 'Create Wallet'
            : _step == 1 ? 'Recovery Phrase'
            : _step == 2 ? 'Confirm Backup'
            : _hasAppPin ? 'Enter App PIN' : 'Set PIN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _step == 0
              ? () => Navigator.of(context).pop()
              : () => setState(() => _step--),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _step == 0 ? _buildNameStep()
              : _step == 1 ? _buildPhraseStep()
              : _step == 2 ? _buildConfirmStep()
              : _buildPinStep(),
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        Text('Give your wallet a name',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 24),
        TextField(
          controller: _nameCtrl,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Wallet name',
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.textSecondary, width: 1.5)),
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _next,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.background,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ]),
    );
  }

  Widget _buildPhraseStep() {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          'Write down these 12 words in order and store them somewhere safe. Never share them with anyone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 24),
        AnimatedTap(
          onTap: () => setState(() => _mnemonicRevealed = !_mnemonicRevealed),
          pressScale: 0.98,
          child: Stack(children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, childAspectRatio: 2.6,
                crossAxisSpacing: 8, mainAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (_, i) => Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(children: [
                  const SizedBox(width: 8),
                  Text('${i+1}', style: TextStyle(
                      color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    _mnemonicRevealed ? _words[i] : '••••',
                    style: TextStyle(
                      color: _mnemonicRevealed ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 13, fontWeight: FontWeight.w500),
                  )),
                ]),
              ),
            ),
            if (!_mnemonicRevealed)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.visibility_outlined, color: AppColors.textPrimary, size: 28),
                      const SizedBox(height: 8),
                      Text('Tap to reveal', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        if (_mnemonicRevealed)
          AnimatedTap(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _mnemonic));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')));
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copy_rounded, color: AppColors.textSecondary, size: 16),
                const SizedBox(width: 6),
                Text('Copy to clipboard',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        const Spacer(),
        FilledButton(
          onPressed: _next,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.background,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text("I've saved my phrase", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ]),
    );
  }

  Widget _buildConfirmStep() {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          'Confirm that you have saved your recovery phrase securely.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 24),
        AnimatedTap(
          onTap: () => setState(() => _confirmed = !_confirmed),
          pressScale: 0.97,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _confirmed ? AppColors.textPrimary : AppColors.border,
                width: _confirmed ? 1.5 : 0.5,
              ),
            ),
            child: Row(children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: _confirmed ? AppColors.textPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _confirmed ? AppColors.textPrimary : AppColors.textTertiary),
                ),
                child: _confirmed
                    ? Icon(Icons.check_rounded, color: AppColors.background, size: 14)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'I have securely saved my 12-word recovery phrase.',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
                ),
              ),
            ]),
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _next,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.background,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ]),
    );
  }

  Widget _buildPinStep() {
    final inputDecor = InputDecoration(
      filled: true,
      fillColor: AppColors.card,
      border:        OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.textSecondary, width: 1.5)),
    );
    return Padding(
      key: const ValueKey(3),
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
          decoration: inputDecor.copyWith(
            hintText: _hasAppPin ? 'App PIN' : 'PIN',
            hintStyle: TextStyle(color: AppColors.textTertiary, letterSpacing: 1, fontSize: 15),
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
            decoration: inputDecor.copyWith(
              hintText: 'Confirm PIN',
              hintStyle: TextStyle(color: AppColors.textTertiary, letterSpacing: 1, fontSize: 15),
              counterText: '',
            ),
            onChanged: (_) => setState(() => _pinError = null),
          ),
        ],
        if (_pinError != null) ...[  
          const SizedBox(height: 10),
          Text(_pinError!, style: TextStyle(color: AppColors.negative, fontSize: 13)),
        ],
        const Spacer(),
        FilledButton(
          onPressed: _loading ? null : _createWallet,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.background,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _loading
              ? SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: AppColors.background, strokeWidth: 2))
              : const Text('Create Wallet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ]),
    );
  }
}
