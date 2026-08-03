import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/repositories/price_repository.dart';
import '../models/fee_estimate.dart';
import '../services/fee_cache_service.dart';
import 'bsc_fee_service.dart';

final bscFeeProvider = StateNotifierProvider.family<BscFeeNotifier, AsyncValue<FeeEstimate?>, FeeSpeed?>(
  (ref, speed) => BscFeeNotifier(speed: speed),
);

class BscFeeNotifier extends StateNotifier<AsyncValue<FeeEstimate?>> {
  final FeeSpeed? speed;
  final BscFeeService _feeService = BscFeeService();
  final PriceRepository _priceRepository = PriceRepository();

  BscFeeNotifier({this.speed}) : super(const AsyncValue.data(null));

  Future<void> fetchFee({bool forceRefresh = false, bool isToken = false}) async {
    state = const AsyncValue.loading();
    try {
      if (!forceRefresh) {
        final cachedFee = await FeeCacheService.getCachedFee(blockchain: 'bsc', speed: speed);
        if (cachedFee != null) {
          final feeWithUsd = await _addUsdPrice(cachedFee);
          state = AsyncValue.data(feeWithUsd);
          return;
        }
      }
      final fee = await _feeService.getFeeEstimate(speed: speed, isToken: isToken);
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
      final prices = await _priceRepository.getPricesOptimized(['binancecoin']);
      final bnbPrice = prices['binancecoin']?.priceUsd ?? 0.0;
      return fee.copyWith(feeInUsd: fee.feeInNative * bnbPrice);
    } catch (e) {
      return fee;
    }
  }

  Future<void> refresh() => fetchFee(forceRefresh: true);

  void setManualFee(double feeInBnb) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['binancecoin']);
      final bnbPrice = prices['binancecoin']?.priceUsd ?? 0.0;
      final manualFee = FeeEstimate.manual(
        blockchain: 'bsc',
        feeInNative: feeInBnb,
        feeInUsd: feeInBnb * bnbPrice,
      );
      state = AsyncValue.data(manualFee);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
