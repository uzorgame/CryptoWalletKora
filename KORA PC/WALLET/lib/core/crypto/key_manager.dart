import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kora_windows/core/crypto/encryption.dart';

/// Менеджер ключів для безпечного зберігання приватних даних
/// Використовує FlutterSecureStorage + AES-256 шифрування
class KeyManager {
  /// Екземпляр secure storage з оптимальними налаштуваннями
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accountName: 'kora_wallet_keys',
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Ключі для зберігання в Secure Storage
  static const String _seedPhraseKey   = 'seed_phrase_encrypted'; // legacy single-wallet key
  static const String _privateKeysKey  = 'private_keys_encrypted';
  static const String _walletAddressesKey = 'wallet_addresses';
  static const String _backupStatusKey = 'backup_status';
  static const String _lastBackupDateKey = 'last_backup_date';
  static const String _appPinVerifyKey = 'app_pin_verify';
  static const String _pinVerifyPlaintext = 'KORA_WALLET_PIN_VALID';

  static String _seedKeyForWallet(String walletId) => 'seed_phrase_$walletId';

  // ─── Biometric-protected PIN key ─────────────────────────────────────────
  static const String _biometricPinKey = 'biometric_protected_pin';

  // ─── Session cache for private keys (cleared on app lock) ───────────────
  static Map<String, dynamic>? _pkSessionCache;
  static String?               _pkSessionPin;

  /// Clears the in-memory private-key cache (call on app lock / PIN change).
  static void clearPrivateKeyCache() {
    _pkSessionCache = null;
    _pkSessionPin   = null;
  }

  // ==================== APP PIN ====================

  // ==================== BIOMETRIC PIN ====================

  /// Stores the app PIN under a dedicated secure-storage key.
  /// Called when the user enables biometric auth so that subsequent
  /// biometric authentication can retrieve the PIN without prompting.
  static Future<void> storePinForBiometric(String pin) async {
    await _secureStorage.write(key: _biometricPinKey, value: pin);
    _log('Biometric PIN stored');
  }

  /// Returns the app PIN that was stored when biometric was enabled,
  /// or null if biometric was not set up.
  static Future<String?> getPinForBiometric() async {
    return _secureStorage.read(key: _biometricPinKey);
  }

  /// Removes the biometric-stored PIN (called when biometric is disabled
  /// or when the PIN is changed).
  static Future<void> deletePinForBiometric() async {
    await _secureStorage.delete(key: _biometricPinKey);
    _log('Biometric PIN deleted');
  }

  /// Зберігає верифікаційний токен для app-рівневого PIN
  static Future<void> storeAppPin(String pin) async {
    final Stopwatch? sw = kDebugMode ? (Stopwatch()..start()) : null;
    final encrypted = await EncryptionService.encryptAsync(_pinVerifyPlaintext, pin);
    final int encMs = sw?.elapsedMilliseconds ?? 0;
    await _secureStorage.write(key: _appPinVerifyKey, value: encrypted);
    sw?.stop();
    if (kDebugMode) debugPrint('[PERF][KeyMgr] storeAppPin: encrypt=${encMs}ms  secureWrite=${(sw!.elapsedMilliseconds - encMs)}ms  total=${sw.elapsedMilliseconds}ms');
    _log('App PIN stored');
  }

  /// Перевіряє чи встановлено app PIN
  static Future<bool> hasAppPin() async {
    final v = await _secureStorage.read(key: _appPinVerifyKey);
    return v != null && v.isNotEmpty;
  }

  /// Верифікує app PIN
  static Future<bool> verifyAppPin(String pin) async {
    final Stopwatch? sw = kDebugMode ? (Stopwatch()..start()) : null;
    final encrypted = await _secureStorage.read(key: _appPinVerifyKey);
    final int readMs = sw?.elapsedMilliseconds ?? 0;
    if (encrypted == null || encrypted.isEmpty) return false;
    try {
      final decrypted = await EncryptionService.decryptAsync(encrypted, pin);
      sw?.stop();
      if (kDebugMode) debugPrint('[PERF][KeyMgr] verifyAppPin: secureRead=${readMs}ms  decrypt=${(sw!.elapsedMilliseconds - readMs)}ms  total=${sw.elapsedMilliseconds}ms');
      return decrypted == _pinVerifyPlaintext;
    } on EncryptionException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ==================== SEED PHRASE ====================

  /// Зберігає seed phrase в зашифрованому вигляді (прив'язаний до гаманця)
  static Future<void> storeSeedPhrase(String mnemonic, String pin,
      {required String walletId}) async {
    try {
      final Stopwatch? sw = kDebugMode ? (Stopwatch()..start()) : null;
      final encrypted = await EncryptionService.encryptAsync(mnemonic, pin);
      final int encMs = sw?.elapsedMilliseconds ?? 0;
      await _secureStorage.write(key: _seedKeyForWallet(walletId), value: encrypted);
      sw?.stop();
      if (kDebugMode) debugPrint('[PERF][KeyMgr] storeSeedPhrase(${mnemonic.split(' ').length}w): encrypt=${encMs}ms  secureWrite=${(sw!.elapsedMilliseconds - encMs)}ms  total=${sw.elapsedMilliseconds}ms');
      _log('Seed phrase stored for wallet $walletId (${mnemonic.split(' ').length} words)');
    } catch (e) {
      _logError('Failed to store seed phrase', e);
      throw KeyManagerException('Failed to store seed phrase: $e');
    }
  }

  /// Отримує seed phrase (розшифровує використовуючи PIN)
  static Future<String?> getSeedPhrase(String pin, {required String walletId}) async {
    try {
      // Спочатку пробуємо wallet-specific ключ
      var encrypted = await _secureStorage.read(key: _seedKeyForWallet(walletId));
      // Fallback до legacy ключа для старих гаманців
      if (encrypted == null || encrypted.isEmpty) {
        encrypted = await _secureStorage.read(key: _seedPhraseKey);
      }
      if (encrypted == null || encrypted.isEmpty) return null;
      return await EncryptionService.decryptAsync(encrypted, pin);
    } on EncryptionException {
      return null;
    } catch (e) {
      _logError('Failed to get seed phrase', e);
      return null;
    }
  }

  /// Перевіряє чи існує seed phrase для гаманця
  static Future<bool> hasSeedPhrase({String? walletId}) async {
    if (walletId != null) {
      final v = await _secureStorage.read(key: _seedKeyForWallet(walletId));
      if (v != null && v.isNotEmpty) return true;
    }
    final legacy = await _secureStorage.read(key: _seedPhraseKey);
    return legacy != null && legacy.isNotEmpty;
  }

  /// Видаляє seed phrase для конкретного гаманця
  static Future<void> deleteSeedPhrase({String? walletId}) async {
    if (walletId != null) {
      await _secureStorage.delete(key: _seedKeyForWallet(walletId));
    }
    _log('Seed phrase deleted${walletId != null ? ' for wallet $walletId' : ''}');
  }

  // ==================== PRIVATE KEYS ====================

  /// Зберігає приватний ключ для конкретного блокчейну
  /// [blockchain] - 'bitcoin', 'ethereum', 'solana', etc.
  /// [address] - публічна адреса (identifier)
  /// [privateKey] - приватний ключ в hex форматі
  /// [pin] - PIN код для шифрування
  static Future<void> storePrivateKey({
    required String blockchain,
    required String address,
    required String privateKey,
    required String pin,
  }) async {
    try {
      // Отримуємо існуючі ключі
      final existingKeys = await _getAllPrivateKeys(pin);
      
      // Додаємо новий ключ
      final keyData = {
        'blockchain': blockchain,
        'address': address,
        'privateKey': privateKey,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      // Ключ для цього блокчейну
      final blockchainKey = '${blockchain}_${address}';
      existingKeys[blockchainKey] = keyData;
      
      // Зберігаємо оновлену мапу
      await _saveAllPrivateKeys(existingKeys, pin);
      
      _log('Private key stored for $blockchain: $address');
    } catch (e) {
      _logError('Failed to store private key', e);
      throw KeyManagerException('Failed to store private key: $e');
    }
  }

  /// Отримує приватний ключ
  static Future<String?> getPrivateKey({
    required String blockchain,
    required String address,
    required String pin,
  }) async {
    try {
      final allKeys = await _getAllPrivateKeys(pin);
      final blockchainKey = '${blockchain}_${address}';
      
      final keyData = allKeys[blockchainKey];
      if (keyData == null) return null;
      
      return keyData['privateKey'] as String?;
    } catch (e) {
      _logError('Failed to get private key', e);
      return null;
    }
  }

  /// Отримує всі приватні ключі (з session-кешем для уникнення повторного PBKDF2)
  static Future<Map<String, dynamic>> _getAllPrivateKeys(String pin) async {
    if (_pkSessionCache != null && _pkSessionPin == pin) {
      return Map<String, dynamic>.from(_pkSessionCache!);
    }
    try {
      final encrypted = await _secureStorage.read(key: _privateKeysKey);
      if (encrypted == null || encrypted.isEmpty) {
        _pkSessionCache = {};
        _pkSessionPin   = pin;
        return {};
      }
      final decrypted = await EncryptionService.decryptAsync(encrypted, pin);
      final result    = jsonDecode(decrypted) as Map<String, dynamic>;
      _pkSessionCache = result;
      _pkSessionPin   = pin;
      return Map<String, dynamic>.from(result);
    } on EncryptionException {
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Зберігає всі приватні ключі та оновлює session-кеш
  static Future<void> _saveAllPrivateKeys(
    Map<String, dynamic> keys,
    String pin,
  ) async {
    final json = jsonEncode(keys);
    final encrypted = await EncryptionService.encryptAsync(json, pin);
    await _secureStorage.write(key: _privateKeysKey, value: encrypted);
    _pkSessionCache = Map<String, dynamic>.from(keys);
    _pkSessionPin   = pin;
  }

  /// Видаляє приватний ключ
  static Future<void> deletePrivateKey({
    required String blockchain,
    required String address,
    required String pin,
  }) async {
    final allKeys = await _getAllPrivateKeys(pin);
    final blockchainKey = '${blockchain}_${address}';
    allKeys.remove(blockchainKey);
    await _saveAllPrivateKeys(allKeys, pin);
    _log('Private key deleted for $blockchain: $address');
  }

  /// Видаляє всі приватні ключі
  static Future<void> deleteAllPrivateKeys() async {
    await _secureStorage.delete(key: _privateKeysKey);
    clearPrivateKeyCache();
    _log('All private keys deleted');
  }

  // ==================== WALLET ADDRESSES ====================

  /// Зберігає список адрес гаманців (не sensitive, можна зберігати як plain text)
  static Future<void> storeWalletAddresses(List<Map<String, dynamic>> addresses) async {
    final json = jsonEncode(addresses);
    await _secureStorage.write(key: _walletAddressesKey, value: json);
  }

  /// Отримує список адрес гаманців
  static Future<List<Map<String, dynamic>>> getWalletAddresses() async {
    final json = await _secureStorage.read(key: _walletAddressesKey);
    if (json == null || json.isEmpty) return [];
    
    return List<Map<String, dynamic>>.from(jsonDecode(json));
  }

  // ==================== BACKUP STATUS ====================

  /// Позначає що backup було зроблено
  static Future<void> markBackupAsDone() async {
    await _secureStorage.write(key: _backupStatusKey, value: 'true');
    await _secureStorage.write(
      key: _lastBackupDateKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  /// Перевіряє чи було зроблено backup
  static Future<bool> isBackupDone() async {
    final status = await _secureStorage.read(key: _backupStatusKey);
    return status == 'true';
  }

  /// Отримує дату останнього backup
  static Future<DateTime?> getLastBackupDate() async {
    final dateStr = await _secureStorage.read(key: _lastBackupDateKey);
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  // ==================== GENERAL ====================

  /// Видаляє ВСІ дані (при logout або delete wallet)
  static Future<void> deleteAll() async {
    await _secureStorage.deleteAll();
    clearPrivateKeyCache();
    _log('All keys deleted from secure storage');
  }

  /// Перевіряє чи є взагалі якісь збережені дані
  static Future<bool> hasAnyData() async {
    final allData = await _secureStorage.readAll();
    return allData.isNotEmpty;
  }

  /// Змінює PIN код (перешифровує всі seed phrases і приватні ключі)
  static Future<bool> changePin(String oldPin, String newPin,
      {required List<String> walletIds}) async {
    try {
      // Verify old PIN first
      if (!await verifyAppPin(oldPin)) return false;

      // ── Phase 1: decrypt everything with old PIN (no writes yet) ──────────
      final seedsById = <String, String>{};
      for (final id in walletIds) {
        final seed = await getSeedPhrase(oldPin, walletId: id);
        if (seed != null) seedsById[id] = seed;
      }
      final privateKeys = await _getAllPrivateKeys(oldPin);

      // ── Phase 2: write everything with new PIN atomically ─────────────────
      for (final entry in seedsById.entries) {
        await storeSeedPhrase(entry.value, newPin, walletId: entry.key);
      }
      await _saveAllPrivateKeys(privateKeys, newPin);
      await storeAppPin(newPin);
      // Update biometric-stored PIN if it was set up
      if (await getPinForBiometric() != null) {
        await storePinForBiometric(newPin);
      }
      clearPrivateKeyCache();

      _log('PIN code changed successfully');
      return true;
    } catch (e) {
      _logError('Failed to change PIN', e);
      return false;
    }
  }

  // ==================== LOGGING ====================

  static void _log(String message) {
    // У production можна використовувати Firebase Analytics або інший logger
    // Зараз просто print для дебагу
    print('[KeyManager] $message');
  }

  static void _logError(String message, dynamic error) {
    print('[KeyManager] ERROR: $message - $error');
  }
}

/// Exception для помилок KeyManager
class KeyManagerException implements Exception {
  final String message;
  
  KeyManagerException(this.message);
  
  @override
  String toString() => 'KeyManagerException: $message';
}
