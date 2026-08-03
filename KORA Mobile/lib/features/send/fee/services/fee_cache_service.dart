import 'package:kora/core/services/storage_service.dart';
import '../models/fee_estimate.dart';
import '../models/fee_cache_entry.dart';

/// Fee Cache Service
/// Manages 24-hour caching of fee estimates
class FeeCacheService {
  static const String _cacheKeyPrefix = 'fee_cache_';

  /// Get cached fee estimate for a blockchain
  /// Returns null if cache is expired or doesn't exist
  static Future<FeeEstimate?> getCachedFee({
    required String blockchain,
    FeeSpeed? speed,
  }) async {
    final cacheKey = _buildCacheKey(blockchain, speed);
    final cachedJson = await StorageService.readJson(cacheKey);
    
    if (cachedJson == null) return null;

    try {
      final cacheEntry = FeeCacheEntry.fromJson(cachedJson);
      
      // Check if cache is still valid
      if (!cacheEntry.isValid) {
        // Cache expired, remove it
        await StorageService.delete(cacheKey);
        return null;
      }

      return cacheEntry.feeEstimate;
    } catch (e) {
      // Invalid cache data, remove it
      await StorageService.delete(cacheKey);
      return null;
    }
  }

  /// Cache a fee estimate
  static Future<void> cacheFee(FeeEstimate feeEstimate) async {
    final cacheKey = _buildCacheKey(feeEstimate.blockchain, feeEstimate.speed);
    final cacheEntry = FeeCacheEntry.create(feeEstimate);
    
    await StorageService.writeJson(cacheKey, cacheEntry.toJson());
  }

  /// Clear cache for a specific blockchain
  static Future<void> clearCache({
    required String blockchain,
    FeeSpeed? speed,
  }) async {
    final cacheKey = _buildCacheKey(blockchain, speed);
    await StorageService.delete(cacheKey);
  }

  /// Clear all fee caches
  static Future<void> clearAllCaches() async {
    // Note: SharedPreferences doesn't provide getAllKeys in our StorageService
    // Individual caches can be cleared using clearCache() method
    // This is a placeholder for future implementation if needed
  }

  /// Check if cache exists and is valid
  static Future<bool> isCacheValid({
    required String blockchain,
    FeeSpeed? speed,
  }) async {
    final cachedFee = await getCachedFee(blockchain: blockchain, speed: speed);
    return cachedFee != null;
  }

  /// Get time until cache expires
  static Future<Duration?> getTimeUntilExpiry({
    required String blockchain,
    FeeSpeed? speed,
  }) async {
    final cacheKey = _buildCacheKey(blockchain, speed);
    final cachedJson = await StorageService.readJson(cacheKey);
    
    if (cachedJson == null) return null;

    try {
      final cacheEntry = FeeCacheEntry.fromJson(cachedJson);
      return cacheEntry.timeUntilExpiry;
    } catch (e) {
      return null;
    }
  }

  /// Build cache key for blockchain and speed
  static String _buildCacheKey(String blockchain, FeeSpeed? speed) {
    if (speed == null) {
      return '$_cacheKeyPrefix$blockchain';
    }
    return '$_cacheKeyPrefix${blockchain}_${speed.name}';
  }
}
