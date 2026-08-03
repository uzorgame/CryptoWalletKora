import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/repositories/price_repository.dart';
import '../models/fee_estimate.dart';
import '../services/fee_cache_service.dart';
import 'bitcoin_fee_service.dart';

/// Bitcoin Fee Provider
/// Manages fee fetching, caching, and USD conversion for Bitcoin
final bitcoinFeeProvider = StateNotifierProvider.family<BitcoinFeeNotifier, AsyncValue<FeeEstimate?>, FeeSpeed?>(
  (ref, speed) => BitcoinFeeNotifier(speed: speed),
);

class BitcoinFeeNotifier extends StateNotifier<AsyncValue<FeeEstimate?>> {
  final FeeSpeed? speed;
  final BitcoinFeeService _feeService = BitcoinFeeService();
  final PriceRepository _priceRepository = PriceRepository();

  BitcoinFeeNotifier({this.speed}) : super(const AsyncValue.data(null));

  /// Fetch fee with cache-first strategy
  Future<void> fetchFee({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();

    try {
      // 1. Try cache first (if not forcing refresh)
      if (!forceRefresh) {
        final cachedFee = await FeeCacheService.getCachedFee(
          blockchain: 'bitcoin',
          speed: speed,
        );
        
        if (cachedFee != null) {
          // Update USD price even for cached fee
          final feeWithUsd = await _addUsdPrice(cachedFee);
          state = AsyncValue.data(feeWithUsd);
          return;
        }
      }

      // 2. Cache miss or force refresh - fetch from API
      final fee = await _feeService.getFeeEstimate(speed: speed);
      
      if (fee != null) {
        // Add USD price
        final feeWithUsd = await _addUsdPrice(fee);
        
        // Cache the fee
        await FeeCacheService.cacheFee(feeWithUsd);
        
        state = AsyncValue.data(feeWithUsd);
      } else {
        // All APIs failed - allow manual input
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Add USD price to fee estimate
  Future<FeeEstimate> _addUsdPrice(FeeEstimate fee) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['bitcoin']);
      final btcPrice = prices['bitcoin']?.priceUsd ?? 0.0;
      final feeInUsd = fee.feeInNative * btcPrice;
      
      return fee.copyWith(feeInUsd: feeInUsd);
    } catch (e) {
      // If price fetch fails, return fee with 0 USD
      return fee;
    }
  }

  /// Refresh fee (force fetch from API)
  Future<void> refresh() async {
    await fetchFee(forceRefresh: true);
  }

  /// Create manual fee estimate
  void setManualFee(double feeInBtc) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['bitcoin']);
      final btcPrice = prices['bitcoin']?.priceUsd ?? 0.0;
      
      final manualFee = FeeEstimate.manual(
        blockchain: 'bitcoin',
        feeInNative: feeInBtc,
        feeInUsd: feeInBtc * btcPrice,
      );
      
      state = AsyncValue.data(manualFee);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
