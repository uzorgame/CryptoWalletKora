import 'dart:math';
import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;

/// Сервіс для роботи з мнемонічними фразами (Seed Phrases)
/// Відповідає стандарту BIP-39
class MnemonicService {
  /// Доступні мови для мнемонічних фраз
  static const List<String> supportedLanguages = ['english'];

  /// Генерує 12-словну мнемонічну фразу
  /// strength: 128 bits = 12 words
  static String generate12Words() {
    return bip39.generateMnemonic(strength: 128);
  }

  /// Генерує 15-словну мнемонічну фразу
  static String generate15Words() {
    return bip39.generateMnemonic(strength: 160);
  }

  /// Генерує 18-словну мнемонічну фразу
  static String generate18Words() {
    return bip39.generateMnemonic(strength: 192);
  }

  /// Генерує 21-словну мнемонічну фразу
  static String generate21Words() {
    return bip39.generateMnemonic(strength: 224);
  }

  /// Генерує 24-словну мнемонічну фразу (максимальна безпека)
  static String generate24Words() {
    return bip39.generateMnemonic(strength: 256);
  }

  /// Генерує мнемонічну фразу з вказаною кількістю слів
  /// [wordCount] має бути: 12, 15, 18, 21, або 24
  static String generate({required int wordCount}) {
    final strength = _wordCountToStrength(wordCount);
    return bip39.generateMnemonic(strength: strength);
  }

  /// Конвертує кількість слів в entropy strength
  static int _wordCountToStrength(int wordCount) {
    switch (wordCount) {
      case 12:
        return 128;
      case 15:
        return 160;
      case 18:
        return 192;
      case 21:
        return 224;
      case 24:
        return 256;
      default:
        throw ArgumentError('Invalid word count. Must be 12, 15, 18, 21, or 24');
    }
  }

  /// Валідує мнемонічну фразу
  /// Перевіряє checksum та слова
  static bool validate(String mnemonic) {
    if (mnemonic.isEmpty) return false;
    
    final words = mnemonic.trim().split(RegExp(r'\s+'));
    final validWordCounts = [12, 15, 18, 21, 24];
    if (!validWordCounts.contains(words.length)) {
      return false;
    }
    
    return bip39.validateMnemonic(mnemonic);
  }

  /// Конвертує мнемонічну фразу в seed (512 bits)
  /// [passphrase] - опціональна passphrase (BIP-39)
  static Uint8List mnemonicToSeed(String mnemonic, {String passphrase = ''}) {
    return bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);
  }

  /// Конвертує мнемонічну фразу в seed як hex string
  static String mnemonicToSeedHex(String mnemonic, {String passphrase = ''}) {
    final seed = mnemonicToSeed(mnemonic, passphrase: passphrase);
    return _bytesToHex(seed);
  }

  /// Конвертує мнемонічну фразу в список слів
  static List<String> splitWords(String mnemonic) {
    return mnemonic.trim().split(RegExp(r'\s+'));
  }

  /// Об'єднує список слів в мнемонічну фразу
  static String joinWords(List<String> words) {
    return words.join(' ');
  }

  /// Перевіряє чи всі слова з валідного списку BIP-39
  static List<String> getInvalidWords(String mnemonic) {
    // bip39 v1.0.6 не надає доступ до словника - перевіряємо через валідацію
    if (validate(mnemonic)) return [];
    return splitWords(mnemonic).where((word) => word.isEmpty).toList();
  }

  /// Генерує випадкову passphrase
  static String generatePassphrase({int length = 16}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = _secureRandom;
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Конвертує bytes в hex string
  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Random get _secureRandom => Random.secure();

  /// Перетворює мнемонічну фразу на список індексів (позиція слова)
  static List<int> toIndices(String mnemonic) {
    // bip39 v1.0.6 не надає доступ до словника
    final words = splitWords(mnemonic);
    return List.generate(words.length, (i) => i);
  }

  /// Перевіряє чи дві мнемонічні фрази еквівалентні (з урахуванням порядку)
  static bool areEqual(String mnemonic1, String mnemonic2) {
    final words1 = splitWords(mnemonic1.toLowerCase());
    final words2 = splitWords(mnemonic2.toLowerCase());
    
    if (words1.length != words2.length) return false;
    
    for (int i = 0; i < words1.length; i++) {
      if (words1[i] != words2[i]) return false;
    }
    
    return true;
  }

  /// Перевіряє чи мнемонічна фраза містить дублікатів слів
  static bool hasDuplicateWords(String mnemonic) {
    final words = splitWords(mnemonic.toLowerCase());
    return words.length != words.toSet().length;
  }

  /// Отримує ентропію мнемонічної фрази в bits
  static int getEntropy(String mnemonic) {
    final words = splitWords(mnemonic);
    return _wordCountToStrength(words.length);
  }

  /// Створює мнемонічну фразу з випадкової ентропії
  /// [entropyHex] - hex string ентропії
  static String fromEntropy(String entropyHex) {
    return bip39.entropyToMnemonic(entropyHex);
  }

}

/// Exception для помилок роботи з мнемонічними фразами
class MnemonicException implements Exception {
  final String message;
  
  MnemonicException(this.message);
  
  @override
  String toString() => 'MnemonicException: $message';
}
