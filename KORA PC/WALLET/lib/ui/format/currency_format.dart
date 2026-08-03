import '../../core/state/providers/currency_provider.dart';
import 'money.dart';

/// Formatting on top of the app's own currency state.
///
/// An extension, not a type. `CurrencyState` already holds the chosen currency and the rates,
/// and already knows how to convert — it only lacked a way to render the result. Wrapping it
/// in a second object would have been the third duplicate of something that already existed.
extension CurrencyFormat on CurrencyState {
  String get symbol => currency.symbol;

  /// A USD amount in the display currency. Null reads as a dash, never as zero: the
  /// difference between "nothing" and "not known yet" matters on a balance.
  String format(double? usd) => money(usd == null ? null : toLocal(usd), currency.symbol);

  double? convert(double? usd) => usd == null ? null : toLocal(usd);

  /// A change, carrying the precision of the amount it was measured against.
  String formatDelta(double usdDelta, double usdReference) =>
      moneyDelta(toLocal(usdDelta), toLocal(usdReference), currency.symbol);
}
