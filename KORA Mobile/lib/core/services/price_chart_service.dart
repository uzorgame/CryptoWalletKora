import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/services/binance_price_stream.dart';

/// Chart period for token price history.
enum PriceChartPeriod {
  oneWeek('1W', 7),
  oneMonth('1M', 30),
  sixMonths('6M', 180),
  oneYear('1Y', 365);

  const PriceChartPeriod(this.label, this.days);
  final String label;
  final int days;
}

/// A single price data point.
class PricePoint {
  const PricePoint(this.timestamp, this.priceUsd);
  final DateTime timestamp;
  final double priceUsd;
}

/// Fetches token price history from CoinGecko /coins/{id}/market_chart.
///
/// Optimization: fetches **one request per token** with days=365 (daily
/// granularity, ~365 points), then derives all shorter periods (1W, 1M, 6M)
/// by filtering cached data by timestamp. This reduces API calls by 4×.
///
/// CoinGecko free tier: ~10-30 req/min. This service uses:
///  • 6-second delay between sequential prefetch requests
///  • Retry with exponential backoff on 429 responses
///  • 10-minute cache to reduce re-fetches
class PriceChartService {
  PriceChartService._();
  static final PriceChartService instance = PriceChartService._();

  // ── Full 1Y cache per symbol ───────────────────────────────────────────
  // One API call per token → stored here → all periods derived from this.
  final Map<String, List<PricePoint>> _fullYearCache = {};
  final Map<String, DateTime> _fullYearCacheTime = {};
  static const _cacheExpiry = Duration(minutes: 10);

  // ── Rate-limit retry config ────────────────────────────────────────────
  static const _maxRetries = 3;
  static const _retryDelays = [
    Duration(seconds: 10),
    Duration(seconds: 25),
    Duration(seconds: 45),
  ];

  /// Whether we have valid cached 1Y data for this symbol.
  bool hasCached(String symbol, PriceChartPeriod period) {
    final sym = symbol.toUpperCase();
    final time = _fullYearCacheTime[sym];
    if (time == null) return false;
    return DateTime.now().difference(time) < _cacheExpiry;
  }

  /// Get price history for a specific period by slicing the cached 1Y data.
  /// If no cache exists, fetches from CoinGecko first.
  Future<List<PricePoint>> fetchPriceHistory(
      String symbol, PriceChartPeriod period) async {
    final sym = symbol.toUpperCase();

    // Ensure we have 1Y data cached
    if (!_hasFreshCache(sym)) {
      await _fetchFullYear(sym);
    }

    final fullData = _fullYearCache[sym];
    if (fullData == null || fullData.isEmpty) return [];

    // Slice to requested period
    final cutoff = DateTime.now().subtract(Duration(days: period.days));
    return fullData.where((p) => p.timestamp.isAfter(cutoff)).toList();
  }

  /// Prefetch 1Y data for all symbols sequentially.
  /// 6-second delay between requests to stay within CoinGecko free-tier
  /// (~10 req/min). One request per token covers ALL 4 periods.
  Future<void> prefetchDefault(List<String> symbols) async {
    if (kDebugMode) {
      debugPrint('[PriceChart] Prefetching ${symbols.length} tokens '
          '(1 req each, days=365)...');
    }
    for (int i = 0; i < symbols.length; i++) {
      final sym = symbols[i].toUpperCase();
      if (_hasFreshCache(sym)) continue;
      await _fetchFullYear(sym);
      // 6s delay between requests to stay under rate limit
      if (i < symbols.length - 1) {
        await Future.delayed(const Duration(seconds: 6));
      }
    }
    if (kDebugMode) {
      debugPrint('[PriceChart] ✓ Prefetch complete');
    }
  }

  /// Clear all cached data.
  void clearCache() {
    _fullYearCache.clear();
    _fullYearCacheTime.clear();
  }

  // ── Private ────────────────────────────────────────────────────────────

  bool _hasFreshCache(String sym) {
    final time = _fullYearCacheTime[sym];
    if (time == null) return false;
    return DateTime.now().difference(time) < _cacheExpiry;
  }

  /// Fetch 365 days of data for [sym]. Tries Binance klines first,
  /// then falls back to CoinGecko with retries on 429.
  Future<void> _fetchFullYear(String sym) async {
    final geckoId = APIConfig.chartGeckoIds[sym];
    if (geckoId == null) {
      if (kDebugMode) debugPrint('[PriceChart] No ID mapping for $sym');
      return;
    }

    // ── Primary: Binance klines REST ───────────────────────────────────
    final binancePair = BinanceKlines.pairForGeckoId(geckoId);
    if (binancePair != null) {
      try {
        final resp = await http
            .get(Uri.parse(BinanceKlines.dailyUrl(binancePair)))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final list = jsonDecode(resp.body) as List<dynamic>;
          final points = <PricePoint>[];
          for (final item in list) {
            final arr = item as List<dynamic>;
            if (arr.length < 7) continue;
            final closeTime  = (arr[6] as num).toInt();   // close time ms
            final closePrice = double.tryParse(arr[4] as String) ?? 0.0;
            points.add(PricePoint(
              DateTime.fromMillisecondsSinceEpoch(closeTime),
              closePrice,
            ));
          }
          if (points.isNotEmpty) {
            _fullYearCache[sym]     = points;
            _fullYearCacheTime[sym] = DateTime.now();
            if (kDebugMode) debugPrint('[PriceChart] ✓ $sym: ${points.length} pts (Binance klines)');
            return;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[PriceChart] Binance klines error for $sym: $e');
      }
    }

    // ── Fallback: CoinGecko market_chart ──────────────────────────────
    final url = APIConfig.coingeckoMarketChart(geckoId, 365);

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final resp = await http.get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));

        if (resp.statusCode == 429) {
          if (attempt < _maxRetries) {
            final delay = _retryDelays[attempt];
            if (kDebugMode) {
              debugPrint('[PriceChart] 429 for $sym, '
                  'retry ${attempt + 1}/$_maxRetries in ${delay.inSeconds}s');
            }
            await Future.delayed(delay);
            continue;
          }
          if (kDebugMode) {
            debugPrint('[PriceChart] 429 for $sym, all retries exhausted');
          }
          return;
        }

        if (resp.statusCode != 200) {
          if (kDebugMode) {
            debugPrint('[PriceChart] HTTP ${resp.statusCode} for $sym');
          }
          return;
        }

        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final prices = (body['prices'] as List<dynamic>?) ?? [];

        final points = <PricePoint>[];
        for (final item in prices) {
          final arr = item as List<dynamic>;
          if (arr.length < 2) continue;
          final timeMs = (arr[0] as num).toInt();
          final price = (arr[1] as num).toDouble();
          points.add(PricePoint(
            DateTime.fromMillisecondsSinceEpoch(timeMs),
            price,
          ));
        }

        _fullYearCache[sym] = points;
        _fullYearCacheTime[sym] = DateTime.now();

        if (kDebugMode) {
          debugPrint('[PriceChart] ✓ $sym: ${points.length} points (365d)');
        }
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('[PriceChart] ✗ $sym error: $e');
        return;
      }
    }
  }
}
