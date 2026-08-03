import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora_windows/core/repositories/price_repository.dart';
import '../models/fee_estimate.dart';
import '../services/fee_cache_service.dart';
import 'tron_fee_service.dart';

final tronFeeProvider = StateNotifierProvider<TronFeeNotifier, AsyncValue<FeeEstimate?>>(
  (ref) => TronFeeNotifier(),
);

class TronFeeNotifier extends StateNotifier<AsyncValue<FeeEstimate?>> {
  final TronFeeService _feeService = TronFeeService();
  final PriceRepository _priceRepository = PriceRepository();

  TronFeeNotifier() : super(const AsyncValue.data(null));

  Future<void> fetchFee({bool forceRefresh = false, bool isToken = false}) async {
    state = const AsyncValue.loading();
    try {
      if (!forceRefresh) {
        final cached = await FeeCacheService.getCachedFee(blockchain: 'tron', speed: null, isToken: isToken);
        if (cached != null) {
          final cachedType = cached.details?['type'] as String?;
          final wantType = isToken ? 'TRC-20' : 'native';
          if (cachedType == wantType) { state = AsyncValue.data(await _addUsd(cached)); return; }
        }
      }
      final fee = await _feeService.getFeeEstimate(speed: null, isToken: isToken);
      if (fee != null) {
        final withUsd = await _addUsd(fee);
        await FeeCacheService.cacheFee(withUsd, isToken: isToken);
        state = AsyncValue.data(withUsd);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      debugPrint('[FEE][tron] ERROR: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<FeeEstimate> _addUsd(FeeEstimate fee) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['tron']);
      return fee.copyWith(feeInUsd: fee.feeInNative * (prices['tron']?.priceUsd ?? 0.0));
    } catch (_) { return fee; }
  }
}
