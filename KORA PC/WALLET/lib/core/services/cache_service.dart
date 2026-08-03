import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Cache Service for storing and retrieving data
/// Supports in-memory cache and persistent storage
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();
  
  // In-memory cache
  final Map<String, CacheEntry> _memoryCache = {};

  // Persistent storage
  SharedPreferences? _prefs;

  /// Every persisted cache key carries this prefix.
  ///
  /// The cache shares one `SharedPreferences` store with the wallet list, the passphrase
  /// settings and the theme. Without a namespace the cache's own housekeeping — which
  /// deletes anything it cannot parse as a cache entry — walks over all of them, and
  /// `wallets` is not a cache entry. A prefix is what makes "clear the cache" a statement
  /// about the cache.
  static const String _ns = 'cache.';

  static String _persistKey(String key) => '$_ns$key';

  /// The store's keys that belong to this cache, and no others.
  Iterable<String> _ownKeys() =>
      _prefs?.getKeys().where((k) => k.startsWith(_ns)) ?? const [];

  /// Initialize cache service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Get cached value
  /// Returns null if not found or expired
  T? get<T>(String key, {T Function(dynamic)? fromJson}) {
    // Check memory cache first
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      return memoryEntry.value as T;
    }
    
    // Check persistent cache
    if (_prefs != null) {
      final stored = _persistKey(key);
      final jsonString = _prefs!.getString(stored);
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString);
          final entry = CacheEntry.fromJson(json);
          
          if (!entry.isExpired) {
            // Update memory cache
            _memoryCache[key] = entry;
            
            if (fromJson != null) {
              return fromJson(entry.value);
            }
            return entry.value as T;
          } else {
            // Remove expired entry
            _prefs!.remove(stored);
          }
        } catch (e) {
          // Invalid cache entry, remove it. Safe now only because `stored` is namespaced:
          // this line used to be able to delete any key in the store that was not ours.
          _prefs!.remove(stored);
        }
      }
    }
    
    return null;
  }
  
  /// Set cached value
  /// [key] - Cache key
  /// [value] - Value to cache
  /// [duration] - Cache duration (default: 5 minutes)
  /// [persistent] - Store in persistent storage (default: false)
  Future<void> set(
    String key,
    dynamic value, {
    Duration duration = const Duration(minutes: 5),
    bool persistent = false,
  }) async {
    final entry = CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(duration),
    );
    
    // Update memory cache
    _memoryCache[key] = entry;
    
    // Update persistent cache if needed
    if (persistent) {
      _prefs ??= await SharedPreferences.getInstance(); // lazy init
      await _prefs!.setString(_persistKey(key), jsonEncode(entry.toJson()));
    }
  }
  
  /// Remove cached value
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    await _prefs?.remove(_persistKey(key));
  }
  
  /// Clear all cache.
  ///
  /// This was `_prefs.clear()`, which empties the entire store — the wallet list included.
  /// "Clear the cache" is a routine thing to call; losing the record of which wallets exist
  /// is not a routine consequence. Only namespaced keys are removed.
  Future<void> clear() async {
    _memoryCache.clear();
    for (final key in _ownKeys().toList()) {
      await _prefs!.remove(key);
    }
  }

  /// Clear expired entries.
  ///
  /// Walks only this cache's own keys. It used to walk every key in the store and delete any
  /// that failed to parse as a cache entry — and `wallets`, `theme_mode` and the settings are
  /// not cache entries, so a ten-minute timer would have emptied the app.
  Future<void> clearExpired() async {
    _memoryCache.removeWhere((key, entry) => entry.isExpired);
    if (_prefs == null) return;

    for (final key in _ownKeys().toList()) {
      final jsonString = _prefs!.getString(key);
      if (jsonString == null) continue;
      try {
        final entry = CacheEntry.fromJson(jsonDecode(jsonString));
        if (entry.isExpired) await _prefs!.remove(key);
      } catch (_) {
        // Ours by name but unreadable — a half-written entry. Dropping it is correct here
        // precisely because the namespace guarantees it is cache and nothing else.
        await _prefs!.remove(key);
      }
    }
  }
  
  /// Check if key exists and is not expired
  bool has(String key) {
    return get(key) != null;
  }
  
  /// Get cache size (memory only)
  int get size => _memoryCache.length;
}

/// Cache Entry
class CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  
  CacheEntry({
    required this.value,
    required this.expiresAt,
  });
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
  
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      value: json['value'],
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }
}

/// Price Cache Service
/// Specialized cache service for cryptocurrency prices
class PriceCacheService {
  final CacheService _cache = CacheService();
  
  /// Cache duration for prices (default: 10 minutes)
  static const Duration priceCacheDuration = Duration(minutes: 10);
  
  /// Cache duration for market data (default: 5 minutes)
  static const Duration marketDataCacheDuration = Duration(minutes: 5);
  
  /// Cache duration for coin details (default: 1 hour)
  static const Duration coinDetailsCacheDuration = Duration(hours: 1);
  
  /// Get cached price
  double? getPrice(String coinId, String currency) {
    final key = 'price_${coinId}_$currency';
    return _cache.get<double>(key);
  }
  
  /// Set cached price
  Future<void> setPrice(String coinId, String currency, double price) async {
    final key = 'price_${coinId}_$currency';
    await _cache.set(key, price, duration: priceCacheDuration);
  }
  
  /// Get cached market data
  Map<String, dynamic>? getMarketData(String coinId) {
    final key = 'market_$coinId';
    return _cache.get<Map<String, dynamic>>(key);
  }
  
  /// Set cached market data
  Future<void> setMarketData(String coinId, Map<String, dynamic> data) async {
    final key = 'market_$coinId';
    await _cache.set(key, data, duration: marketDataCacheDuration);
  }
  
  /// Get cached coin details
  Map<String, dynamic>? getCoinDetails(String coinId) {
    final key = 'details_$coinId';
    return _cache.get<Map<String, dynamic>>(key);
  }
  
  /// Set cached coin details
  Future<void> setCoinDetails(String coinId, Map<String, dynamic> details) async {
    final key = 'details_$coinId';
    await _cache.set(
      key,
      details,
      duration: coinDetailsCacheDuration,
      persistent: true,
    );
  }
  
  /// Get cached chart data
  List<dynamic>? getChartData(String coinId, String currency, int days) {
    final key = 'chart_${coinId}_${currency}_$days';
    return _cache.get<List<dynamic>>(key);
  }
  
  /// Set cached chart data
  Future<void> setChartData(
    String coinId,
    String currency,
    int days,
    List<dynamic> data,
  ) async {
    final key = 'chart_${coinId}_${currency}_$days';
    await _cache.set(key, data, duration: marketDataCacheDuration);
  }
  
  /// Clear all price cache
  Future<void> clearPriceCache() async {
    await _cache.clear();
  }
}

/// Cache Keys
class CacheKeys {
  // Price cache keys
  static String price(String coinId, String currency) => 'price_${coinId}_$currency';
  static String marketData(String coinId) => 'market_$coinId';
  static String coinDetails(String coinId) => 'details_$coinId';
  static String chartData(String coinId, String currency, int days) => 
    'chart_${coinId}_${currency}_$days';
  
  // Wallet cache keys
  static String balance(String address, String blockchain) => 
    'balance_${blockchain}_$address';
  static String transactions(String address, String blockchain) => 
    'txs_${blockchain}_$address';
  
  // Settings cache keys
  static const String selectedCurrency = 'selected_currency';
  static const String selectedLanguage = 'selected_language';
  static const String theme = 'theme';
}

/// Cache Manager
/// High-level cache management with automatic cleanup
class CacheManager {
  final CacheService _cache = CacheService();
  Timer? _cleanupTimer;
  
  /// Start automatic cleanup (every 10 minutes)
  void startAutoCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _cache.clearExpired(),
    );
  }
  
  /// Stop automatic cleanup
  void stopAutoCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
  
  /// Get cache statistics
  CacheStats getStats() {
    return CacheStats(
      size: _cache.size,
      // Add more stats as needed
    );
  }
  
  void dispose() {
    stopAutoCleanup();
  }
}

/// Cache Statistics
class CacheStats {
  final int size;
  
  CacheStats({required this.size});
  
  @override
  String toString() => 'CacheStats(size: $size)';
}
