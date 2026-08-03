import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/repositories/price_repository.dart';
import '../models/fee_estimate.dart';
import '../services/fee_cache_service.dart';
import 'ethereum_classic_fee_service.dart';

final ethereumClassicFeeProvider = StateNotifierProvider.family<EthereumClassicFeeNotifier, AsyncValue<FeeEstimate?>, FeeSpeed?>(
  (ref, speed) => EthereumClassicFeeNotifier(speed: speed),
);

class EthereumClassicFeeNotifier extends StateNotifier<AsyncValue<FeeEstimate?>> {
  final FeeSpeed? speed;
  final EthereumClassicFeeService _feeService = EthereumClassicFeeService();
  final PriceRepository _priceRepository = PriceRepository();

  EthereumClassicFeeNotifier({this.speed}) : super(const AsyncValue.data(null));

  Future<void> fetchFee({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    try {
      if (!forceRefresh) {
        final cachedFee = await FeeCacheService.getCachedFee(blockchain: 'ethereum_classic', speed: speed);
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
      final prices = await _priceRepository.getPricesOptimized(['ethereum-classic']);
      final etcPrice = prices['ethereum-classic']?.priceUsd ?? 0.0;
      return fee.copyWith(feeInUsd: fee.feeInNative * etcPrice);
    } catch (e) {
      return fee;
    }
  }

  Future<void> refresh() => fetchFee(forceRefresh: true);

  void setManualFee(double feeInEtc) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['ethereum-classic']);
      final etcPrice = prices['ethereum-classic']?.priceUsd ?? 0.0;
      final manualFee = FeeEstimate.manual(
        blockchain: 'ethereum_classic',
        feeInNative: feeInEtc,
        feeInUsd: feeInEtc * etcPrice,
      );
      state = AsyncValue.data(manualFee);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
