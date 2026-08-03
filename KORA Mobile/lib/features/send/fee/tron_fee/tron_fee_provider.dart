import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/repositories/price_repository.dart';
import '../models/fee_estimate.dart';
import '../services/fee_cache_service.dart';
import 'tron_fee_service.dart';

/// Tron Fee Provider
final tronFeeProvider = StateNotifierProvider<TronFeeNotifier, AsyncValue<FeeEstimate?>>(
  (ref) => TronFeeNotifier(),
);

class TronFeeNotifier extends StateNotifier<AsyncValue<FeeEstimate?>> {
  final TronFeeService _feeService = TronFeeService();
  final PriceRepository _priceRepository = PriceRepository();

  TronFeeNotifier() : super(const AsyncValue.data(null));

  Future<void> fetchFee({bool forceRefresh = false, bool isToken = false}) async {
    debugPrint('[FEE][Provider][tron] fetchFee called (forceRefresh: $forceRefresh, isToken: $isToken)');
    state = const AsyncValue.loading();

    try {
      if (!forceRefresh) {
        final cachedFee = await FeeCacheService.getCachedFee(
          blockchain: 'tron',
          speed: null,
        );
        
        if (cachedFee != null) {
          // Only use cache if it matches the token type
          final cachedType = cachedFee.details?['type'] as String?;
          final wantType = isToken ? 'TRC-20' : 'native';
          if (cachedType == wantType) {
            debugPrint('[FEE][Provider][tron] Cache hit ($wantType)');
            final feeWithUsd = await _addUsdPrice(cachedFee);
            state = AsyncValue.data(feeWithUsd);
            return;
          }
        }
      }

      final fee = await _feeService.getFeeEstimate(speed: null, isToken: isToken);
      
      if (fee != null) {
        debugPrint('[FEE][Provider][tron] Adding USD price...');
        final feeWithUsd = await _addUsdPrice(fee);
        debugPrint('[FEE][Provider][tron] Fee: ${feeWithUsd.feeInNative} TRX, ${feeWithUsd.feeInUsd} USD');
        
        await FeeCacheService.cacheFee(feeWithUsd);
        state = AsyncValue.data(feeWithUsd);
        debugPrint('[FEE][Provider][tron] State set to data (SUCCESS)');
      } else {
        debugPrint('[FEE][Provider][tron] Fee is null');
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      debugPrint('[FEE][Provider][tron] ERROR: $e');
      debugPrint('[FEE][Provider][tron] Stack: $stack');
      state = AsyncValue.error(e, stack);
      debugPrint('[FEE][Provider][tron] State set to error');
    }
  }

  Future<FeeEstimate> _addUsdPrice(FeeEstimate fee) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['tron']);
      final trxPrice = prices['tron']?.priceUsd ?? 0.0;
      final feeInUsd = fee.feeInNative * trxPrice;
      
      return fee.copyWith(feeInUsd: feeInUsd);
    } catch (e) {
      return fee;
    }
  }

  Future<void> refresh() async {
    await fetchFee(forceRefresh: true);
  }

  void setManualFee(double feeInTrx) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['tron']);
      final trxPrice = prices['tron']?.priceUsd ?? 0.0;
      
      final manualFee = FeeEstimate.manual(
        blockchain: 'tron',
        feeInNative: feeInTrx,
        feeInUsd: feeInTrx * trxPrice,
      );
      
      state = AsyncValue.data(manualFee);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
