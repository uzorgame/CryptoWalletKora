import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Уніфікований сервіс зберігання даних
/// Використовує Secure Storage для sensitive даних
/// та SharedPreferences для налаштувань
class StorageService {
  // ==================== SECURE STORAGE ====================
  
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Зберігає значення в Secure Storage
  static Future<void> writeSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  /// Читає значення з Secure Storage
  static Future<String?> readSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  /// Видаляє значення з Secure Storage
  static Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  /// Перевіряє чи існує ключ
  static Future<bool> hasSecure(String key) async {
    final value = await readSecure(key);
    return value != null && value.isNotEmpty;
  }

  // ==================== SHARED PREFERENCES ====================

  /// Зберігає String
  static Future<void> writeString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  /// Зберігає bool
  static Future<void> writeBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// Зберігає int
  static Future<void> writeInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  /// Зберігає double
  static Future<void> writeDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  /// Зберігає List<String>
  static Future<void> writeStringList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  /// Зберігає Map як JSON
  static Future<void> writeJson(String key, Map<String, dynamic> value) async {
    final json = jsonEncode(value);
    await writeString(key, json);
  }

  /// Читає String
  static Future<String?> readString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  /// Читає bool
  static Future<bool?> readBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  /// Читає int
  static Future<int?> readInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }

  /// Читає double
  static Future<double?> readDouble(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(key);
  }

  /// Читає List<String>
  static Future<List<String>?> readStringList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key);
  }

  /// Читає Map з JSON
  static Future<Map<String, dynamic>?> readJson(String key) async {
    final json = await readString(key);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  /// Видаляє значення
  static Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Перевіряє чи існує ключ
  static Future<bool> has(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }

  /// Очищає всі SharedPreferences.
  ///
  /// НЕБЕЗПЕЧНО: це стирає і `wallets` — список гаманців користувача, тобто запис про те,
  /// які ключі взагалі існують. Це не «скидання налаштувань», а втрата доступу до коштів.
  /// Для скидання налаштувань видаляй потрібні ключі поіменно через [delete].
  @Deprecated('Стирає wallets разом з налаштуваннями. Видаляй ключі поіменно через delete().')
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ==================== CONSTANTS ====================

  /// Ключі для зберігання
  static const String KEY_FIRST_LAUNCH = 'first_launch';
  static const String KEY_PIN_ENABLED = 'pin_enabled';
  static const String KEY_BIOMETRIC_ENABLED = 'biometric_enabled';
  static const String KEY_THEME_MODE = 'theme_mode';
  static const String KEY_CURRENCY = 'currency';
  static const String KEY_LANGUAGE = 'language';
  static const String KEY_LAST_BACKUP = 'last_backup';
  static const String KEY_WALLET_CREATED      = 'wallet_created';
  static const String KEY_AUTO_LOCK_TIMEOUT   = 'auto_lock_timeout';

  // ==================== HELPER METHODS ====================

  /// Ініціалізація за замовчуванням
  static Future<void> initializeDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!prefs.containsKey(KEY_FIRST_LAUNCH)) {
      await prefs.setBool(KEY_FIRST_LAUNCH, true);
    }
    if (!prefs.containsKey(KEY_CURRENCY)) {
      await prefs.setString(KEY_CURRENCY, 'USD');
    }
    if (!prefs.containsKey(KEY_LANGUAGE)) {
      await prefs.setString(KEY_LANGUAGE, 'en');
    }
  }

  /// Перевіряє чи це перший запуск
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(KEY_FIRST_LAUNCH) ?? true;
  }

  /// Позначає що перший запуск завершено
  static Future<void> setFirstLaunchComplete() async {
    await writeBool(KEY_FIRST_LAUNCH, false);
  }

  /// Отримує всі налаштування для дебагу
  static Future<Map<String, dynamic>> getAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    final Map<String, dynamic> settings = {};
    for (final key in keys) {
      settings[key] = prefs.get(key);
    }
    
    return settings;
  }
}
