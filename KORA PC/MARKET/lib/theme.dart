import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KORA Market — the uz-or design system.
///
/// Monochrome throughout, with exactly one exception: the direction of a price. That is the
/// only place on screen where colour carries information rather than decoration. Everything
/// is square; nothing is rounded, tinted or shadowed for its own sake.

// ── Typography ────────────────────────────────────────────────────────────────
/// The prototype's three faces, bundled as static instances so the weights are the real
/// drawn ones rather than interpolations of a variable axis.
///
/// Space Grotesk carries no Cyrillic — checked, not assumed — so anything set in it falls
/// back to Inter. Every string in this interface is Latin or numeric today, and the fallback
/// is what keeps that from becoming a rule nobody wrote down.
const String kSans = 'Inter';
const String kDisplay = 'Space Grotesk';
const String kMono = 'JetBrains Mono';
const List<String> kDisplayFallback = ['Inter'];

/// The house easing — a fast start that settles rather than bounces.
const Curve kEase = Cubic(0.16, 1, 0.3, 1);

const double kTitlebarHeight = 46;
const double kStatusbarHeight = 26;

// ── Palette ───────────────────────────────────────────────────────────────────

@immutable
class Palette {
  const Palette({
    required this.bg,
    required this.bgAlt,
    required this.surface,
    required this.surfaceHi,
    required this.text,
    required this.text2,
    required this.text3,
    required this.border,
    required this.borderHi,
    required this.up,
    required this.down,
    required this.flashUp,
    required this.flashDown,
  });

  final Color bg, bgAlt, surface, surfaceHi;
  final Color text, text2, text3;
  final Color border, borderHi;
  final Color up, down, flashUp, flashDown;

  static const dark = Palette(
    bg: Color(0xFF0A0A0A),
    bgAlt: Color(0xFF111111),
    surface: Color(0xFF0F0F0F),
    surfaceHi: Color(0xFF161616),
    text: Color(0xFFF0F0F0),
    text2: Color(0xFF8A8A8A),
    text3: Color(0xFF4A4A4A),
    border: Color(0x1AFFFFFF),
    borderHi: Color(0x38FFFFFF),
    up: Color(0xFF3FB950),
    down: Color(0xFFF85149),
    flashUp: Color(0x293FB950),
    flashDown: Color(0x29F85149),
  );

  static const light = Palette(
    bg: Color(0xFFFFFFFF),
    bgAlt: Color(0xFFF6F6F6),
    surface: Color(0xFFFFFFFF),
    surfaceHi: Color(0xFFFAFAFA),
    text: Color(0xFF111111),
    text2: Color(0xFF6B6B6B),
    text3: Color(0xFFA0A0A0),
    border: Color(0x1F000000),
    borderHi: Color(0x47000000),
    up: Color(0xFF1A7F37),
    down: Color(0xFFCF222E),
    flashUp: Color(0x1A1A7F37),
    flashDown: Color(0x1ACF222E),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// The one colour decision in the product: which way did it go.
  Color direction(num v) => v >= 0 ? up : down;
}

// ── Text styles ───────────────────────────────────────────────────────────────

/// Small uppercase mono with wide tracking — the system's label voice.
TextStyle label(
  Color color, {
  double size = 10,
  double tracking = 0.12,
  FontWeight weight = FontWeight.w400,
}) =>
    TextStyle(
      fontFamily: kMono,
      fontSize: size,
      fontWeight: weight,
      height: 1.2,
      letterSpacing: size * tracking,
      color: color,
    );

/// Figures the eye compares down a column, so they must not reflow as digits change.
TextStyle numeric(Color color, {double size = 14, FontWeight weight = FontWeight.w500}) =>
    TextStyle(
      fontFamily: kDisplay,
      fontFamilyFallback: kDisplayFallback,
      fontSize: size,
      fontWeight: weight,
      height: 1.05,
      letterSpacing: -size * 0.02,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

TextStyle body(Color color, {double size = 11, FontWeight weight = FontWeight.w400}) =>
    TextStyle(fontFamily: kSans, fontSize: size, fontWeight: weight, height: 1.25, color: color);

// ── Theme mode, persisted ─────────────────────────────────────────────────────

class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier._();
  static final instance = ThemeNotifier._();

  static const _key = 'kora_market_theme_mode';

  // Dark first: this is a window that sits open on a desktop all day.
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == 'light') _mode = ThemeMode.light;
      if (saved == 'dark') _mode = ThemeMode.dark;
    } catch (_) {
      // A missing preference store is not a reason to refuse to start.
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, isDark ? 'dark' : 'light');
    } catch (_) {}
  }
}

// ── ThemeData ─────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData _build(Palette p, Brightness brightness) => ThemeData(
        useMaterial3: true,
        brightness: brightness,
        fontFamily: kSans,
        scaffoldBackgroundColor: p.bg,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        colorScheme: ColorScheme(
          brightness: brightness,
          surface: p.surface,
          onSurface: p.text,
          primary: p.text,
          onPrimary: p.bg,
          secondary: p.text2,
          onSecondary: p.bg,
          error: p.down,
          onError: p.bg,
          outline: p.border,
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(p.border),
          thickness: WidgetStateProperty.all(9),
          radius: Radius.zero,
        ),
      );

  static ThemeData get dark => _build(Palette.dark, Brightness.dark);
  static ThemeData get light => _build(Palette.light, Brightness.light);
}
