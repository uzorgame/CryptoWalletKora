import 'dart:async';

/// Rate Limiter for API calls
/// Prevents exceeding API rate limits
class RateLimiter {
  final int maxCalls;
  final Duration period;
  final List<DateTime> _callTimestamps = [];
  
  RateLimiter({
    required this.maxCalls,
    required this.period,
  });
  
  /// Execute a function with rate limiting
  /// Waits if rate limit would be exceeded
  Future<T> execute<T>(Future<T> Function() fn) async {
    await _waitIfNeeded();
    _recordCall();
    return await fn();
  }
  
  /// Check if we can make a call without waiting
  bool canCall() {
    _cleanOldTimestamps();
    return _callTimestamps.length < maxCalls;
  }
  
  /// Wait until we can make a call
  Future<void> _waitIfNeeded() async {
    _cleanOldTimestamps();
    
    while (_callTimestamps.length >= maxCalls) {
      final oldestCall = _callTimestamps.first;
      final timeSinceOldest = DateTime.now().difference(oldestCall);
      final waitTime = period - timeSinceOldest;
      
      if (waitTime > Duration.zero) {
        await Future.delayed(waitTime);
      }
      
      _cleanOldTimestamps();
    }
  }
  
  /// Record a new call
  void _recordCall() {
    _callTimestamps.add(DateTime.now());
  }
  
  /// Remove timestamps older than the period
  void _cleanOldTimestamps() {
    final cutoff = DateTime.now().subtract(period);
    _callTimestamps.removeWhere((timestamp) => timestamp.isBefore(cutoff));
  }
  
  /// Get current call count in period
  int get currentCalls {
    _cleanOldTimestamps();
    return _callTimestamps.length;
  }
  
  /// Get remaining calls in period
  int get remainingCalls {
    return maxCalls - currentCalls;
  }
  
  /// Reset rate limiter
  void reset() {
    _callTimestamps.clear();
  }
}

/// Rate limiter for CoinGecko API
/// Free tier: 10-50 calls/minute
class CoinGeckoRateLimiter extends RateLimiter {
  CoinGeckoRateLimiter({int callsPerMinute = 45})
      : super(
          maxCalls: callsPerMinute,
          period: const Duration(minutes: 1),
        );
}
