import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/numpad.dart';

/// Changing the PIN, in the wallet's own language.
///
/// It used to be three Material text fields with floating labels in the system font — the
/// only place in the app that still looked like a form. It is now what every other PIN in
/// this application is: six squares filling under the wallet's own keypad, one stage at a
/// time. Nothing about the key rotation itself changed; [KeyManager.changePin] does the same
/// work it always did, over the same wallet ids.
Future<bool> showChangePinSheet(BuildContext context, WidgetRef ref) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChangePinSheet(ref: ref),
  );
  return ok ?? false;
}

enum _Stage { current, fresh, confirm }

class _ChangePinSheet extends StatefulWidget {
  const _ChangePinSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends State<_ChangePinSheet> {
  _Stage _stage = _Stage.current;
  String _entry = '';
  String _oldPin = '';
  String _newPin = '';
  bool _busy = false;
  String? _error;

  String get _title => switch (_stage) {
        _Stage.current => 'Current PIN',
        _Stage.fresh => 'New PIN',
        _Stage.confirm => 'Confirm new PIN',
      };

  String get _explanation => switch (_stage) {
        _Stage.current => 'Enter the PIN you use today.',
        _Stage.fresh => 'Choose six new digits.',
        _Stage.confirm => 'Enter the new PIN once more.',
      };

  void _onDigit(String d) {
    if (_busy || _entry.length >= 6) return;
    setState(() {
      _entry += d;
      _error = null;
    });
    if (_entry.length == 6) {
      Future.delayed(const Duration(milliseconds: 200), _advance);
    }
  }

  void _onBackspace() {
    if (_busy || _entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  void _fail(String message) {
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = false;
      _entry = '';
      _error = message;
    });
  }

  Future<void> _advance() async {
    if (!mounted || _entry.length != 6) return;

    switch (_stage) {
      case _Stage.current:
        setState(() => _busy = true);
        final valid = await KeyManager.verifyAppPin(_entry);
        if (!mounted) return;
        if (!valid) {
          _fail('Incorrect PIN.');
          return;
        }
        setState(() {
          _oldPin = _entry;
          _entry = '';
          _busy = false;
          _stage = _Stage.fresh;
        });

      case _Stage.fresh:
        if (_entry == _oldPin) {
          _fail('The new PIN must differ.');
          return;
        }
        setState(() {
          _newPin = _entry;
          _entry = '';
          _stage = _Stage.confirm;
        });

      case _Stage.confirm:
        if (_entry != _newPin) {
          setState(() {
            _entry = '';
            _newPin = '';
            _stage = _Stage.fresh;
            _error = 'They did not match. Start again.';
          });
          return;
        }
        setState(() => _busy = true);
        // Every wallet's seed is re-encrypted under the new PIN, so all ids go in.
        final wallets = await widget.ref.read(allWalletsProvider.future);
        final changed = await KeyManager.changePin(
          _oldPin,
          _newPin,
          walletIds: wallets.map((w) => w.id).toList(),
        );
        if (!mounted) return;
        if (!changed) {
          _fail('Could not change the PIN.');
          return;
        }
        HapticFeedback.lightImpact();
        Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderHi, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          Container(width: 24, height: 2, color: AppColors.textTertiary),
          const SizedBox(height: 18),
          Text(_title.toUpperCase(),
              style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.18)),
          const SizedBox(height: 8),
          Text(_explanation.toUpperCase(),
              style: kLabel(AppColors.textTertiary, size: 9, tracking: 0.12,
                  weight: FontWeight.w400)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              final filled = i < _entry.length;
              return AnimatedContainer(
                duration: kControl,
                curve: kEase,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: filled ? AppColors.textPrimary : Colors.transparent,
                  border: Border.all(
                    color: filled ? AppColors.textPrimary : AppColors.borderHi,
                    width: 1,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 14,
            child: _error == null
                ? null
                : Text(_error!.toUpperCase(),
                    style: kLabel(AppColors.negative, size: 9, tracking: 0.08)),
          ),
          const SizedBox(height: 10),
          Numpad(onDigit: _onDigit, onBackspace: _onBackspace, loading: _busy),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(false),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('CANCEL',
                  style: kLabel(AppColors.textSecondary, size: 9.5, tracking: 0.16)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
