import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Сервіс біометричної аутентифікації
/// Використовує Local Auth для Face ID, Touch ID, Fingerprint
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Перевіряє чи доступна біометрія на пристрої
  static Future<bool> isAvailable() async {
    try {
      final result = await _auth.canCheckBiometrics;
      if (kDebugMode) debugPrint('[Biometric] isAvailable=$result');
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[Biometric] isAvailable ERROR: $e');
      return false;
    }
  }

  /// Перевіряє чи доступна будь-яка біометрія
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// Отримує список доступних типів біометрії
  static Future<List<BiometricType>> getAvailableTypes() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (kDebugMode) debugPrint('[Biometric] availableTypes=${types.map((t) => t.name).toList()}');
      return types;
    } catch (e) {
      if (kDebugMode) debugPrint('[Biometric] getAvailableTypes ERROR: $e');
      return [];
    }
  }

  /// Перевіряє чи доступний Face ID (iOS)
  static Future<bool> hasFaceId() async {
    final types = await getAvailableTypes();
    return types.contains(BiometricType.face);
  }

  /// Перевіряє чи доступний Touch ID / Fingerprint
  static Future<bool> hasFingerprint() async {
    final types = await getAvailableTypes();
    return types.contains(BiometricType.fingerprint) ||
           types.contains(BiometricType.strong) ||
           types.contains(BiometricType.weak);
  }

  /// Перевіряє чи доступний Iris сканер
  static Future<bool> hasIris() async {
    final types = await getAvailableTypes();
    return types.contains(BiometricType.iris);
  }

  /// Аутентифікує користувача за допомогою біометрії
  /// [reason] - повідомлення яке показується користувачу
  /// [useErrorDialogs] - показувати системні діалоги помилок
  /// [stickyAuth] - залишати аутентифікацію активною при зміні app lifecycle
  static Future<BiometricResult> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
    bool biometricOnly = true,
    Duration? lockOutDuration,
  }) async {
    if (kDebugMode) debugPrint('[Biometric] authenticate() START  reason="$reason"  biometricOnly=$biometricOnly');
    final sw = Stopwatch()..start();
    try {
      // Перевіряємо чи доступна біометрія
      final bioAvailable = await isAvailable();
      if (!bioAvailable) {
        if (kDebugMode) debugPrint('[Biometric] ❌ notAvailable — canCheckBiometrics=false');
        return BiometricResult.notAvailable;
      }

      // Виконуємо аутентифікацію
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Біометрична аутентифікація',
            cancelButton: 'Скасувати',
            deviceCredentialsRequiredTitle: 'Потрібна верифікація пристрою',
            deviceCredentialsSetupDescription: 'Будь ласка, налаштуйте PIN або біометрію',
            biometricHint: 'Використайте біометрію',
            biometricNotRecognized: 'Не розпізнано, спробуйте ще раз',
            biometricSuccess: 'Успішна аутентифікація',
          ),
          IOSAuthMessages(
            lockOut: 'Будь ласка, спробуйте пізніше',
            goToSettingsButton: 'Налаштування',
            goToSettingsDescription: 'Будь ласка, налаштуйте біометрію в Settings',
            cancelButton: 'Скасувати',
          ),
        ],
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: biometricOnly,
        ),
      );

      sw.stop();
      // Тактильний фідбек при успіху
      if (didAuthenticate) {
        if (kDebugMode) debugPrint('[Biometric] ✅ SUCCESS in ${sw.elapsedMilliseconds}ms');
        await HapticFeedback.lightImpact();
        return BiometricResult.success;
      } else {
        if (kDebugMode) debugPrint('[Biometric] ⚠️ CANCELLED by user in ${sw.elapsedMilliseconds}ms');
        return BiometricResult.cancelled;
      }
    } on PlatformException catch (e) {
      sw.stop();
      if (kDebugMode) debugPrint('[Biometric] ❌ PlatformException code=${e.code}  msg=${e.message}  in ${sw.elapsedMilliseconds}ms');
      return _handlePlatformException(e);
    } catch (e) {
      sw.stop();
      if (kDebugMode) debugPrint('[Biometric] ❌ Exception: $e  in ${sw.elapsedMilliseconds}ms');
      return BiometricResult.error;
    }
  }

  /// Аутентифікує з можливістю використання PIN/Password як fallback
  static Future<BiometricResult> authenticateWithFallback({
    required String reason,
    required String fallbackMessage,
  }) async {
    return authenticate(
      reason: reason,
      biometricOnly: false,
    );
  }

  /// Обробляє PlatformException
  static BiometricResult _handlePlatformException(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return BiometricResult.notAvailable;
      case 'NotEnrolled':
        return BiometricResult.notEnrolled;
      case 'PasscodeNotSet':
        return BiometricResult.passcodeNotSet;
      case 'LockedOut':
        return BiometricResult.lockedOut;
      case 'PermanentlyLockedOut':
        return BiometricResult.permanentlyLockedOut;
      default:
        return BiometricResult.error;
    }
  }

  /// Відкриває налаштування біометрії (iOS/Android Settings)
  static Future<void> openSettings() async {
    await _auth.stopAuthentication();
    // На практиці треба використовувати url_launcher для відкриття Settings
  }

  /// Зупиняє активну аутентифікацію
  static Future<bool> stopAuthentication() async {
    return await _auth.stopAuthentication();
  }
}

/// Результат біометричної аутентифікації
enum BiometricResult {
  /// Успішна аутентифікація
  success,
  
  /// Користувач скасував
  cancelled,
  
  /// Біометрія не доступна на пристрої
  notAvailable,
  
  /// Біометрія не налаштована (не зареєстровані відбитки/обличчя)
  notEnrolled,
  
  /// PIN/Passcode не встановлений
  passcodeNotSet,
  
  /// Тимчасове блокування (занадто багато спроб)
  lockedOut,
  
  /// Постійне блокування (потрібен PIN)
  permanentlyLockedOut,
  
  /// Інша помилка
  error,
}

extension BiometricResultExtension on BiometricResult {
  /// Чи була аутентифікація успішною
  bool get isSuccess => this == BiometricResult.success;
  
  /// Чи була аутентифікація скасована
  bool get isCancelled => this == BiometricResult.cancelled;
  
  /// Чи є помилка
  bool get isError => this != BiometricResult.success && this != BiometricResult.cancelled;
  
  /// Отримує user-friendly повідомлення
  String get message {
    switch (this) {
      case BiometricResult.success:
        return 'Аутентифікація успішна';
      case BiometricResult.cancelled:
        return 'Аутентифікацію скасовано';
      case BiometricResult.notAvailable:
        return 'Біометрія не доступна на цьому пристрої';
      case BiometricResult.notEnrolled:
        return 'Біометрія не налаштована. Будь ласка, налаштуйте в Settings';
      case BiometricResult.passcodeNotSet:
        return 'PIN код не встановлений. Будь ласка, налаштуйте в Settings';
      case BiometricResult.lockedOut:
        return 'Занадто багато спроб. Спробуйте пізніше';
      case BiometricResult.permanentlyLockedOut:
        return 'Потрібен PIN код для розблокування';
      case BiometricResult.error:
        return 'Помилка аутентифікації';
    }
  }
}
