import 'package:flutter_test/flutter_test.dart';
import 'package:kora_widget/format.dart';

/// Formatting is where both of this redesign's real bugs lived: a price rounded to whole
/// dollars looked frozen while the feed was delivering, and a change sized by its own
/// magnitude printed four decimals on a coin whose price only ever shows two. Both are cheap
/// to assert and expensive to catch by eye.
void main() {
  group('money', () {
    test('keeps cents on four-figure prices so a live tick is visible', () {
      expect(money(1848.07), r'$1,848.07');
      expect(money(62834.5), r'$62,834.50');
    });

    test('adds precision as the price shrinks', () {
      expect(money(8.08), r'$8.08');
      expect(money(0.3276), r'$0.3276');
      expect(money(0.00123456), r'$0.001235');
    });

    test('renders a missing price as a dash rather than zero', () {
      expect(money(null), '—');
    });
  });

  group('moneyDiff', () {
    test('carries the precision of the price it was measured against', () {
      // 21 cents on a $73 coin: two decimals, because that is what the price itself shows.
      expect(moneyDiff(0.21, 73.06), r'+$0.21');
      expect(moneyDiff(-22151.04, 90395.31), r'−$22,151.04');
    });

    test('keeps sub-cent precision where the price has it', () {
      expect(moneyDiff(-0.0001, 0.3276), r'−$0.0001');
    });
  });

  group('compact', () {
    test('thins the decimals as the magnitude grows', () {
      expect(compact(1259743409170), '1.26T');
      expect(compact(31069019327), '31.1B');
      expect(compact(155000000000), '155B');
      // Past ten, one decimal: 20.06M would claim a precision the figure does not have.
      expect(compact(20064440), '20.1M');
      expect(compact(9876543), '9.88M');
    });

    test('survives a missing or non-finite value', () {
      expect(compact(null), '—');
      expect(compact(double.infinity), '—');
    });
  });

  group('stamp', () {
    final t = DateTime(2026, 3, 7, 14, 32, 5);

    test('shows seconds only where a one-second candle needs them', () {
      expect(stamp(t, '15M'), '14:32:05');
      expect(stamp(t, '24H'), '14:32');
    });

    test('drops the clock on a daily candle and keeps it on an hourly one', () {
      expect(stamp(t, '1Y'), '07 Mar 2026');
      expect(stamp(t, '7D'), '07 Mar · 14:32');
    });
  });

  group('pct', () {
    test('always carries a sign so direction is readable without colour', () {
      expect(pct(2.4137), '+2.41%');
      expect(pct(-19.6841), '-19.68%');
      expect(pct(0), '+0.00%');
    });
  });
}
