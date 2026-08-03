import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A supported interface language.
///
/// The set is deliberately small and entirely Latin-script. Sixteen languages shipped before,
/// including Arabic, Japanese, Korean and Chinese — none of them maintained, and all of them
/// constraining every typographic choice in the app to whatever face happened to cover their
/// script.
@immutable
class KoraLanguage {
  const KoraLanguage(this.code, this.name, this.endonym);

  /// The asset file stem: `assets/Language/<code>.json`.
  final String code;

  /// The English name. This is also the value persisted in preferences.
  final String name;

  /// What speakers of the language call it — what the picker shows.
  final String endonym;
}

const List<KoraLanguage> kLanguages = [
  KoraLanguage('en', 'English', 'English'),
  KoraLanguage('de', 'German', 'Deutsch'),
  KoraLanguage('fr', 'French', 'Français'),
  KoraLanguage('es', 'Spanish', 'Español'),
];

const KoraLanguage kDefaultLanguage = KoraLanguage('en', 'English', 'English');

class LocalizationService {
  LocalizationService._();

  static const String _prefKey = 'selected_language';

  static LocalizationService? _instance;
  static LocalizationService get instance => _instance ??= LocalizationService._();

  KoraLanguage _current = kDefaultLanguage;
  Map<String, String> _translations = const {};

  KoraLanguage get current => _current;
  String get currentLanguage => _current.name;

  /// Resolves a persisted value to a supported language, falling back to English.
  ///
  /// A preference written by an older build can name a language that no longer ships. That is
  /// not an error worth surfacing — it is a wallet whose owner should simply see English.
  static KoraLanguage resolve(String? value) => kLanguages.firstWhere(
        (l) => l.name == value || l.code == value,
        orElse: () => kDefaultLanguage,
      );

  Future<void> loadLanguage(String value) async {
    final language = resolve(value);
    try {
      final raw = await rootBundle.loadString('assets/Language/${language.code}.json');
      final map = json.decode(raw) as Map<String, dynamic>;
      _translations = map.map((k, v) => MapEntry(k, v.toString()));
      _current = language;
      await _persist(language);
    } catch (e) {
      debugPrint('LocalizationService: could not load ${language.code} — $e');
      if (language.code != kDefaultLanguage.code) {
        await loadLanguage(kDefaultLanguage.name);
      }
    }
  }

  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    await loadLanguage(prefs.getString(_prefKey) ?? kDefaultLanguage.name);
  }

  /// An unknown key returns itself, so a missing translation reads as an untranslated string
  /// rather than as an empty box.
  String translate(String key) => _translations[key] ?? key;

  Future<void> _persist(KoraLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, language.name);
  }
}

/// Global shorthand used throughout the UI.
String tr(String key) => LocalizationService.instance.translate(key);
