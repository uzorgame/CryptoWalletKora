import 'package:flutter/material.dart';

/// KORA — the uz-or design system, shared with KORA Market.
///
/// Monochrome throughout, with exactly one exception: the direction of a value. That is the
/// only place on screen where colour carries information rather than decoration. Everything
/// is square; nothing is rounded, tinted or shadowed for its own sake.

// ── Typography ────────────────────────────────────────────────────────────────
/// The three faces of the prototype, bundled as static instances.
///
/// One fallback each, and only to Inter. The app ships in English, German, French and
/// Spanish — all Latin — so the three faces cover every glyph the interface can produce, and
/// Inter is there for the odd symbol a display or mono face happens to lack.
const String kSans = 'Inter';
const String kDisplay = 'Space Grotesk';
const String kMono = 'JetBrains Mono';

const List<String> kDisplayFallback = [kSans];
const List<String> kMonoFallback = [kSans];

/// The house easing — a fast start that settles rather than bounces.
const Curve kEase = Cubic(0.16, 1, 0.3, 1);

const double kTitlebarHeight = 46;
const double kRailWidth = 176;

/// Timings, taken from the prototype rather than approximated.
const Duration kViewFade = Duration(milliseconds: 300);
const Duration kViewSlide = Duration(milliseconds: 420);
const Duration kMarkerTravel = Duration(milliseconds: 380);
const Duration kHoverFast = Duration(milliseconds: 160);
const Duration kHover = Duration(milliseconds: 200);
const Duration kControl = Duration(milliseconds: 180);
const Duration kInk = Duration(milliseconds: 220);

/// How long the view takes to reach where a wheel notch sent it. Long enough to read as
/// travel, short enough that a second notch does not feel queued behind the first.
const Duration kSmoothScroll = Duration(milliseconds: 260);
const Duration kRowRise = Duration(milliseconds: 420);
const Duration kRowStagger = Duration(milliseconds: 16);

/// How many rows of a table get an entrance.
///
/// The stagger exists so a table assembles itself rather than appearing all at once, and only
/// the first screenful is ever watched assembling. Past that it would be a delay on a row the
/// user scrolled to and is waiting to read — and in a lazy list those rows are built during
/// the scroll, so it would read as rows arriving late rather than as an entrance.
const int kStaggeredRows = 14;
const double kViewTravel = 20;

// ── Palette ───────────────────────────────────────────────────────────────────

@immutable
class Kora {
  const Kora({
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
    required this.hover,
    required this.selected,
  });

  final Color bg, bgAlt, surface, surfaceHi;
  final Color text, text2, text3;
  final Color border, borderHi;
  final Color up, down, flashUp, flashDown;

  /// The wash under a hovered row, and under a selected one.
  ///
  /// Both are the same ink at different opacities, and that is the whole point. `Color.lerp`
  /// interpolates the four channels independently and is not premultiplied, so fading from
  /// `Colors.transparent` — which is transparent *black* — drags r, g and b up from zero while
  /// alpha rises. The midpoint of a hover on the light rail composited to #B9B9B9: sixty-one
  /// levels darker than the surface it sits on, while the settled hover was four levels
  /// lighter. The transition was fifteen times louder than the state it was transitioning to,
  /// which is what the flashing grey blocks were.
  ///
  /// Fading these to `withAlpha(0)` instead keeps r, g and b fixed and moves only alpha, so
  /// nothing appears on the way in that is not a fainter version of what appears at the end.
  final Color hover, selected;

  static const dark = Kora(
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
    hover: Color(0x0FFFFFFF),
    selected: Color(0x1FFFFFFF),
  );

  static const light = Kora(
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
    hover: Color(0x0A000000),
    selected: Color(0x14000000),
  );

  static Kora of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// The one colour decision in the product: which way did it go.
  Color direction(num v) => v >= 0 ? up : down;
}

// ── Text styles ───────────────────────────────────────────────────────────────

/// Small uppercase mono with wide tracking — the system's label voice.
TextStyle koraLabel(
  Color color, {
  double size = 10,
  double tracking = 0.12,
  FontWeight weight = FontWeight.w400,
}) =>
    TextStyle(
      fontFamily: kMono,
      fontFamilyFallback: kMonoFallback,
      fontSize: size,
      fontWeight: weight,
      height: 1.2,
      letterSpacing: size * tracking,
      color: color,
    );

/// Figures the eye compares down a column, so they must not reflow as digits change.
TextStyle koraNumeric(
  Color color, {
  double size = 14,
  FontWeight weight = FontWeight.w500,
}) =>
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

TextStyle koraBody(
  Color color, {
  double size = 11,
  FontWeight weight = FontWeight.w400,
}) =>
    TextStyle(
      fontFamily: kSans,
      fontSize: size,
      fontWeight: weight,
      height: 1.25,
      color: color,
    );

// ── ThemeData ─────────────────────────────────────────────────────────────────

class KoraTheme {
  KoraTheme._();

  static ThemeData _build(Kora p, Brightness brightness) => ThemeData(
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

  /// Built once, not per rebuild. The previous theme rebuilt a whole ThemeData — and every
  /// TextStyle inside it — each time the root widget rebuilt, which is on every theme or
  /// language notification.
  static final ThemeData dark = _build(Kora.dark, Brightness.dark);
  static final ThemeData light = _build(Kora.light, Brightness.light);
}
