import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kora/core/services/theme_notifier.dart';

// ─────────────────────── KORA dark palette ────────────────────────────────────
// The same tokens as the Windows wallet's kora_design.dart, so the two products are one
// design. `accent` maps to the ink colour on purpose: in this language the primary action is
// the inverted surface, not a brand blue.
const _dBackground   = Color(0xFF0A0A0A);
const _dSurface      = Color(0xFF0F0F0F);
const _dCard         = Color(0xFF0F0F0F);
const _dCardElevated = Color(0xFF161616);
const _dSeparator    = Color(0x1AFFFFFF);
const _dBorder       = Color(0x1AFFFFFF);
const _dBorderHi     = Color(0x38FFFFFF);
const _dTextPrimary  = Color(0xFFF0F0F0);
const _dTextSecondary= Color(0xFF8A8A8A);
const _dTextTertiary = Color(0xFF4A4A4A);
const _dPositive     = Color(0xFF3FB950);
const _dNegative     = Color(0xFFF85149);
const _dAccent       = Color(0xFFF0F0F0);
const _dWarning      = Color(0xFFD29922);

// ─────────────────────── KORA light palette ───────────────────────────────────
const _lBackground   = Color(0xFFFFFFFF);
const _lSurface      = Color(0xFFFFFFFF);
const _lCard         = Color(0xFFFFFFFF);
const _lCardElevated = Color(0xFFFAFAFA);
const _lSeparator    = Color(0x1F000000);
const _lBorder       = Color(0x1F000000);
const _lBorderHi     = Color(0x47000000);
const _lTextPrimary  = Color(0xFF111111);
const _lTextSecondary= Color(0xFF6B6B6B);
const _lTextTertiary = Color(0xFFA0A0A0);
const _lPositive     = Color(0xFF1A7F37);
const _lNegative     = Color(0xFFCF222E);
const _lAccent       = Color(0xFF111111);
const _lWarning      = Color(0xFF9A6700);

// ─────────────────────────── AppColors (dynamic) ─────────────────────────────
class AppColors {
  AppColors._();

  static bool get _d => ThemeNotifier.instance.isDark;

  static Color get background    => _d ? _dBackground   : _lBackground;
  static Color get surface       => _d ? _dSurface      : _lSurface;
  static Color get card          => _d ? _dCard         : _lCard;
  static Color get cardElevated  => _d ? _dCardElevated : _lCardElevated;
  static Color get separator     => _d ? _dSeparator    : _lSeparator;
  static Color get border        => _d ? _dBorder       : _lBorder;

  /// The brighter hairline: focus rings, pressed outlines, the PIN dots' rest state.
  static Color get borderHi      => _d ? _dBorderHi     : _lBorderHi;

  static Color get textPrimary   => _d ? _dTextPrimary   : _lTextPrimary;
  static Color get textSecondary => _d ? _dTextSecondary : _lTextSecondary;
  static Color get textTertiary  => _d ? _dTextTertiary  : _lTextTertiary;

  static Color get positive => _d ? _dPositive : _lPositive;
  static Color get negative => _d ? _dNegative : _lNegative;
  static Color get accent   => _d ? _dAccent   : _lAccent;
  static Color get warning  => _d ? _dWarning  : _lWarning;

  static const Color btc = Color(0xFFF7931A);
  static const Color eth = Color(0xFF627EEA);
  static const Color sol = Color(0xFF9945FF);
  static const Color bnb = Color(0xFFF3BA2F);
  static const Color trx = Color(0xFFEF0027);

  static Color coinColor(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'BTC': return btc;
      case 'ETH': return eth;
      case 'SOL': return sol;
      case 'BNB': return bnb;
      case 'TRX': return trx;
      default:    return accent;
    }
  }
}

// ─────────────────────────── AppTheme ────────────────────────────────────────
const _fontFamily = 'Inter';

class AppTheme {
  AppTheme._();

  static SystemUiOverlayStyle get overlayStyle => ThemeNotifier.instance.isDark
      ? const SystemUiOverlayStyle(
          statusBarColor:                    Colors.transparent,
          statusBarIconBrightness:           Brightness.light,
          statusBarBrightness:               Brightness.dark,
          systemNavigationBarColor:          _dBackground,
          systemNavigationBarIconBrightness: Brightness.light,
        )
      : const SystemUiOverlayStyle(
          statusBarColor:                    Colors.transparent,
          statusBarIconBrightness:           Brightness.dark,
          statusBarBrightness:               Brightness.light,
          systemNavigationBarColor:          _lBackground,
          systemNavigationBarIconBrightness: Brightness.dark,
        );

  static ThemeData get light => ThemeData(
    useMaterial3:            true,
    brightness:              Brightness.light,
    fontFamily:              _fontFamily,
    scaffoldBackgroundColor: _lBackground,
    colorScheme: const ColorScheme.light(
      surface:   _lSurface,
      primary:   _lTextPrimary,
      onPrimary: _lBackground,
      secondary: _lAccent,
      error:     _lNegative,
      onSurface: _lTextPrimary,
      outline:   _lBorder,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:        _lBackground,
      elevation:              0,
      scrolledUnderElevation: 0,
      centerTitle:            true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      iconTheme:     IconThemeData(color: _lTextPrimary, size: 22),
      titleTextStyle: TextStyle(
        color: _lTextPrimary, fontSize: 17, fontWeight: FontWeight.w600,
        letterSpacing: -0.4, fontFamily: _fontFamily,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge:   TextStyle(color: _lTextPrimary,   fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -2.0,  fontFamily: _fontFamily),
      displayMedium:  TextStyle(color: _lTextPrimary,   fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.0,  fontFamily: _fontFamily),
      displaySmall:   TextStyle(color: _lTextPrimary,   fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5,  fontFamily: _fontFamily),
      headlineLarge:  TextStyle(color: _lTextPrimary,   fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5,  fontFamily: _fontFamily),
      headlineMedium: TextStyle(color: _lTextPrimary,   fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3,  fontFamily: _fontFamily),
      headlineSmall:  TextStyle(color: _lTextPrimary,   fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4,  fontFamily: _fontFamily),
      bodyLarge:      TextStyle(color: _lTextPrimary,   fontSize: 17, fontWeight: FontWeight.w400, fontFamily: _fontFamily),
      bodyMedium:     TextStyle(color: _lTextSecondary, fontSize: 15, fontWeight: FontWeight.w400, fontFamily: _fontFamily),
      bodySmall:      TextStyle(color: _lTextSecondary, fontSize: 13, fontWeight: FontWeight.w400, fontFamily: _fontFamily),
      labelLarge:     TextStyle(color: _lTextPrimary,   fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3,  fontFamily: _fontFamily),
      labelMedium:    TextStyle(color: _lTextSecondary, fontSize: 13, fontWeight: FontWeight.w500, fontFamily: _fontFamily),
      labelSmall:     TextStyle(color: _lTextTertiary,  fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.4,   fontFamily: _fontFamily),
    ),
    dividerTheme: const DividerThemeData(color: _lSeparator, thickness: 0.5, space: 0),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _lTextPrimary,
        foregroundColor: _lBackground,
        minimumSize:     const Size(double.infinity, 56),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3, fontFamily: _fontFamily),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _lTextPrimary,
        minimumSize:     const Size(double.infinity, 56),
        side:            const BorderSide(color: _lBorder),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3, fontFamily: _fontFamily),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:         true,
      fillColor:      _lSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border:         OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: _lBorder)),
      enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: _lBorder)),
      focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: _lTextSecondary, width: 1.5)),
      errorBorder:    OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: _lNegative)),
      hintStyle:      const TextStyle(color: _lTextTertiary, fontSize: 15, fontFamily: _fontFamily),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor:  _lCardElevated,
      contentTextStyle: const TextStyle(color: _lTextPrimary, fontSize: 14, fontFamily: _fontFamily),
      shape:            RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      behavior:         SnackBarBehavior.floating,
      insetPadding:     const EdgeInsets.all(16),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:      _lBackground,
      selectedItemColor:    _lTextPrimary,
      unselectedItemColor:  _lTextTertiary,
      type:                 BottomNavigationBarType.fixed,
      elevation:            0,
      selectedLabelStyle:   TextStyle(fontSize: 10, fontWeight: FontWeight.w500, fontFamily: _fontFamily),
      unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, fontFamily: _fontFamily),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3:            true,
    brightness:              Brightness.dark,
    fontFamily:              _fontFamily,
    scaffoldBackgroundColor: _dBackground,
    colorScheme: const ColorScheme.dark(
      surface:   _dSurface,
      primary:   _dTextPrimary,
      onPrimary: _dBackground,
      secondary: _dAccent,
      error:     _dNegative,
      onSurface: _dTextPrimary,
      outline:   _dBorder,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:        _dBackground,
      elevation:              0,
      scrolledUnderElevation: 0,
      centerTitle:            true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      iconTheme:     IconThemeData(color: _dTextPrimary, size: 22),
      titleTextStyle: TextStyle(
        color: _dTextPrimary, fontSize: 17, fontWeight: FontWeight.w600,
        letterSpacing: -0.4, fontFamily: _fontFamily,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge:   TextStyle(color: _dTextPrimary,   fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -2.0,  fontFamily: _fontFamily),
      displayMedium:  TextStyle(color: _dTextPrimary,   fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.0,  fontFamily: _fontFamily),
      displaySmall:   TextStyle(color: _dTextPrimary,   fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5,  fontFamily: _fontFamily),
      headlineLarge:  TextStyle(color: _dTextPrimary,   fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5,  fontFamily: _fontFamily),
      headlineMedium: TextStyle(color: _dTextPrimary,   fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3,  fontFamily: _fontFamily),
      headlineSmall:  TextStyle(color: _dTextPrimary,   fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4,  fontFamily: _fontFamily),
      bodyLarge:      TextStyle(color: _dTextPrimary,   fontSize: 17, fontWeight: FontWeight.w400, fontFamily: _fontFamily),
      bodyMedium:     TextStyle(color: _dTextSecondary, fontSize: 15, fontWeight: FontWeight.w400, fontFamily: _fontFamily),
      bodySmall:      TextStyle(color: _dTextSecondary, fontSize: 13, fontWeight: FontWeight.w400, fontFamily: _fontFamily),
      labelLarge:     TextStyle(color: _dTextPrimary,   fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3,  fontFamily: _fontFamily),
      labelMedium:    TextStyle(color: _dTextSecondary, fontSize: 13, fontWeight: FontWeight.w500, fontFamily: _fontFamily),
      labelSmall:     TextStyle(color: _dTextTertiary,  fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.4,   fontFamily: _fontFamily),
    ),
    dividerTheme: const DividerThemeData(color: _dSeparator, thickness: 0.5, space: 0),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _dTextPrimary,
        foregroundColor: _dBackground,
        minimumSize:     const Size(double.infinity, 56),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3, fontFamily: _fontFamily),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _dTextPrimary,
        minimumSize:     const Size(double.infinity, 56),
        side:            const BorderSide(color: _dBorder),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3, fontFamily: _fontFamily),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:         true,
      fillColor:      _dSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border:         OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: _dBorder)),
      enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: _dBorder)),
      focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: _dTextSecondary, width: 1.5)),
      errorBorder:    OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: _dNegative)),
      hintStyle:      const TextStyle(color: _dTextTertiary, fontSize: 15, fontFamily: _fontFamily),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor:  _dCardElevated,
      contentTextStyle: const TextStyle(color: _dTextPrimary, fontSize: 14, fontFamily: _fontFamily),
      shape:            RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      behavior:         SnackBarBehavior.floating,
      insetPadding:     const EdgeInsets.all(16),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:      Color(0xFF0A0A0A),
      selectedItemColor:    _dTextPrimary,
      unselectedItemColor:  _dTextTertiary,
      type:                 BottomNavigationBarType.fixed,
      elevation:            0,
      selectedLabelStyle:   TextStyle(fontSize: 10, fontWeight: FontWeight.w500, fontFamily: _fontFamily),
      unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, fontFamily: _fontFamily),
    ),
  );
}
