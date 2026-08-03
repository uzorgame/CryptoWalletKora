import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/services/storage_service.dart';

// ─── Auto-lock timeout ───────────────────────────────────────────────────────

enum AutoLockTimeout {
  immediately,
  oneMinute,
  fiveMinutes,
  fifteenMinutes,
  onLaunchOnly,
}

extension AutoLockTimeoutExt on AutoLockTimeout {
  String get displayName {
    switch (this) {
      case AutoLockTimeout.immediately:    return 'Immediately';
      case AutoLockTimeout.oneMinute:      return 'After 1 minute';
      case AutoLockTimeout.fiveMinutes:    return 'After 5 minutes';
      case AutoLockTimeout.fifteenMinutes: return 'After 15 minutes';
      case AutoLockTimeout.onLaunchOnly:   return 'On launch only';
    }
  }

  String get description {
    switch (this) {
      case AutoLockTimeout.immediately:    return 'Lock as soon as app is minimized';
      case AutoLockTimeout.oneMinute:      return 'Standard for banking apps';
      case AutoLockTimeout.fiveMinutes:    return 'Balance of security & convenience';
      case AutoLockTimeout.fifteenMinutes: return 'For frequent users';
      case AutoLockTimeout.onLaunchOnly:   return 'Only when app is fully closed';
    }
  }

  String get storageValue {
    switch (this) {
      case AutoLockTimeout.immediately:    return 'immediately';
      case AutoLockTimeout.oneMinute:      return '1min';
      case AutoLockTimeout.fiveMinutes:    return '5min';
      case AutoLockTimeout.fifteenMinutes: return '15min';
      case AutoLockTimeout.onLaunchOnly:   return 'launch_only';
    }
  }

  /// Returns null for onLaunchOnly (no background lock).
  Duration? get backgroundDuration {
    switch (this) {
      case AutoLockTimeout.immediately:    return Duration.zero;
      case AutoLockTimeout.oneMinute:      return const Duration(minutes: 1);
      case AutoLockTimeout.fiveMinutes:    return const Duration(minutes: 5);
      case AutoLockTimeout.fifteenMinutes: return const Duration(minutes: 15);
      case AutoLockTimeout.onLaunchOnly:   return null;
    }
  }

  static AutoLockTimeout fromStorage(String? value) {
    if (value == null) return AutoLockTimeout.fiveMinutes;
    return AutoLockTimeout.values.firstWhere(
      (t) => t.storageValue == value,
      orElse: () => AutoLockTimeout.fiveMinutes,
    );
  }
}

/// Settings State Notifier
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings.defaultSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (kDebugMode) debugPrint('[Settings] _loadSettings START');
    final currency = await StorageService.readString(StorageService.KEY_CURRENCY) ?? 'USD';
    final language = await StorageService.readString(StorageService.KEY_LANGUAGE) ?? 'en';
    final themeMode = await StorageService.readString(StorageService.KEY_THEME_MODE) ?? 'system';
    final pinEnabled = await StorageService.readBool(StorageService.KEY_PIN_ENABLED) ?? false;
    final biometricEnabled = await StorageService.readBool(StorageService.KEY_BIOMETRIC_ENABLED) ?? false;
    final autoLockRaw = await StorageService.readString(StorageService.KEY_AUTO_LOCK_TIMEOUT);
    final autoLock = AutoLockTimeoutExt.fromStorage(autoLockRaw);

    if (kDebugMode) {
      debugPrint('[Settings] Loaded: currency=$currency  language=$language  theme=$themeMode');
      debugPrint('[Settings] Loaded: pinEnabled=$pinEnabled  biometricEnabled=$biometricEnabled  autoLock=${autoLock.displayName}');
    }

    state = AppSettings(
      currency: currency,
      language: language,
      themeMode: themeMode,
      pinEnabled: pinEnabled,
      biometricEnabled: biometricEnabled,
      autoLockTimeout: autoLock,
    );
  }

  Future<void> setCurrency(String currency) async {
    if (kDebugMode) debugPrint('[Settings] currency: ${state.currency} → $currency');
    await StorageService.writeString(StorageService.KEY_CURRENCY, currency);
    state = state.copyWith(currency: currency);
  }

  Future<void> setLanguage(String language) async {
    if (kDebugMode) debugPrint('[Settings] language: ${state.language} → $language');
    await StorageService.writeString(StorageService.KEY_LANGUAGE, language);
    state = state.copyWith(language: language);
  }

  Future<void> setThemeMode(String themeMode) async {
    if (kDebugMode) debugPrint('[Settings] themeMode: ${state.themeMode} → $themeMode');
    await StorageService.writeString(StorageService.KEY_THEME_MODE, themeMode);
    state = state.copyWith(themeMode: themeMode);
  }

  Future<void> setPinEnabled(bool enabled) async {
    if (kDebugMode) debugPrint('[Settings] pinEnabled: ${state.pinEnabled} → $enabled');
    await StorageService.writeBool(StorageService.KEY_PIN_ENABLED, enabled);
    state = state.copyWith(pinEnabled: enabled);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (kDebugMode) debugPrint('[Settings] biometricEnabled: ${state.biometricEnabled} → $enabled');
    await StorageService.writeBool(StorageService.KEY_BIOMETRIC_ENABLED, enabled);
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<void> setAutoLockTimeout(AutoLockTimeout timeout) async {
    if (kDebugMode) debugPrint('[Settings] autoLock: ${state.autoLockTimeout.displayName} → ${timeout.displayName}');
    await StorageService.writeString(
        StorageService.KEY_AUTO_LOCK_TIMEOUT, timeout.storageValue);
    state = state.copyWith(autoLockTimeout: timeout);
  }

  Future<void> resetSettings() async {
    if (kDebugMode) debugPrint('[Settings] RESET all settings to defaults');
    await StorageService.clearAll();
    state = AppSettings.defaultSettings();
  }
}

/// Settings Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

/// Individual setting providers for convenience
final currencyProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).currency;
});

final languageProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).language;
});

final themeModeProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).themeMode;
});

final pinEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).pinEnabled;
});

final biometricEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).biometricEnabled;
});

final autoLockTimeoutProvider = Provider<AutoLockTimeout>((ref) {
  return ref.watch(settingsProvider).autoLockTimeout;
});

/// App Settings Model
class AppSettings {
  final String currency;
  final String language;
  final String themeMode; // 'light', 'dark', 'system'
  final bool pinEnabled;
  final bool biometricEnabled;
  final AutoLockTimeout autoLockTimeout;

  AppSettings({
    required this.currency,
    required this.language,
    required this.themeMode,
    required this.pinEnabled,
    required this.biometricEnabled,
    this.autoLockTimeout = AutoLockTimeout.fiveMinutes,
  });

  factory AppSettings.defaultSettings() {
    return AppSettings(
      currency: 'USD',
      language: 'en',
      themeMode: 'system',
      pinEnabled: false,
      biometricEnabled: false,
      autoLockTimeout: AutoLockTimeout.fiveMinutes,
    );
  }

  AppSettings copyWith({
    String? currency,
    String? language,
    String? themeMode,
    bool? pinEnabled,
    bool? biometricEnabled,
    AutoLockTimeout? autoLockTimeout,
  }) {
    return AppSettings(
      currency: currency ?? this.currency,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLockTimeout: autoLockTimeout ?? this.autoLockTimeout,
    );
  }
}

/// Supported currencies
class SupportedCurrencies {
  static const List<String> all = [
    'USD',
    'EUR',
    'GBP',
    'UAH',
    'BTC',
    'ETH',
  ];
}

/// Supported languages
class SupportedLanguages {
  static const List<String> all = [
    'en',
    'uk',
    'ru',
    'fr',
  ];
  
  static String getDisplayName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'uk':
        return 'Українська';
      case 'ru':
        return 'Русский';
      case 'fr':
        return 'Français';
      default:
        return code;
    }
  }
}
