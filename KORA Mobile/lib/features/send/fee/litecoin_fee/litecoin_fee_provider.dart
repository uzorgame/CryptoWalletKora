import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/repositories/price_repository.dart';
import '../models/fee_estimate.dart';
import '../services/fee_cache_service.dart';
import 'litecoin_fee_service.dart';

final litecoinFeeProvider = StateNotifierProvider.family<LitecoinFeeNotifier, AsyncValue<FeeEstimate?>, FeeSpeed?>(
  (ref, speed) => LitecoinFeeNotifier(speed: speed),
);

class LitecoinFeeNotifier extends StateNotifier<AsyncValue<FeeEstimate?>> {
  final FeeSpeed? speed;
  final LitecoinFeeService _feeService = LitecoinFeeService();
  final PriceRepository _priceRepository = PriceRepository();

  LitecoinFeeNotifier({this.speed}) : super(const AsyncValue.data(null));

  Future<void> fetchFee({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    try {
      if (!forceRefresh) {
        final cachedFee = await FeeCacheService.getCachedFee(blockchain: 'litecoin', speed: speed);
        if (cachedFee != null) {
          final feeWithUsd = await _addUsdPrice(cachedFee);
          state = AsyncValue.data(feeWithUsd);
          return;
        }
      }
      final fee = await _feeService.getFeeEstimate(speed: speed);
      if (fee != null) {
        final feeWithUsd = await _addUsdPrice(fee);
        await FeeCacheService.cacheFee(feeWithUsd);
        state = AsyncValue.data(feeWithUsd);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<FeeEstimate> _addUsdPrice(FeeEstimate fee) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['litecoin']);
      final ltcPrice = prices['litecoin']?.priceUsd ?? 0.0;
      return fee.copyWith(feeInUsd: fee.feeInNative * ltcPrice);
    } catch (e) {
      return fee;
    }
  }

  Future<void> refresh() => fetchFee(forceRefresh: true);

  void setManualFee(double feeInLtc) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['litecoin']);
      final ltcPrice = prices['litecoin']?.priceUsd ?? 0.0;
      final manualFee = FeeEstimate.manual(
        blockchain: 'litecoin',
        feeInNative: feeInLtc,
        feeInUsd: feeInLtc * ltcPrice,
      );
      state = AsyncValue.data(manualFee);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
