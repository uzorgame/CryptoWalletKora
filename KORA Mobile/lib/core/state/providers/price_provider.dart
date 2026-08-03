import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/repositories/price_repository.dart';
import 'package:kora/core/services/crypto_price_service.dart' hide PricePoint;
import 'package:kora/core/services/websocket_service.dart';

/// Price Repository Provider
final priceRepositoryProvider = Provider<PriceRepository>((ref) {
  return PriceRepository();
});

/// WebSocket Service Provider
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService(provider: WebSocketProvider.binance);
});

/// Price State Provider for a single coin
final coinPriceProvider = FutureProvider.family<CryptoPrice?, String>((ref, coinId) async {
  final repository = ref.watch(priceRepositoryProvider);
  return await repository.getPrice(coinId);
});

/// Prices State Provider for multiple coins
final coinPricesProvider = FutureProvider.family<Map<String, CryptoPrice>, List<String>>((ref, coinIds) async {
  final repository = ref.watch(priceRepositoryProvider);
  return await repository.getPricesOptimized(coinIds);
});

/// Market Chart Provider
final marketChartProvider = FutureProvider.family<List<PricePoint>, MarketChartParams>((ref, params) async {
  final repository = ref.watch(priceRepositoryProvider);
  return await repository.getMarketChartOptimized(
    coinId: params.coinId,
    currency: params.currency,
    days: params.days,
  );
});

/// Top Coins Provider
final topCoinsProvider = FutureProvider.family<List<CoinMarket>, int>((ref, perPage) async {
  final repository = ref.watch(priceRepositoryProvider);
  return await repository.getTopCoinsOptimized(perPage: perPage);
});

/// Trending Coins Provider
final trendingCoinsProvider = FutureProvider<List<TrendingCoin>>((ref) async {
  final repository = ref.watch(priceRepositoryProvider);
  return await repository.getTrendingCoinsOptimized();
});

/// Global Market Data Provider
final globalMarketDataProvider = FutureProvider<GlobalMarketData?>((ref) async {
  final repository = ref.watch(priceRepositoryProvider);
  return await repository.getGlobalMarketData();
});

/// Coin Details Provider
final coinDetailsProvider = FutureProvider.family<CoinDetails?, String>((ref, coinId) async {
  final repository = ref.watch(priceRepositoryProvider);
  return await repository.getCoinDetailsExtended(coinId);
});

/// Search Coins Provider
final searchCoinsProvider = FutureProvider.family<List<CoinSearchResult>, String>((ref, query) async {
  final repository = ref.watch(priceRepositoryProvider);
  return await repository.searchCoinsOptimized(query);
});

/// Real-time Price Updates Provider (WebSocket)
final realTimePriceProvider = StreamProvider.family<PriceUpdate, List<String>>((ref, symbols) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  
  // Connect to WebSocket
  webSocketService.connect(symbols);
  
  // Return price updates stream
  return webSocketService.priceUpdates;
});

/// Selected Currency Provider (USD, EUR, UAH, etc.)
final selectedCurrencyProvider = StateProvider<String>((ref) => 'usd');

/// Price Refresh Notifier
/// Allows manual refresh of prices
final priceRefreshProvider = StateProvider<int>((ref) => 0);

/// Refresh prices
void refreshPrices(WidgetRef ref) {
  ref.read(priceRefreshProvider.notifier).state++;
}

/// Market Chart Parameters
class MarketChartParams {
  final String coinId;
  final String currency;
  final int days;
  
  MarketChartParams({
    required this.coinId,
    required this.currency,
    required this.days,
  });
  
  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is MarketChartParams &&
    runtimeType == other.runtimeType &&
    coinId == other.coinId &&
    currency == other.currency &&
    days == other.days;
  
  @override
  int get hashCode => coinId.hashCode ^ currency.hashCode ^ days.hashCode;
}

/// Price Notifier for managing price state
class PriceNotifier extends StateNotifier<AsyncValue<Map<String, CryptoPrice>>> {
  final PriceRepository _repository;
  
  PriceNotifier(this._repository) : super(const AsyncValue.loading());
  
  /// Load prices for multiple coins
  Future<void> loadPrices(List<String> coinIds) async {
    state = const AsyncValue.loading();
    
    try {
      final prices = await _repository.getPricesOptimized(coinIds);
      state = AsyncValue.data(prices);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  /// Refresh prices
  Future<void> refresh(List<String> coinIds) async {
    await loadPrices(coinIds);
  }
  
  /// Clear cache and reload
  Future<void> clearAndReload(List<String> coinIds) async {
    await _repository.clearCache();
    await loadPrices(coinIds);
  }
}

/// Price Notifier Provider
final priceNotifierProvider = StateNotifierProvider<PriceNotifier, AsyncValue<Map<String, CryptoPrice>>>((ref) {
  final repository = ref.watch(priceRepositoryProvider);
  return PriceNotifier(repository);
});

/// Watchlist Provider (user's favorite coins)
final watchlistProvider = StateProvider<List<String>>((ref) {
  // Default watchlist
  return [
    CoinIds.bitcoin,
    CoinIds.ethereum,
    CoinIds.solana,
    CoinIds.binancecoin,
  ];
});

/// Watchlist Prices Provider
final watchlistPricesProvider = FutureProvider<Map<String, CryptoPrice>>((ref) async {
  final watchlist = ref.watch(watchlistProvider);
  final repository = ref.watch(priceRepositoryProvider);
  
  if (watchlist.isEmpty) {
    return {};
  }
  
  return await repository.getPricesOptimized(watchlist);
});

/// Add coin to watchlist
void addToWatchlist(WidgetRef ref, String coinId) {
  final current = ref.read(watchlistProvider);
  if (!current.contains(coinId)) {
    ref.read(watchlistProvider.notifier).state = [...current, coinId];
  }
}

/// Remove coin from watchlist
void removeFromWatchlist(WidgetRef ref, String coinId) {
  final current = ref.read(watchlistProvider);
  ref.read(watchlistProvider.notifier).state = current.where((id) => id != coinId).toList();
}

/// Popular Coin IDs (re-export from repository)
class CoinIds {
  static const String bitcoin = 'bitcoin';
  static const String ethereum = 'ethereum';
  static const String solana = 'solana';
  static const String binancecoin = 'binancecoin';
  static const String tron = 'tron';
  static const String dogecoin = 'dogecoin';
  static const String usdtEth = 'tether';
  static const String usdcEth = 'usd-coin';
  static const String dai = 'dai';
}
