import 'fee_estimate.dart';

/// Fee Cache Entry
/// Wraps FeeEstimate with cache metadata for 24-hour caching
class FeeCacheEntry {
  /// The cached fee estimate
  final FeeEstimate feeEstimate;
  
  /// When this entry was cached
  final DateTime cachedAt;
  
  /// Cache duration (default: 24 hours)
  final Duration cacheDuration;

  const FeeCacheEntry({
    required this.feeEstimate,
    required this.cachedAt,
    this.cacheDuration = const Duration(hours: 24),
  });

  /// Check if cache is still valid
  bool get isValid {
    final now = DateTime.now();
    final expiresAt = cachedAt.add(cacheDuration);
    return now.isBefore(expiresAt);
  }

  /// Time remaining until cache expires
  Duration get timeUntilExpiry {
    final now = DateTime.now();
    final expiresAt = cachedAt.add(cacheDuration);
    final remaining = expiresAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Create a new cache entry with current timestamp
  factory FeeCacheEntry.create(FeeEstimate feeEstimate) {
    return FeeCacheEntry(
      feeEstimate: feeEstimate,
      cachedAt: DateTime.now(),
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'feeEstimate': feeEstimate.toJson(),
      'cachedAt': cachedAt.toIso8601String(),
      'cacheDuration': cacheDuration.inMilliseconds,
    };
  }

  /// Create from JSON (for cache retrieval)
  factory FeeCacheEntry.fromJson(Map<String, dynamic> json) {
    return FeeCacheEntry(
      feeEstimate: FeeEstimate.fromJson(json['feeEstimate'] as Map<String, dynamic>),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      cacheDuration: Duration(milliseconds: json['cacheDuration'] as int? ?? 86400000),
    );
  }

  @override
  String toString() {
    return 'FeeCacheEntry(blockchain: ${feeEstimate.blockchain}, '
           'isValid: $isValid, timeRemaining: ${timeUntilExpiry.inHours}h)';
  }
}
