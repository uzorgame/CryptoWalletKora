import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's theme, and the only owner of the stored `theme_mode` key.
///
/// The root listens to this and hands the mode to `MaterialApp`, so a change reaches every
/// widget through the theme itself. A `ThemeAwareMixin` used to sit here and make six screens
/// each call `setState` on a 50 ms delay when the theme changed — six staggered rebuilds
/// where one is enough, and a visible stutter that the delay was added to hide.
class ThemeNotifier extends ChangeNotifier {
  static const _key = 'theme_mode';

  /// Global singleton — accessible from anywhere via ThemeNotifier.instance
  static final ThemeNotifier instance = ThemeNotifier._();

  ThemeNotifier._() {
    _load();
  }

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? 'Light';
    _mode = _fromString(saved);
    notifyListeners();
  }

  Future<void> setTheme(String themeName) async {
    _mode = _fromString(themeName);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, themeName);
  }

  Future<void> toggleTheme() async {
    final newTheme = _mode == ThemeMode.dark ? 'Light' : 'Dark';
    await setTheme(newTheme);
  }

  ThemeMode _fromString(String name) {
    switch (name) {
      case 'Dark':
      case 'AMOLED':
        return ThemeMode.dark;
      default:
        return ThemeMode.light;
    }
  }
}
