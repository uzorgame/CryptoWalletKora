import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/crypto/mnemonic.dart';

/// Which way the user is setting a wallet up.
enum OnboardingMode { create, restore }

/// Where the flow is.
enum OnboardingStep { choose, name, phrase, verify, restore, passphrase, done }

/// The state of setting up a wallet, and the rules about moving through it.
///
/// Kept apart from the widgets so the rules — what makes a name acceptable, which words are
/// checked, when a passphrase step is needed at all — can be read and changed without
/// scrolling past layout.
class OnboardingController extends ChangeNotifier {
  OnboardingController({required this.firstRun, required this.existingNames})
      : _name = firstRun ? 'Main' : 'Wallet ${existingNames.length + 1}';

  /// True when the app has no wallets yet. Only then does the flow set an app passphrase;
  /// afterwards there is one already, and asking again would be asking for a second.
  final bool firstRun;

  final List<String> existingNames;

  OnboardingStep _step = OnboardingStep.choose;
  OnboardingMode? _mode;
  String _name;
  String _mnemonic = '';
  List<int> _checkIndices = const [];
  String _error = '';

  OnboardingStep get step => _step;
  OnboardingMode? get mode => _mode;
  String get name => _name;
  String get mnemonic => _mnemonic;
  List<String> get words => _mnemonic.isEmpty ? const [] : MnemonicService.splitWords(_mnemonic);
  List<int> get checkIndices => _checkIndices;
  String get error => _error;

  int get stepCount => firstRun ? 5 : 4;

  int get stepIndex => switch (_step) {
        OnboardingStep.choose => 0,
        OnboardingStep.name => 1,
        OnboardingStep.phrase || OnboardingStep.restore => 2,
        OnboardingStep.verify => 3,
        OnboardingStep.passphrase => 4,
        OnboardingStep.done => stepCount - 1,
      };

  void _set(OnboardingStep step) {
    _step = step;
    _error = '';
    notifyListeners();
  }

  void fail(String message) {
    _error = message;
    notifyListeners();
  }

  void choose(OnboardingMode mode) {
    _mode = mode;
    _set(OnboardingStep.name);
  }

  /// A name has to be present and its own. Two wallets called the same thing are two wallets
  /// nobody can tell apart in a switcher.
  bool submitName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      fail('Give the wallet a name.');
      return false;
    }
    if (existingNames.any((n) => n.toLowerCase() == trimmed.toLowerCase())) {
      fail('A wallet with that name already exists.');
      return false;
    }
    _name = trimmed;

    if (_mode == OnboardingMode.create) {
      // The real generator, with its checksum. A phrase that cannot be restored in another
      // wallet is not a recovery phrase.
      _mnemonic = MnemonicService.generate12Words();
      _checkIndices = _pickChecks(MnemonicService.splitWords(_mnemonic).length);
      _set(OnboardingStep.phrase);
    } else {
      _set(OnboardingStep.restore);
    }
    return true;
  }

  void phraseWritten() => _set(OnboardingStep.verify);

  /// Three positions typed back — the only check that the phrase actually left the screen.
  bool submitVerification(List<String> answers) {
    final expected = words;
    for (final (i, index) in _checkIndices.indexed) {
      if (answers[i].trim().toLowerCase() != expected[index]) {
        fail('Those do not match the phrase. Check your notes.');
        return false;
      }
    }
    _set(firstRun ? OnboardingStep.passphrase : OnboardingStep.done);
    return true;
  }

  bool submitRestoredPhrase(List<String> entered) {
    final cleaned = entered.map((w) => w.trim().toLowerCase()).toList();
    if (cleaned.any((w) => w.isEmpty)) {
      fail('All twelve words are needed.');
      return false;
    }
    final phrase = MnemonicService.joinWords(cleaned);
    // Validated against BIP-39 rather than merely counted: a phrase with a wrong word or a
    // broken checksum restores a different wallet, silently and permanently.
    if (!MnemonicService.validate(phrase)) {
      final invalid = MnemonicService.getInvalidWords(phrase);
      fail(invalid.isEmpty
          ? 'That phrase is not valid. Check the order of the words.'
          : 'Not in the word list: ${invalid.join(', ')}');
      return false;
    }
    _mnemonic = phrase;
    _set(firstRun ? OnboardingStep.passphrase : OnboardingStep.done);
    return true;
  }

  bool submitPassphrase(String value, String repeat) {
    if (value.length < 6) {
      fail('Use at least six characters.');
      return false;
    }
    if (value != repeat) {
      fail('The two entries do not match.');
      return false;
    }
    _set(OnboardingStep.done);
    return true;
  }

  void back() {
    _set(switch (_step) {
      OnboardingStep.name => OnboardingStep.choose,
      OnboardingStep.phrase || OnboardingStep.restore => OnboardingStep.name,
      OnboardingStep.verify => OnboardingStep.phrase,
      OnboardingStep.passphrase =>
        _mode == OnboardingMode.create ? OnboardingStep.verify : OnboardingStep.restore,
      _ => OnboardingStep.choose,
    });
  }

  /// Positions are drawn without replacement and shown in order, so the check reads as three
  /// spot questions rather than a puzzle.
  static List<int> _pickChecks(int wordCount) {
    final random = Random.secure();
    final picked = <int>{};
    while (picked.length < 3) {
      picked.add(random.nextInt(wordCount));
    }
    return picked.toList()..sort();
  }
}
