import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mixin for [State] subclasses that use [AppColors] directly.
/// Automatically calls [setState] whenever the theme changes so the
/// widget rebuilds with the correct palette without needing a
/// [ListenableBuilder] wrapper in every screen.
mixin ThemeAwareMixin<T extends StatefulWidget> on State<T> {
  void _onTheme() {
    // Delay rebuild slightly to let overlay animation start first
    // This prevents jerky/abrupt theme switching
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    ThemeNotifier.instance.addListener(_onTheme);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onTheme);
    super.dispose();
  }
}

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
