import 'package:kora_windows/core/services/storage_service.dart';
import '../models/fee_estimate.dart';
import '../models/fee_cache_entry.dart';

class FeeCacheService {
  static const String _cacheKeyPrefix = 'fee_cache_';

  /// [isToken] separates a token transfer's estimate from the native coin's.
  ///
  /// It belongs in the key because the two are different numbers for the same chain and
  /// speed: a bare ETH transfer costs 21,000 gas, an ERC-20 transfer roughly three times
  /// that. Without it both wrote to `fee_cache_ethereum_normal` and each overwrote the other,
  /// so whichever the user asked for second was quoted the first one's price — and on a page
  /// whose next button signs a transaction.
  static Future<FeeEstimate?> getCachedFee({
    required String blockchain,
    FeeSpeed? speed,
    bool isToken = false,
  }) async {
    final cacheKey = _buildCacheKey(blockchain, speed, isToken);
    final cachedJson = await StorageService.readJson(cacheKey);
    if (cachedJson == null) return null;
    try {
      final entry = FeeCacheEntry.fromJson(cachedJson);
      if (!entry.isValid) { await StorageService.delete(cacheKey); return null; }
      return entry.feeEstimate;
    } catch (_) {
      await StorageService.delete(cacheKey);
      return null;
    }
  }

  static Future<void> cacheFee(FeeEstimate feeEstimate, {bool isToken = false}) async {
    final cacheKey = _buildCacheKey(feeEstimate.blockchain, feeEstimate.speed, isToken);
    await StorageService.writeJson(cacheKey, FeeCacheEntry.create(feeEstimate).toJson());
  }

  static Future<void> clearCache({
    required String blockchain,
    FeeSpeed? speed,
    bool isToken = false,
  }) async {
    await StorageService.delete(_buildCacheKey(blockchain, speed, isToken));
  }

  static String _buildCacheKey(String blockchain, FeeSpeed? speed, bool isToken) {
    final tier = speed == null ? blockchain : '${blockchain}_${speed.name}';
    // Native keeps the bare key so entries written by earlier versions are still found; only
    // the token variant gets a suffix.
    return isToken ? '$_cacheKeyPrefix${tier}_token' : '$_cacheKeyPrefix$tier';
  }
}
