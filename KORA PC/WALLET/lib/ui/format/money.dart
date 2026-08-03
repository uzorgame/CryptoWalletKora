/// Turning amounts into text.
///
/// The rules here were arrived at by watching the prototype get them wrong twice: a price
/// rounded to whole dollars looked frozen while the feed was delivering, and a change sized
/// by its own magnitude printed four decimals on a coin whose price shows two.
library;

/// Decimal places by magnitude.
///
/// Zero is special-cased: it has no magnitude to scale by, and falling through to six
/// decimals printed a fresh wallet's balance as `$0.000000`, which reads as a number that
/// failed to load rather than a balance of nothing.
int placesFor(double value) {
  final v = value.abs();
  if (v == 0) return 2;
  if (v >= 1) return 2;
  if (v >= 0.01) return 4;
  return 6;
}

String _grouped(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// A fixed-point amount with thousands separators, without the currency mark.
String amount(double value, int places) {
  final fixed = value.abs().toStringAsFixed(places);
  final dot = fixed.indexOf('.');
  final whole = dot < 0 ? fixed : fixed.substring(0, dot);
  final rest = dot < 0 ? '' : fixed.substring(dot);
  return '${_grouped(whole)}$rest';
}

/// A value in the display currency. `null` reads as a dash, never as zero — the difference
/// between "nothing" and "not known yet" matters on a balance.
String money(double? value, String symbol) {
  if (value == null || !value.isFinite) return '—';
  final sign = value < 0 ? '−' : '';
  return '$sign$symbol${amount(value, placesFor(value))}';
}

/// A change, carrying the precision of the amount it was measured against rather than its
/// own. Sized by itself, a 21-cent move on a \$73 coin printed as `0.2100`.
String moneyDelta(double delta, double reference, String symbol) {
  final places = placesFor(reference);
  return '${delta >= 0 ? '+' : '−'}$symbol${amount(delta, places)}';
}

/// Always signed, so direction survives without colour.
String percent(double? value) {
  if (value == null || !value.isFinite) return '—';
  return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%';
}

/// A coin quantity. Large holdings lose their decimals; small ones keep four.
///
/// Trailing zeros are only ever stripped after a decimal point. Stripping them from the whole
/// string turned 12,480 into 12,48 — a holding understated by a factor of ten, printed with
/// complete confidence.
String quantity(double value) {
  final v = value.abs();
  final text = amount(v, v >= 1000 ? 0 : 4);
  if (!text.contains('.')) return text;
  final trimmed = text.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}

/// Trillions down to units, for figures where three significant digits is the honest limit.
String compact(double? value) {
  if (value == null || !value.isFinite) return '—';
  final a = value.abs();
  final (unit, suffix) = switch (a) {
    >= 1e12 => (1e12, 'T'),
    >= 1e9 => (1e9, 'B'),
    >= 1e6 => (1e6, 'M'),
    >= 1e3 => (1e3, 'K'),
    _ => (1.0, ''),
  };
  final n = value / unit;
  final digits = n.abs() >= 100 ? 0 : (n.abs() >= 10 ? 1 : 2);
  return '${n.toStringAsFixed(digits)}$suffix';
}

/// An address, shortened to the two ends people actually compare.
String shortAddress(String address) =>
    address.length <= 16 ? address : '${address.substring(0, 7)}…${address.substring(address.length - 5)}';
