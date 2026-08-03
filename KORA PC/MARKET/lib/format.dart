/// Number and time formatting for KORA Market.
///
/// The rules here are the ones the prototype was corrected into: precision follows the
/// magnitude of the price, and a change carries the precision of the price it was measured
/// against rather than its own.
library;

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _pad(int v) => v.toString().padLeft(2, '0');

String _group(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Decimal places by magnitude. Rounding four-figure prices to whole dollars hid the ticking
/// entirely — ETH moves a few cents at a time, so at zero decimals the number sat frozen
/// while the feed was in fact delivering.
int places(double v) {
  final a = v.abs();
  if (a >= 1) return 2;
  if (a >= 0.01) return 4;
  return 6;
}

String _dollars(double v, int p) {
  final fixed = v.toStringAsFixed(p);
  final dot = fixed.indexOf('.');
  final whole = dot < 0 ? fixed : fixed.substring(0, dot);
  final rest = dot < 0 ? '' : fixed.substring(dot);
  final negative = whole.startsWith('-');
  final digits = negative ? whole.substring(1) : whole;
  return '${negative ? '-' : ''}\$${_group(digits)}$rest';
}

String money(double? v) => v == null ? '—' : _dollars(v, places(v));

/// A change carries the precision of the price it was measured against, not its own. Sizing
/// by the difference printed a 21-cent move on a \$73 coin as "0.2100" — four decimals of
/// authority on a number whose own price only ever shows two.
String moneyDiff(double diff, double reference) =>
    '${diff >= 0 ? '+' : '−'}${_dollars(diff.abs(), places(reference))}';

String pct(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';

/// Trillions down to units, with the decimals thinning out as the number grows.
String compact(double? v) {
  if (v == null || !v.isFinite) return '—';
  final a = v.abs();
  final (unit, suffix) = switch (a) {
    >= 1e12 => (1e12, 'T'),
    >= 1e9 => (1e9, 'B'),
    >= 1e6 => (1e6, 'M'),
    >= 1e3 => (1e3, 'K'),
    _ => (1.0, ''),
  };
  final n = v / unit;
  final digits = n.abs() >= 100 ? 0 : (n.abs() >= 10 ? 1 : 2);
  return '${n.toStringAsFixed(digits)}$suffix';
}

/// How a moment is written depends on how much of it is on screen: a one-second candle needs
/// seconds to be identifiable, while a daily candle reading "14:32" would be noise.
String stamp(DateTime t, String range) => switch (range) {
      '15M' => '${_pad(t.hour)}:${_pad(t.minute)}:${_pad(t.second)}',
      '1H' || '24H' => '${_pad(t.hour)}:${_pad(t.minute)}',
      '1Y' => '${_pad(t.day)} ${_months[t.month - 1]} ${t.year}',
      _ => '${_pad(t.day)} ${_months[t.month - 1]} · ${_pad(t.hour)}:${_pad(t.minute)}',
    };

String clockOf(DateTime t) => '${_pad(t.hour)}:${_pad(t.minute)}:${_pad(t.second)}';
