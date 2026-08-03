import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kora_windows/core/config/api_config.dart';
import 'package:kora_windows/core/services/rate_limiter.dart';

/// Crypto Price Service using CoinGecko API
/// Provides cryptocurrency prices, market data, and historical charts
class CryptoPriceService {
  final Dio _dio;
  final CoinGeckoRateLimiter _rateLimiter;
  
  // CoinGecko API (безкоштовно)
  static const String baseUrl = APIConfig.coingeckoBaseUrl;
  
  CryptoPriceService({int? callsPerMinute}) 
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        )),
        _rateLimiter = CoinGeckoRateLimiter(
          callsPerMinute: callsPerMinute ?? 45,
        );
  
  /// Get simple price for multiple coins
  /// [coinIds] - List of coin IDs (e.g., ['bitcoin', 'ethereum'])
  /// [vsCurrencies] - List of currencies (e.g., ['usd', 'eur'])
  /// [includeMarketCap] - Include market cap
  /// [include24hrVol] - Include 24h volume
  /// [include24hrChange] - Include 24h change percentage
  Future<Map<String, CoinPrice>> getPrice({
    required List<String> coinIds,
    List<String> vsCurrencies = const ['usd'],
    bool includeMarketCap = false,
    bool include24hrVol = false,
    bool include24hrChange = true,
  }) async {
    return await _rateLimiter.execute(() async {
      try {
        final response = await _dio.get(
          '/simple/price',
          queryParameters: {
            'ids': coinIds.join(','),
            'vs_currencies': vsCurrencies.join(','),
            'include_market_cap': includeMarketCap,
            'include_24hr_vol': include24hrVol,
            'include_24hr_change': include24hrChange,
          },
        );
        final Map<String, CoinPrice> prices = {};
        for (final entry in (response.data as Map<String, dynamic>).entries) {
          prices[entry.key] = CoinPrice.fromJson(
            entry.key,
            entry.value as Map<String, dynamic>,
            vsCurrencies.first,
          );
        }
        return prices;
      } on DioException catch (e) {
        throw CryptoPriceException(_handleDioError(e));
      }
    });
  }
  
  /// Get detailed coin information
  Future<CoinDetails?> getCoinDetails(String coinId) async {
    return await _rateLimiter.execute(() async {
      try {
        final response = await _dio.get('/coins/$coinId');
        return CoinDetails.fromJson(response.data as Map<String, dynamic>);
      } on DioException catch (e) {
        throw CryptoPriceException(_handleDioError(e));
      }
    });
  }
  
  /// Get market chart data (price history)
  /// [days] - Number of days (1, 7, 14, 30, 90, 180, 365, max)
  Future<List<PricePoint>> getMarketChart({
    required String coinId,
    required String vsCurrency,
    required int days,
  }) async {
    return await _rateLimiter.execute(() async {
      try {
        final response = await _dio.get(
          '/coins/$coinId/market_chart',
          queryParameters: {
            'vs_currency': vsCurrency.toLowerCase(),
            'days': days,
          },
        );
        final prices = response.data['prices'] as List;
        return prices.map((p) {
          final point = p as List;
          return PricePoint(
            timestamp: DateTime.fromMillisecondsSinceEpoch(point[0] as int),
            price: (point[1] as num).toDouble(),
          );
        }).toList();
      } on DioException catch (e) {
        throw CryptoPriceException(_handleDioError(e));
      }
    });
  }
  
  /// Get market chart range (custom date range)
  Future<List<PricePoint>> getMarketChartRange({
    required String coinId,
    required String vsCurrency,
    required DateTime from,
    required DateTime to,
  }) async {
    return await _rateLimiter.execute(() async {
      try {
        final response = await _dio.get(
          '/coins/$coinId/market_chart/range',
          queryParameters: {
            'vs_currency': vsCurrency.toLowerCase(),
            'from': from.millisecondsSinceEpoch ~/ 1000,
            'to': to.millisecondsSinceEpoch ~/ 1000,
          },
        );
        final prices = response.data['prices'] as List;
        return prices.map((p) {
          final point = p as List;
          return PricePoint(
            timestamp: DateTime.fromMillisecondsSinceEpoch(point[0] as int),
            price: (point[1] as num).toDouble(),
          );
        }).toList();
      } on DioException catch (e) {
        throw CryptoPriceException(_handleDioError(e));
      }
    });
  }
  
  /// Get top coins by market cap
  Future<List<CoinMarket>> getTopCoins({
    String vsCurrency = 'usd',
    int perPage = 100,
    int page = 1,
    String order = 'market_cap_desc',
  }) async {
    return await _rateLimiter.execute(() async {
      try {
        final response = await _dio.get(
          '/coins/markets',
          queryParameters: {
            'vs_currency': vsCurrency.toLowerCase(),
            'order': order,
            'per_page': perPage,
            'page': page,
            'sparkline': false,
          },
        );
        final List<dynamic> data = response.data as List;
        return data.map((coin) => CoinMarket.fromJson(coin as Map<String, dynamic>)).toList();
      } on DioException catch (e) {
        throw CryptoPriceException(_handleDioError(e));
      }
    });
  }
  
  /// Search coins by query
  Future<List<CoinSearchResult>> searchCoins(String query) async {
    return await _rateLimiter.execute(() async {
      try {
        final response = await _dio.get('/search', queryParameters: {'query': query});
        final coins = response.data['coins'] as List;
        return coins.map((coin) => CoinSearchResult.fromJson(coin as Map<String, dynamic>)).toList();
      } on DioException catch (e) {
        throw CryptoPriceException(_handleDioError(e));
      }
    });
  }
  
  /// Get trending coins
  Future<List<TrendingCoin>> getTrendingCoins() async {
    return await _rateLimiter.execute(() async {
      try {
        final response = await _dio.get('/search/trending');
        final coins = response.data['coins'] as List;
        return coins.map((item) {
          final m = item as Map<String, dynamic>;
          return TrendingCoin.fromJson(m['item'] as Map<String, dynamic>);
        }).toList();
      } on DioException catch (e) {
        throw CryptoPriceException(_handleDioError(e));
      }
    });
  }
  
  /// Get global market data
  Future<GlobalMarketData?> getGlobalMarketData() async {
    return await _rateLimiter.execute(() async {
      try {
        final response = await _dio.get('/global');
        return GlobalMarketData.fromJson(response.data['data'] as Map<String, dynamic>);
      } on DioException catch (e) {
        throw CryptoPriceException(_handleDioError(e));
      }
    });
  }
  
  /// Get supported currencies
  Future<List<String>> getSupportedCurrencies() async {
    return await _rateLimiter.execute(() async {
      try {
        final response = await _dio.get('/simple/supported_vs_currencies');
        return List<String>.from(response.data as List);
      } on DioException catch (e) {
        throw CryptoPriceException(_handleDioError(e));
      }
    });
  }
  
  String _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Receive timeout';
    } else if (e.type == DioExceptionType.badResponse) {
      return 'Server error: ${e.response?.statusCode}';
    } else if (e.type == DioExceptionType.cancel) {
      return 'Request cancelled';
    } else {
      return 'Network error: ${e.message}';
    }
  }
  
  void dispose() {
    _dio.close();
  }
}

/// Coin Price Model
class CoinPrice {
  final String coinId;
  final String currency;
  final double price;
  final double? change24h;
  final double? marketCap;
  final double? volume24h;
  
  CoinPrice({
    required this.coinId,
    required this.currency,
    required this.price,
    this.change24h,
    this.marketCap,
    this.volume24h,
  });
  
  factory CoinPrice.fromJson(String coinId, Map<String, dynamic> json, String currency) {
    return CoinPrice(
      coinId: coinId,
      currency: currency,
      price: (json[currency] as num).toDouble(),
      change24h: json['${currency}_24h_change'] != null 
        ? (json['${currency}_24h_change'] as num).toDouble()
        : null,
      marketCap: json['${currency}_market_cap'] != null
        ? (json['${currency}_market_cap'] as num).toDouble()
        : null,
      volume24h: json['${currency}_24h_vol'] != null
        ? (json['${currency}_24h_vol'] as num).toDouble()
        : null,
    );
  }
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

/// Coin Details Model
class CoinDetails {
  final String id;
  final String symbol;
  final String name;
  final String? description;
  final String? imageUrl;
  final int? marketCapRank;
  final double? currentPrice;
  final double? marketCap;
  final double? totalVolume;
  final double? priceChange24h;
  final double? priceChangePercentage24h;
  
  CoinDetails({
    required this.id,
    required this.symbol,
    required this.name,
    this.description,
    this.imageUrl,
    this.marketCapRank,
    this.currentPrice,
    this.marketCap,
    this.totalVolume,
    this.priceChange24h,
    this.priceChangePercentage24h,
  });
  
  factory CoinDetails.fromJson(Map<String, dynamic> json) {
    return CoinDetails(
      id: json['id'],
      symbol: json['symbol'],
      name: json['name'],
      description: json['description']?['en'],
      imageUrl: json['image']?['large'],
      marketCapRank: json['market_cap_rank'],
      currentPrice: json['market_data']?['current_price']?['usd']?.toDouble(),
      marketCap: json['market_data']?['market_cap']?['usd']?.toDouble(),
      totalVolume: json['market_data']?['total_volume']?['usd']?.toDouble(),
      priceChange24h: json['market_data']?['price_change_24h']?.toDouble(),
      priceChangePercentage24h: json['market_data']?['price_change_percentage_24h']?.toDouble(),
    );
  }
}

/// Coin Market Model
class CoinMarket {
  final String id;
  final String symbol;
  final String name;
  final String? image;
  final double currentPrice;
  final int marketCapRank;
  final double? marketCap;
  final double? totalVolume;
  final double? priceChangePercentage24h;
  
  CoinMarket({
    required this.id,
    required this.symbol,
    required this.name,
    this.image,
    required this.currentPrice,
    required this.marketCapRank,
    this.marketCap,
    this.totalVolume,
    this.priceChangePercentage24h,
  });
  
  factory CoinMarket.fromJson(Map<String, dynamic> json) {
    return CoinMarket(
      id: json['id'],
      symbol: json['symbol'],
      name: json['name'],
      image: json['image'],
      currentPrice: (json['current_price'] as num).toDouble(),
      marketCapRank: json['market_cap_rank'] ?? 0,
      marketCap: json['market_cap']?.toDouble(),
      totalVolume: json['total_volume']?.toDouble(),
      priceChangePercentage24h: json['price_change_percentage_24h']?.toDouble(),
    );
  }
}

/// Coin Search Result
class CoinSearchResult {
  final String id;
  final String name;
  final String symbol;
  final int? marketCapRank;
  final String? thumb;
  
  CoinSearchResult({
    required this.id,
    required this.name,
    required this.symbol,
    this.marketCapRank,
    this.thumb,
  });
  
  factory CoinSearchResult.fromJson(Map<String, dynamic> json) {
    return CoinSearchResult(
      id: json['id'],
      name: json['name'],
      symbol: json['symbol'],
      marketCapRank: json['market_cap_rank'],
      thumb: json['thumb'],
    );
  }
}

/// Trending Coin
class TrendingCoin {
  final String id;
  final String name;
  final String symbol;
  final int marketCapRank;
  final String? thumb;
  
  TrendingCoin({
    required this.id,
    required this.name,
    required this.symbol,
    required this.marketCapRank,
    this.thumb,
  });
  
  factory TrendingCoin.fromJson(Map<String, dynamic> json) {
    return TrendingCoin(
      id: json['id'],
      name: json['name'],
      symbol: json['symbol'],
      marketCapRank: json['market_cap_rank'] ?? 0,
      thumb: json['thumb'],
    );
  }
}

/// Global Market Data
class GlobalMarketData {
  final int activeCryptocurrencies;
  final double totalMarketCap;
  final double totalVolume;
  final double marketCapPercentage;
  
  GlobalMarketData({
    required this.activeCryptocurrencies,
    required this.totalMarketCap,
    required this.totalVolume,
    required this.marketCapPercentage,
  });
  
  factory GlobalMarketData.fromJson(Map<String, dynamic> json) {
    return GlobalMarketData(
      activeCryptocurrencies: json['active_cryptocurrencies'] ?? 0,
      totalMarketCap: (json['total_market_cap']?['usd'] as num?)?.toDouble() ?? 0.0,
      totalVolume: (json['total_volume']?['usd'] as num?)?.toDouble() ?? 0.0,
      marketCapPercentage: (json['market_cap_percentage']?['btc'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Crypto Price Exception
class CryptoPriceException implements Exception {
  final String message;
  CryptoPriceException(this.message);
  
  @override
  String toString() => 'CryptoPriceException: $message';
}

/// Popular Coin IDs
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
