import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/services/storage_service.dart';
import 'package:kora/core/services/crypto_price_service.dart';
import 'package:kora/core/services/cache_service.dart';
import 'package:kora/core/services/binance_price_stream.dart';

/// Repository for fetching cryptocurrency prices
/// Integrates CryptoPriceService and CacheService for optimized data fetching
class PriceRepository {
  final CryptoPriceService _priceService;
  final PriceCacheService _cacheService;
  
  static const String _baseUrl = APIConfig.coingeckoBaseUrl;
  static const String _pricesCacheKey = 'cached_prices';
  static const Duration _cacheExpiration = Duration(minutes: 10);
  static const Duration _minFetchInterval = Duration(seconds: 30);
  static DateTime? _lastSuccessfulFetch;

  PriceRepository({
    CryptoPriceService? priceService,
    PriceCacheService? cacheService,
  })  : _priceService = priceService ?? CryptoPriceService(),
        _cacheService = cacheService ?? PriceCacheService();

  /// Get price for single cryptocurrency (using new service)
  Future<CryptoPrice?> getPrice(String coinId, {String currency = 'usd'}) async {
    // ── Primary: Binance WebSocket live prices ─────────────────────────────
    final ws = BinancePriceStream.instance;
    if (ws.isConnected && ws.hasLiveData) {
      final p = ws.latestPrices[coinId];
      if (p != null) return p;
    }

    // Check cache first
    final cachedPrice = _cacheService.getPrice(coinId, currency);
    if (cachedPrice != null) {
      return CryptoPrice(
        coinId: coinId,
        priceUsd: cachedPrice,
        change24h: 0.0,
        lastUpdated: DateTime.now(),
      );
    }
    
    try {
      final prices = await _priceService.getPrice(
        coinIds: [coinId],
        vsCurrencies: [currency],
        include24hrChange: true,
      );
      
      final coinPrice = prices[coinId];
      if (coinPrice != null) {
        // Cache the price
        await _cacheService.setPrice(coinId, currency, coinPrice.price);
        
        return CryptoPrice(
          coinId: coinId,
          priceUsd: coinPrice.price,
          change24h: coinPrice.change24h ?? 0.0,
          lastUpdated: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      // Try to get from old cache
      return await _getCachedPrice(coinId);
    }
  }

  /// Get prices for multiple cryptocurrencies
  /// @deprecated Use getPricesOptimized() instead for better performance and caching
  @Deprecated('Use getPricesOptimized() instead')
  Future<Map<String, CryptoPrice>> getPrices(List<String> coinIds) async {
    final Map<String, CryptoPrice> prices = {};

    try {
      final idsString = coinIds.join(',');
      final response = await http.get(
        Uri.parse('$_baseUrl/simple/price?ids=$idsString&vs_currencies=usd&include_24hr_change=true'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        for (final coinId in coinIds) {
          if (data[coinId] != null) {
            prices[coinId] = CryptoPrice(
              coinId: coinId,
              priceUsd: (data[coinId]['usd'] as num).toDouble(),
              change24h: (data[coinId]['usd_24h_change'] as num?)?.toDouble() ?? 0.0,
              lastUpdated: DateTime.now(),
            );
          }
        }

        // Cache prices
        await _cachePrices(prices);
      }
    } catch (e) {
      // Try to get from cache
      return await _getCachedPrices(coinIds);
    }

    return prices;
  }

  /// Get historical prices (for charts)
  Future<List<PricePoint>> getHistoricalPrices({
    required String coinId,
    required int days,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/coins/$coinId/market_chart?vs_currency=usd&days=$days'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prices = data['prices'] as List;
        
        return prices.map((point) {
          return PricePoint(
            timestamp: DateTime.fromMillisecondsSinceEpoch(point[0] as int),
            price: (point[1] as num).toDouble(),
          );
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Search coins by query
  Future<List<CoinInfo>> searchCoins(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search?query=$query'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coins = data['coins'] as List;
        
        return coins.map((coin) {
          return CoinInfo(
            id: coin['id'] as String,
            symbol: coin['symbol'] as String,
            name: coin['name'] as String,
            iconUrl: coin['large'] as String?,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get trending coins
  Future<List<String>> getTrendingCoins() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search/trending'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coins = data['coins'] as List;
        
        return coins.map((item) => item['item']['id'] as String).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get prices for multiple cryptocurrencies.
  /// Uses direct http.get (same as currency-rate fetching) so it works
  /// reliably on Android where the Dio-based path can fail silently.
  Future<Map<String, CryptoPrice>> getPricesOptimized(
    List<String> coinIds, {
    String currency = 'usd',
    bool forceRefresh = false,
  }) async {
    // ── Primary: Binance WebSocket live prices ────────────────────────────────
    var _wsPartialHit = false;
    if (!forceRefresh) {
      final ws = BinancePriceStream.instance;
      if (ws.isConnected && ws.hasLiveData) {
        final wsPrices = ws.latestPrices;
        final result = <String, CryptoPrice>{};
        for (final coinId in coinIds) {
          final p = wsPrices[coinId];
          if (p != null) result[coinId] = p;
        }
        if (result.length == coinIds.length) {
          if (kDebugMode) debugPrint('[PriceAudit] ✓ ${result.length} prices from Binance WS');
          return result;
        }
        // Partial WS hit — flag to bypass cooldown so REST fills the gaps
        if (result.isNotEmpty) {
          _wsPartialHit = true;
          if (kDebugMode) debugPrint('[PriceAudit] Partial WS: ${result.length}/${coinIds.length} — bypassing cooldown');
        }
      }
    }

    // ── Cooldown: skip network if last success was < 30s ago ─────────────────
    // (skipped when WS had partial data — we need REST to fill the gaps)
    final now = DateTime.now();
    if (!forceRefresh && !_wsPartialHit &&
        _lastSuccessfulFetch != null &&
        now.difference(_lastSuccessfulFetch!) < _minFetchInterval) {
      final secs = now.difference(_lastSuccessfulFetch!).inSeconds;
      if (kDebugMode) debugPrint('[PriceAudit] ⏳ Cooldown ${secs}s/<30s — using cache');
      return await _getCachedPrices(coinIds, ignoreExpiry: true);
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl/simple/price'
        '?ids=${coinIds.join(',')}'
        '&vs_currencies=$currency'
        '&include_24hr_change=true',
      );
      if (kDebugMode) {
        debugPrint('[PriceAudit] → CoinGecko: requesting ${coinIds.length} IDs');
      }
      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        debugPrint('[PriceAudit] ← CoinGecko HTTP ${response.statusCode}');
      }
      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        if (raw is! Map) {
          if (kDebugMode) debugPrint('[PriceAudit] ⚠ unexpected response shape — using cache');
          return await _getCachedPrices(coinIds, ignoreExpiry: true);
        }
        final data = raw as Map<String, dynamic>;
        final Map<String, CryptoPrice> result = {};
        for (final entry in data.entries) {
          final coinData = entry.value as Map<String, dynamic>?;
          if (coinData == null) continue;
          final priceVal = coinData[currency];
          if (priceVal == null) continue;
          final price  = (priceVal as num).toDouble();
          final change =
              (coinData['${currency}_24h_change'] as num?)?.toDouble() ?? 0.0;
          result[entry.key] = CryptoPrice(
            coinId: entry.key,
            priceUsd: price,
            change24h: change,
            lastUpdated: DateTime.now(),
          );
          await _cacheService.setPrice(entry.key, currency, price);
        }
        // ── Persist to SharedPreferences so 429-fallback has data ────────────
        if (result.isNotEmpty) {
          _lastSuccessfulFetch = now;
          await _cachePrices(result);
        }
        if (kDebugMode) {
          final missing = coinIds.where((id) => !result.containsKey(id)).toList();
          debugPrint('[PriceAudit] Received ${result.length}/${coinIds.length} prices');
          if (missing.isNotEmpty) {
            debugPrint('[PriceAudit] ⚠ NOT returned by CoinGecko: $missing');
          }
        }
        return result;
      }
      if (kDebugMode) {
        debugPrint('[PriceAudit] ⚠ HTTP ${response.statusCode} — trying CryptoCompare fallback');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PriceAudit] ✗ exception: $e — trying CryptoCompare fallback');
    }

    // ── CryptoCompare live fallback (1s delay, free API, tested ✅) ──────────
    if (kDebugMode) debugPrint('[PriceAudit] ⏳ 1s delay before CryptoCompare fallback...');
    await Future.delayed(const Duration(seconds: 1));
    try {
      final symbols = coinIds
          .map((id) => APIConfig.geckoToCryptoCompare[id])
          .whereType<String>()
          .toList();
      if (symbols.isNotEmpty) {
        final ccUri = Uri.parse(
          '${APIConfig.cryptoCompareUrl}?fsyms=${symbols.join(',')}&tsyms=${currency.toUpperCase()}',
        );
        if (kDebugMode) debugPrint('[PriceAudit] → CryptoCompare: $ccUri');
        final ccResp = await http.get(ccUri).timeout(const Duration(seconds: 15));
        if (kDebugMode) debugPrint('[PriceAudit] ← CryptoCompare HTTP ${ccResp.statusCode}');
        if (ccResp.statusCode == 200) {
          final raw    = jsonDecode(ccResp.body) as Map<String, dynamic>;
          final rawMap = raw['RAW'] as Map<String, dynamic>? ?? {};
          final cur    = currency.toUpperCase();
          final Map<String, CryptoPrice> ccResult = {};
          for (final geckoId in coinIds) {
            final sym = APIConfig.geckoToCryptoCompare[geckoId];
            if (sym == null) continue;
            final symData = (rawMap[sym] as Map<String, dynamic>?)?[cur] as Map<String, dynamic>?;
            if (symData == null) continue;
            final price  = (symData['PRICE']           as num?)?.toDouble();
            final change = (symData['CHANGEPCT24HOUR'] as num?)?.toDouble() ?? 0.0;
            if (price == null) continue;
            ccResult[geckoId] = CryptoPrice(
              coinId: geckoId, priceUsd: price, change24h: change, lastUpdated: now);
            await _cacheService.setPrice(geckoId, currency, price);
          }
          if (ccResult.isNotEmpty) {
            _lastSuccessfulFetch = now;
            await _cachePrices(ccResult);
            if (kDebugMode) {
              debugPrint('[PriceAudit] CryptoCompare fallback: ${ccResult.length}/${coinIds.length} prices');
            }
            return ccResult;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PriceAudit] CryptoCompare fallback error: $e');
    }

    // ── Final fallback: persistent cache (ignores expiry) ─────────────────────
    await Future.delayed(const Duration(seconds: 1));
    final cached = await _getCachedPrices(coinIds, ignoreExpiry: true);
    if (kDebugMode) {
      final stillMissing = coinIds.where((id) => !cached.containsKey(id)).toList();
      debugPrint('[PriceAudit] Cache fallback: ${cached.length}/${coinIds.length} available');
      if (stillMissing.isNotEmpty) {
        debugPrint('[PriceAudit] ✗ NO price (live or cached): $stillMissing');
      }
    }
    return cached;
  }

  /// Get detailed coin information (optimized)
  Future<CoinDetails?> getCoinDetailsExtended(String coinId) async {
    try {
      final details = await _priceService.getCoinDetails(coinId);
      return details;
    } catch (e) {
      return null;
    }
  }

  /// Get market chart (optimized with caching)
  Future<List<PricePoint>> getMarketChartOptimized({
    required String coinId,
    required String currency,
    required int days,
  }) async {
    // Check cache first
    final cached = _cacheService.getChartData(coinId, currency, days);
    if (cached != null) {
      return cached.map((p) => PricePoint(
        timestamp: DateTime.fromMillisecondsSinceEpoch(p[0] as int),
        price: (p[1] as num).toDouble(),
      )).toList();
    }
    
    try {
      final points = await _priceService.getMarketChart(
        coinId: coinId,
        vsCurrency: currency,
        days: days,
      );
      
      // Cache the data
      final cacheData = points.map((p) => [
        p.timestamp.millisecondsSinceEpoch,
        p.price,
      ]).toList();
      await _cacheService.setChartData(coinId, currency, days, cacheData);
      
      return points.map((p) => PricePoint(
        timestamp: p.timestamp,
        price: p.price,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get top coins by market cap (optimized)
  Future<List<CoinMarket>> getTopCoinsOptimized({
    String currency = 'usd',
    int perPage = 100,
  }) async {
    try {
      return await _priceService.getTopCoins(
        vsCurrency: currency,
        perPage: perPage,
      );
    } catch (e) {
      return [];
    }
  }

  /// Search coins (optimized)
  Future<List<CoinSearchResult>> searchCoinsOptimized(String query) async {
    try {
      return await _priceService.searchCoins(query);
    } catch (e) {
      return [];
    }
  }

  /// Get trending coins (optimized)
  Future<List<TrendingCoin>> getTrendingCoinsOptimized() async {
    try {
      return await _priceService.getTrendingCoins();
    } catch (e) {
      return [];
    }
  }

  /// Get global market data
  Future<GlobalMarketData?> getGlobalMarketData() async {
    try {
      return await _priceService.getGlobalMarketData();
    } catch (e) {
      return null;
    }
  }

  /// Clear price cache
  Future<void> clearCache() async {
    await _cacheService.clearPriceCache();
  }

  /// Dispose resources
  void dispose() {
    _priceService.dispose();
  }

  // Cache helpers
  Future<void> _cachePrices(Map<String, CryptoPrice> prices) async {
    // Merge with existing cache to avoid overwriting other coins' prices
    Map<String, dynamic> existingPrices = {};
    try {
      final cacheJson = await StorageService.readString(_pricesCacheKey);
      if (cacheJson != null) {
        final cacheData = jsonDecode(cacheJson);
        existingPrices = Map<String, dynamic>.from(
          (cacheData['prices'] as Map<String, dynamic>?) ?? {},
        );
      }
    } catch (_) {}

    for (final entry in prices.entries) {
      existingPrices[entry.key] = entry.value.toJson();
    }

    final cacheData = {
      'timestamp': DateTime.now().toIso8601String(),
      'prices': existingPrices,
    };
    await StorageService.writeString(_pricesCacheKey, jsonEncode(cacheData));
  }

  Future<CryptoPrice?> _getCachedPrice(String coinId) async {
    final cached = await _getCachedPrices([coinId]);
    return cached[coinId];
  }

  Future<Map<String, CryptoPrice>> _getCachedPrices(
    List<String> coinIds, {
    bool ignoreExpiry = false,
  }) async {
    final cacheJson = await StorageService.readString(_pricesCacheKey);
    if (cacheJson == null) return {};

    try {
      final cacheData = jsonDecode(cacheJson);
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);

      // Respect expiry only when NOT in fallback mode
      if (!ignoreExpiry &&
          DateTime.now().difference(timestamp) > _cacheExpiration) {
        return {};
      }

      final pricesMap = cacheData['prices'] as Map<String, dynamic>;
      final Map<String, CryptoPrice> result = {};

      for (final coinId in coinIds) {
        if (pricesMap[coinId] != null) {
          result[coinId] = CryptoPrice.fromJson(pricesMap[coinId]);
        }
      }

      return result;
    } catch (e) {
      return {};
    }
  }
}

/// Crypto Price Model
class CryptoPrice {
  final String coinId;
  final double priceUsd;
  final double change24h;
  final DateTime lastUpdated;

  CryptoPrice({
    required this.coinId,
    required this.priceUsd,
    required this.change24h,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'coinId': coinId,
    'priceUsd': priceUsd,
    'change24h': change24h,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory CryptoPrice.fromJson(Map<String, dynamic> json) => CryptoPrice(
    coinId: json['coinId'] as String,
    priceUsd: (json['priceUsd'] as num).toDouble(),
    change24h: (json['change24h'] as num).toDouble(),
    lastUpdated: DateTime.parse(json['lastUpdated'] as String),
  );
}

/// Price Point for charts
class PricePoint {
  final DateTime timestamp;
  final double price;

  PricePoint({
    required this.timestamp,
    required this.price,
  });
}

/// Coin Info for search
class CoinInfo {
  final String id;
  final String symbol;
  final String name;
  final String? iconUrl;

  CoinInfo({
    required this.id,
    required this.symbol,
    required this.name,
    this.iconUrl,
  });
}

/// Coin ID mappings (CoinGecko IDs)
class CoinIds {
  static const String bitcoin = 'bitcoin';
  static const String ethereum = 'ethereum';
  static const String solana = 'solana';
  static const String binancecoin = 'binancecoin';
  static const String tron = 'tron';
  static const String usdtEth = 'tether';
  static const String usdcEth = 'usd-coin';
  static const String dai = 'dai';
}
