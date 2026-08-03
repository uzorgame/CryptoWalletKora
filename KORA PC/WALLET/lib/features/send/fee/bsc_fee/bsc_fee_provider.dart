import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora_windows/core/repositories/price_repository.dart';
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
        final cached = await FeeCacheService.getCachedFee(blockchain: 'bsc', speed: speed, isToken: isToken);
        if (cached != null) { state = AsyncValue.data(await _addUsd(cached)); return; }
      }
      final fee = await _feeService.getFeeEstimate(speed: speed, isToken: isToken);
      if (fee != null) {
        final withUsd = await _addUsd(fee);
        await FeeCacheService.cacheFee(withUsd, isToken: isToken);
        state = AsyncValue.data(withUsd);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) { state = AsyncValue.error(e, st); }
  }

  Future<FeeEstimate> _addUsd(FeeEstimate fee) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['binancecoin']);
      return fee.copyWith(feeInUsd: fee.feeInNative * (prices['binancecoin']?.priceUsd ?? 0.0));
    } catch (_) { return fee; }
  }
}
