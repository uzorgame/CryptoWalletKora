import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';

/// The KORA design language, as approved in the side-by-side prototype and already shipped on
/// the Windows wallet: a monochrome surface, hairline borders, square corners, tracked
/// monospace labels and tabular display numerals. Nothing here is decorative preference —
/// every token matches `KORA PC/WALLET/lib/core/theme/kora_design.dart` so the two products
/// read as one.

// ─── Type families (bundled in assets/fonts, same files as the desktop) ─────────────────
const String kDisplay = 'Space Grotesk';
const String kMono = 'JetBrains Mono';
const String kSans = 'Inter';

// ─── Motion ─────────────────────────────────────────────────────────────────────────────
/// The desktop's ease: fast out, long settle. One curve for everything keeps the two
/// platforms moving the same way.
const Curve kEase = Cubic(0.16, 1, 0.3, 1);
const Duration kControl = Duration(milliseconds: 180);

// ─── Text styles ────────────────────────────────────────────────────────────────────────

/// A tracked uppercase monospace label — section headings, field labels, buttons.
///
/// [tracking] is a fraction of the size, exactly as on the desktop, so the same value reads
/// the same at any scale. Callers pass text already uppercased where the design wants it;
/// the style does not force case because addresses and hashes go through here too.
TextStyle kLabel(Color color, {double size = 10, double tracking = 0.14, FontWeight weight = FontWeight.w500}) =>
    TextStyle(
      fontFamily: kMono,
      fontFamilyFallback: const [kSans],
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: 1.2,
      letterSpacing: size * tracking,
    );

/// Display numerals — balances, amounts. Tabular, slightly tightened, never bold beyond 700.
TextStyle kNum(Color color, {double size = 40, FontWeight weight = FontWeight.w500}) =>
    TextStyle(
      fontFamily: kDisplay,
      fontFamilyFallback: const [kSans],
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: 1.1,
      letterSpacing: -0.02 * size,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Plain monospace for figures inside rows — prices, quantities, hashes.
TextStyle kMonoText(Color color, {double size = 10, FontWeight weight = FontWeight.w400}) =>
    TextStyle(
      fontFamily: kMono,
      fontFamilyFallback: const [kSans],
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: 1.35,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Body prose — onboarding copy, warnings in sentence case.
TextStyle kBody(Color color, {double size = 13, FontWeight weight = FontWeight.w400}) =>
    TextStyle(
      fontFamily: kSans,
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: 1.55,
    );

// ─── Hairlines ──────────────────────────────────────────────────────────────────────────

/// The 1px border every surface carries. A helper so nobody re-invents the width.
Border kHairline() => Border.all(color: AppColors.border, width: 1);

BorderSide kHairlineSide() => BorderSide(color: AppColors.border, width: 1);
