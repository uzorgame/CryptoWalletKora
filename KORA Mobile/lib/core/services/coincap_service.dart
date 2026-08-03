import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora/core/config/api_config.dart';

/// Chart period for token price history.
enum PriceChartPeriod {
  oneWeek('1W', 7, 'h2'),
  oneMonth('1M', 30, 'h12'),
  threeMonths('3M', 90, 'd1'),
  sixMonths('6M', 180, 'd1'),
  oneYear('1Y', 365, 'd1'),
  fiveYears('5Y', 1825, 'd1');

  const PriceChartPeriod(this.label, this.days, this.interval);
  final String label;
  final int days;
  final String interval; // CoinCap interval param
}

/// A single price data point.
class PricePoint {
  const PricePoint(this.timestamp, this.priceUsd);
  final DateTime timestamp;
  final double priceUsd;
}

/// Service for fetching token price history from CoinCap API.
/// Used exclusively for price charts — separate from CoinGecko (which handles
/// current prices and 24h change).
class CoinCapService {
  CoinCapService._();
  static final CoinCapService instance = CoinCapService._();

  // ── In-memory cache ──────────────────────────────────────────────────────
  // Key: "${symbol}_${period.name}"
  final Map<String, List<PricePoint>> _cache = {};
  final Map<String, DateTime> _cacheTime = {};
  static const _cacheExpiry = Duration(minutes: 5);

  /// Whether we have valid cached data for this symbol + period.
  bool hasCached(String symbol, PriceChartPeriod period) {
    final key = '${symbol}_${period.name}';
    final time = _cacheTime[key];
    if (time == null) return false;
    return DateTime.now().difference(time) < _cacheExpiry;
  }

  /// Get cached data (may be null or stale).
  List<PricePoint>? getCached(String symbol, PriceChartPeriod period) {
    final key = '${symbol}_${period.name}';
    return _cache[key];
  }

  /// Fetch price history for a single token + period.
  /// Returns cached data if still fresh; otherwise fetches from API.
  Future<List<PricePoint>> fetchPriceHistory(
      String symbol, PriceChartPeriod period) async {
    final key = '${symbol}_${period.name}';

    // Return cache if fresh
    if (hasCached(symbol, period)) {
      return _cache[key]!;
    }

    final coincapId = APIConfig.coincapIds[symbol.toUpperCase()];
    if (coincapId == null) {
      if (kDebugMode) debugPrint('[CoinCap] No ID mapping for $symbol');
      return _cache[key] ?? [];
    }

    final now = DateTime.now();
    final start = now.subtract(Duration(days: period.days));
    final url = APIConfig.coincapHistory(
        coincapId, period.interval,
        start.millisecondsSinceEpoch, now.millisecondsSinceEpoch);

    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${APIConfig.coincapApiKey}',
          'Accept-Encoding': 'gzip',
        },
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('[CoinCap] HTTP ${resp.statusCode} for $symbol ($coincapId)');
        }
        return _cache[key] ?? [];
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (body['data'] as List<dynamic>?) ?? [];

      final points = <PricePoint>[];
      for (final item in data) {
        final m = item as Map<String, dynamic>;
        final priceStr = m['priceUsd'] as String?;
        final timeMs = m['time'] as int?;
        if (priceStr == null || timeMs == null) continue;
        final price = double.tryParse(priceStr);
        if (price == null) continue;
        points.add(PricePoint(
          DateTime.fromMillisecondsSinceEpoch(timeMs),
          price,
        ));
      }

      _cache[key] = points;
      _cacheTime[key] = DateTime.now();

      if (kDebugMode) {
        debugPrint('[CoinCap] ✓ $symbol (${period.label}): ${points.length} points');
      }
      return points;
    } catch (e) {
      if (kDebugMode) debugPrint('[CoinCap] ✗ $symbol error: $e');
      return _cache[key] ?? [];
    }
  }

  /// Prefetch price histories for all given symbols sequentially.
  /// Requests are sent one after another (no parallel) to avoid rate limiting.
  /// [period] — which period to prefetch.
  /// [symbols] — list of token symbols (e.g. ['BTC', 'ETH', 'SOL']).
  Future<void> prefetchAll(List<String> symbols, PriceChartPeriod period) async {
    if (kDebugMode) {
      debugPrint('[CoinCap] Prefetching ${symbols.length} tokens for ${period.label}...');
    }
    for (final symbol in symbols) {
      if (hasCached(symbol, period)) continue;
      await fetchPriceHistory(symbol, period);
    }
    if (kDebugMode) {
      debugPrint('[CoinCap] ✓ Prefetch complete for ${period.label}');
    }
  }

  /// Prefetch ALL periods for all given symbols sequentially.
  Future<void> prefetchAllPeriods(List<String> symbols) async {
    if (kDebugMode) {
      debugPrint('[CoinCap] Starting full prefetch for ${symbols.length} tokens, '
          '${PriceChartPeriod.values.length} periods...');
    }
    for (final period in PriceChartPeriod.values) {
      for (final symbol in symbols) {
        if (hasCached(symbol, period)) continue;
        await fetchPriceHistory(symbol, period);
      }
    }
    if (kDebugMode) {
      debugPrint('[CoinCap] ✓ Full prefetch complete');
    }
  }

  /// Clear all cached data.
  void clearCache() {
    _cache.clear();
    _cacheTime.clear();
  }
}
