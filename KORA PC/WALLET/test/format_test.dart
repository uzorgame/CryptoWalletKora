import 'package:flutter_test/flutter_test.dart';
import 'package:kora_windows/ui/format/money.dart';
import 'package:kora_windows/ui/format/moment.dart' as moment;

/// Formatting is where a wallet lies most easily: a balance that reads as loading, a change
/// that claims precision it does not have, a zero that looks like a failure. These are cheap
/// to assert and expensive to notice by eye.
void main() {
  group('money', () {
    test('a zero balance reads as nothing, not as a failed load', () {
      // Falling through to six decimals printed a fresh wallet as "$0.000000".
      expect(money(0, r'$'), r'$0.00');
    });

    test('keeps cents above a unit so a live tick is visible', () {
      expect(money(1848.07, r'$'), r'$1,848.07');
      expect(money(62834.5, r'$'), r'$62,834.50');
    });

    test('adds precision as the amount shrinks', () {
      expect(money(0.3276, r'$'), r'$0.3276');
      expect(money(0.00123456, r'$'), r'$0.001235');
    });

    test('an unknown amount is a dash, never a zero', () {
      expect(money(null, r'$'), '—');
      expect(money(double.nan, r'$'), '—');
    });

    test('carries the currency mark it is given', () {
      expect(money(1234.5, '₴'), '₴1,234.50');
      expect(money(1234.5, '€'), '€1,234.50');
    });

    test('negative amounts keep their sign', () {
      expect(money(-42.5, r'$'), r'−$42.50');
    });
  });

  group('moneyDelta', () {
    test('takes the precision of the amount it was measured against', () {
      expect(moneyDelta(0.21, 73.06, r'$'), r'+$0.21');
      expect(moneyDelta(-22151.04, 90395.31, r'$'), r'−$22,151.04');
    });

    test('keeps sub-cent precision where the reference has it', () {
      expect(moneyDelta(-0.0001, 0.3276, r'$'), r'−$0.0001');
    });
  });

  group('compact', () {
    test('thins the decimals as the magnitude grows', () {
      expect(compact(1259743409170), '1.26T');
      expect(compact(31069019327), '31.1B');
      expect(compact(155000000000), '155B');
      expect(compact(9876543), '9.88M');
    });

    test('survives a missing or non-finite value', () {
      expect(compact(null), '—');
      expect(compact(double.infinity), '—');
    });
  });

  group('percent', () {
    test('always carries a sign so direction survives without colour', () {
      expect(percent(2.4137), '+2.41%');
      expect(percent(-19.6841), '-19.68%');
      expect(percent(0), '+0.00%');
      expect(percent(null), '—');
    });
  });

  group('quantity', () {
    test('drops trailing zeros and thins decimals on large holdings', () {
      expect(quantity(0.42180000), '0.4218');
      expect(quantity(12480), '12,480');
      expect(quantity(1.5), '1.5');
    });
  });

  group('shortAddress', () {
    test('keeps the two ends people actually compare', () {
      expect(shortAddress('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'), 'bc1qar0…f5mdq');
    });

    test('leaves a short address alone', () {
      expect(shortAddress('abc123'), 'abc123');
    });
  });

  group('moment', () {
    final t = DateTime(2026, 3, 7, 14, 32, 5);

    test('writes a day, a day with a clock, and a clock', () {
      expect(moment.day(t), '07 Mar 2026');
      expect(moment.dayAndTime(t), '07 Mar · 14:32');
      expect(moment.time(t), '14:32');
      expect(moment.timeWithSeconds(t), '14:32:05');
    });

    test('goes absolute once relative stops being useful', () {
      final now = DateTime(2026, 3, 7, 15, 0);
      expect(moment.ago(DateTime(2026, 3, 7, 14, 45), now: now), '15 min ago');
      expect(moment.ago(DateTime(2026, 3, 7, 9, 0), now: now), '6 h ago');
      expect(moment.ago(DateTime(2026, 3, 6, 14, 0), now: now), 'Yesterday');
      // Forty-three days ago tells nobody anything a date would not tell them better.
      expect(moment.ago(DateTime(2026, 1, 23, 14, 0), now: now), '23 Jan 2026');
    });
  });
}
