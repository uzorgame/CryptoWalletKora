import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────── Currency enum ───────────────────────────────────

enum AppCurrency {
  usd(code: 'usd', symbol: r'$',   name: 'US Dollar',         locale: 'en_US', flag: '🇺🇸'),
  eur(code: 'eur', symbol: '€',    name: 'Euro',              locale: 'de_DE', flag: '🇪🇺'),
  gbp(code: 'gbp', symbol: '£',    name: 'British Pound',     locale: 'en_GB', flag: '🇬🇧'),
  jpy(code: 'jpy', symbol: '¥',    name: 'Japanese Yen',      locale: 'ja_JP', flag: '🇯🇵'),
  cny(code: 'cny', symbol: '¥',    name: 'Chinese Yuan',      locale: 'zh_CN', flag: '🇨🇳'),
  aud(code: 'aud', symbol: 'A\$',  name: 'Australian Dollar', locale: 'en_AU', flag: '🇦🇺'),
  cad(code: 'cad', symbol: 'CA\$', name: 'Canadian Dollar',   locale: 'en_CA', flag: '🇨🇦'),
  chf(code: 'chf', symbol: 'CHF',  name: 'Swiss Franc',       locale: 'de_CH', flag: '🇨🇭'),
  hkd(code: 'hkd', symbol: 'HK\$', name: 'Hong Kong Dollar',  locale: 'zh_HK', flag: '🇭🇰'),
  sgd(code: 'sgd', symbol: 'S\$',  name: 'Singapore Dollar',  locale: 'en_SG', flag: '🇸🇬'),
  krw(code: 'krw', symbol: '₩',    name: 'South Korean Won',  locale: 'ko_KR', flag: '🇰🇷'),
  inr(code: 'inr', symbol: '₹',    name: 'Indian Rupee',      locale: 'en_IN', flag: '��'),
  brl(code: 'brl', symbol: 'R\$',  name: 'Brazilian Real',    locale: 'pt_BR', flag: '🇧🇷'),
  mxn(code: 'mxn', symbol: 'MX\$', name: 'Mexican Peso',      locale: 'es_MX', flag: '🇲🇽'),
  zar(code: 'zar', symbol: 'R',    name: 'South African Rand',locale: 'en_ZA', flag: '🇿🇦'),
  try_(code: 'try', symbol: '₺',   name: 'Turkish Lira',      locale: 'tr_TR', flag: '🇹🇷'),
  nzd(code: 'nzd', symbol: 'NZ\$', name: 'New Zealand Dollar',locale: 'en_NZ', flag: '🇳🇿'),
  pln(code: 'pln', symbol: 'zł',   name: 'Polish Zloty',      locale: 'pl_PL', flag: '��'),
  uah(code: 'uah', symbol: '₴',    name: 'Ukrainian Hryvnia', locale: 'uk_UA', flag: '🇺🇦'),
  aed(code: 'aed', symbol: 'AED',  name: 'UAE Dirham',        locale: 'ar_AE', flag: '🇦🇪');

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.locale,
    required this.flag,
  });

  final String code, symbol, name, locale, flag;

  static AppCurrency fromCode(String code) =>
      AppCurrency.values.firstWhere((c) => c.code == code,
          orElse: () => AppCurrency.usd);
}

// ─────────────────────────── State ───────────────────────────────────────────

class CurrencyState {
  const CurrencyState({
    required this.currency,
    required this.rates,
    this.loading = false,
  });

  final AppCurrency currency;
  final Map<String, double> rates; // USD → other (1 USD = X)
  final bool loading;

  CurrencyState copyWith({AppCurrency? currency, Map<String, double>? rates, bool? loading}) =>
      CurrencyState(
        currency: currency ?? this.currency,
        rates:    rates    ?? this.rates,
        loading:  loading  ?? this.loading,
      );

  double toLocal(double usdAmount) => usdAmount * (rates[currency.code] ?? 1.0);

  /// Full-precision amount (portfolio balance, totals)
  String formatAmount(double usdAmount) => _fmt(toLocal(usdAmount), 2);

  /// Market price per coin — 4 decimals for tiny values
  String formatPrice(double usdPrice) {
    final v = toLocal(usdPrice);
    return _fmt(v, v < 1 ? 4 : 2);
  }

  /// Header total balance
  String formatTotal(double usdAmount) => _fmt(toLocal(usdAmount), 2);

  String _fmt(double value, int decimals) {
    final fmt = NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: decimals,
    );
    return fmt.format(value);
  }
}

// ─────────────────────────── Notifier ────────────────────────────────────────

class CurrencyNotifier extends StateNotifier<CurrencyState> {
  static const _prefKey = 'selected_currency';

  // Fallback exchange rates (updated when live fetch fails)
  static const Map<String, double> _fallback = {
    'usd': 1.0,
    'eur': 0.92,
    'gbp': 0.79,
    'jpy': 149.50,
    'cny': 7.24,
    'aud': 1.53,
    'cad': 1.36,
    'chf': 0.90,
    'hkd': 7.82,
    'sgd': 1.34,
    'krw': 1325.0,
    'inr': 83.10,
    'brl': 4.97,
    'mxn': 17.15,
    'zar': 18.63,
    'try': 30.50,
    'nzd': 1.63,
    'pln': 4.02,
    'uah': 41.50,
    'aed': 3.67,
  };

  CurrencyNotifier()
      : super(const CurrencyState(currency: AppCurrency.usd, rates: _fallback)) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final code  = prefs.getString(_prefKey) ?? 'usd';
    final cur   = AppCurrency.fromCode(code);
    if (kDebugMode) debugPrint('[Currency] Loaded saved currency: ${cur.code}');
    state = state.copyWith(currency: cur, loading: true);
    await _fetchRates();
  }

  Future<void> setCurrency(AppCurrency currency) async {
    if (kDebugMode) debugPrint('[Currency] Switching to ${currency.code}');
    state = state.copyWith(currency: currency);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, currency.code);
  }

  Future<void> refreshRates() => _fetchRates();

  static const _allCurrencies =
      'usd,eur,gbp,jpy,cny,aud,cad,chf,hkd,sgd,krw,inr,brl,mxn,zar,try,nzd,pln,uah,aed';

  Future<void> _fetchRates() async {
    if (kDebugMode) debugPrint('[Currency] Fetching exchange rates from CoinGecko…');
    try {
      final resp = await http.get(Uri.parse(
          '${APIConfig.coingeckoBaseUrl}/simple/price'
          '?ids=tether&vs_currencies=$_allCurrencies'),
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final data = (jsonDecode(resp.body) as Map)['tether'] as Map<String, dynamic>;
        final usdBase = (data['usd'] as num).toDouble();
        final rates = <String, double>{'usd': 1.0};
        for (final code in _allCurrencies.split(',')) {
          if (code == 'usd') continue;
          final raw = data[code];
          if (raw != null) {
            rates[code] = (raw as num).toDouble() / usdBase;
          }
        }
        if (kDebugMode) debugPrint('[Currency] Rates fetched: ${rates.length} currencies');
        if (kDebugMode) debugPrint('[Currency] Rates: $rates');
        state = state.copyWith(rates: rates, loading: false);
        return;
      }
      if (kDebugMode) debugPrint('[Currency] Rate fetch failed (${resp.statusCode}), using fallback');
    } catch (e) {
      if (kDebugMode) debugPrint('[Currency] Rate fetch error: $e — using fallback');
    }
    state = state.copyWith(rates: _fallback, loading: false);
  }
}

// ─────────────────────────── Provider ────────────────────────────────────────

final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, CurrencyState>((ref) {
  return CurrencyNotifier();
});
