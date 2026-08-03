import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' hide SecureRandom;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, compute;
import 'package:pointycastle/export.dart';

// ── Top-level helpers required by compute() ──────────────────────────────────

class _EncryptArgs {
  final String plainText;
  final String password;
  const _EncryptArgs(this.plainText, this.password);
}

class _DecryptArgs {
  final String encryptedData;
  final String password;
  const _DecryptArgs(this.encryptedData, this.password);
}

String _encryptIsolate(_EncryptArgs args) =>
    EncryptionService.encrypt(args.plainText, args.password);

String _decryptIsolate(_DecryptArgs args) =>
    EncryptionService.decrypt(args.encryptedData, args.password);

/// Runs a single PBKDF2 + AES-GCM round with dummy data to pre-load
/// PointyCastle/BouncyCastle JVM classes before the user enters their PIN.
void _warmupCryptoIsolate(Object? _) {
  try {
    final salt        = Uint8List(32); // zeroes — just for warmup
    final password    = Uint8List.fromList(utf8.encode('warmup'));
    final params      = Pbkdf2Parameters(salt, 1, 32); // 1 iteration — fast
    final kdf         = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    kdf.init(params);
    final keyBytes    = kdf.process(password);
    // Also warm AES-GCM path
    final key         = Key(keyBytes);
    final iv          = IV(Uint8List(12));
    Encrypter(AES(key, mode: AESMode.gcm)).encrypt('w', iv: iv);
  } catch (_) { /* warmup failures are harmless */ }
}

/// Сервіс шифрування для безпечного зберігання sensitive даних
/// Використовує AES-256-GCM (AEAD) з PBKDF2 для key derivation.
/// GCM надає автентифікацію (auth tag) та шифрування в одному — на відміну від CBC.
class EncryptionService {
  static const int _keyLength   = 32; // AES-256
  static const int _ivLength    = 12; // GCM nonce: 96 bits (recommended)
  static const int _saltLength  = 32;
  static const int _iterations  = 10000; // PBKDF2 iterations (10k is NIST minimum, fast enough for mobile)
  static Future<void>? _warmupFuture;

  /// Генерує випадкову сіль
  static String _generateSalt() {
    final random = SecureRandom('Fortuna')
      ..seed(KeyParameter(Uint8List.fromList(
        List.generate(32, (_) => Random.secure().nextInt(256))
      )));
    final saltBytes = random.nextBytes(_saltLength);
    return base64Encode(saltBytes);
  }

  /// Генерує ключ з пароля використовуючи PBKDF2
  static Key _deriveKey(String password, String salt) {
    final saltBytes = base64Decode(salt);
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    
    final params = Pbkdf2Parameters(
      Uint8List.fromList(saltBytes),
      _iterations,
      _keyLength,
    );
    
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    kdf.init(params);
    
    final keyBytes = kdf.process(passwordBytes);
    return Key(keyBytes);
  }

  /// Шифрує текст за допомогою AES-256-GCM (AEAD).
  /// Формат результату: salt:nonce:ciphertext_with_tag (base64)
  /// Auth tag (16 байт) включений в ciphertext автоматично пакетом encrypt.
  static String encrypt(String plainText, String password) {
    try {
      final Stopwatch? sw = kDebugMode ? (Stopwatch()..start()) : null;
      final salt = _generateSalt();
      final key  = _deriveKey(password, salt);
      final int kdfMs = sw?.elapsedMilliseconds ?? 0;

      final iv   = IV.fromSecureRandom(_ivLength); // 12-byte GCM nonce
      final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      sw?.stop();

      if (kDebugMode) debugPrint('[PERF][Encrypt] PBKDF2=${kdfMs}ms  AES-GCM=${(sw!.elapsedMilliseconds - kdfMs)}ms  total=${sw.elapsedMilliseconds}ms  iterations=$_iterations');
      return '${salt}:${base64Encode(iv.bytes)}:${encrypted.base64}';
    } catch (e) {
      throw EncryptionException('Failed to encrypt data: $e');
    }
  }

  /// Дешифрує текст (AES-256-GCM).
  /// Очікує формат: salt:nonce:ciphertext_with_tag
  /// Якщо дані були зашифровані старим CBC форматом — кидає EncryptionException.
  static String decrypt(String encryptedData, String password) {
    try {
      final parts = encryptedData.split(':');
      if (parts.length != 3) {
        throw EncryptionException('Invalid encrypted data format');
      }

      final salt       = parts[0];
      final iv         = IV(base64Decode(parts[1]));
      final cipherText = parts[2];

      final Stopwatch? sw = kDebugMode ? (Stopwatch()..start()) : null;
      final key = _deriveKey(password, salt);
      final int kdfMs = sw?.elapsedMilliseconds ?? 0;

      final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
      final result = encrypter.decrypt64(cipherText, iv: iv);
      sw?.stop();

      if (kDebugMode) debugPrint('[PERF][Decrypt] PBKDF2=${kdfMs}ms  AES-GCM=${(sw!.elapsedMilliseconds - kdfMs)}ms  total=${sw.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      throw EncryptionException('Failed to decrypt data: $e');
    }
  }

  /// Async encrypt — runs PBKDF2 in a separate isolate to keep UI responsive.
  static Future<String> encryptAsync(String plainText, String password) =>
      compute(_encryptIsolate, _EncryptArgs(plainText, password));

  /// Async decrypt — runs PBKDF2 in a separate isolate to keep UI responsive.
  static Future<String> decryptAsync(String encryptedData, String password) =>
      compute(_decryptIsolate, _DecryptArgs(encryptedData, password));

  /// Pre-warms JVM PointyCastle/BouncyCastle classes so the first real
  /// PBKDF2 call is fast (~380ms) instead of cold (~1160ms).
  /// Call once from the splash screen; result is discarded.
  static Future<void> warmupCrypto() =>
      _warmupFuture ??= compute(_warmupCryptoIsolate, null);

  /// Шифрує бінарні дані
  static String encryptBytes(Uint8List data, String password) {
    return encrypt(base64Encode(data), password);
  }

  /// Дешифрує бінарні дані
  static Uint8List decryptBytes(String encryptedData, String password) {
    final decrypted = decrypt(encryptedData, password);
    return base64Decode(decrypted);
  }

  /// Генерує випадковий ключ для одноразового використання
  static String generateRandomKey() {
    final random = SecureRandom('Fortuna')
      ..seed(KeyParameter(Uint8List.fromList(
        List.generate(32, (_) => Random.secure().nextInt(256))
      )));
    final keyBytes = random.nextBytes(_keyLength);
    return base64Encode(keyBytes);
  }

  /// Хешує пароль для верифікації (SHA-256)
  static String hashPassword(String password, {String? salt}) {
    final effectiveSalt = salt ?? _generateSalt();
    final passwordBytes = utf8.encode(password);
    final saltBytes = base64Decode(effectiveSalt);
    
    final hmac = HMac(SHA256Digest(), 64);
    hmac.init(KeyParameter(Uint8List.fromList(saltBytes)));
    
    final hash = hmac.process(Uint8List.fromList(passwordBytes));
    return '${effectiveSalt}:${base64Encode(hash)}';
  }

  /// Верифікує пароль з хешем
  static bool verifyPassword(String password, String hashedPassword) {
    try {
      final parts = hashedPassword.split(':');
      if (parts.length != 2) return false;
      
      final salt = parts[0];
      final hash = parts[1];
      
      final newHash = hashPassword(password, salt: salt);
      final newParts = newHash.split(':');
      
      return hash == newParts[1];
    } catch (e) {
      return false;
    }
  }
}

/// Exception для помилок шифрування
class EncryptionException implements Exception {
  final String message;
  
  EncryptionException(this.message);
  
  @override
  String toString() => 'EncryptionException: $message';
}
