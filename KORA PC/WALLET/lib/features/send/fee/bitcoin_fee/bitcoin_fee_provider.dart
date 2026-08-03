import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora_windows/core/repositories/price_repository.dart';
import '../models/fee_estimate.dart';
import '../services/fee_cache_service.dart';
import 'bitcoin_fee_service.dart';

final bitcoinFeeProvider = StateNotifierProvider.family<BitcoinFeeNotifier, AsyncValue<FeeEstimate?>, FeeSpeed?>(
  (ref, speed) => BitcoinFeeNotifier(speed: speed),
);

class BitcoinFeeNotifier extends StateNotifier<AsyncValue<FeeEstimate?>> {
  final FeeSpeed? speed;
  final BitcoinFeeService _feeService = BitcoinFeeService();
  final PriceRepository _priceRepository = PriceRepository();

  BitcoinFeeNotifier({this.speed}) : super(const AsyncValue.data(null));

  Future<void> fetchFee({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    try {
      if (!forceRefresh) {
        final cached = await FeeCacheService.getCachedFee(blockchain: 'bitcoin', speed: speed);
        if (cached != null) { state = AsyncValue.data(await _addUsd(cached)); return; }
      }
      final fee = await _feeService.getFeeEstimate(speed: speed);
      if (fee != null) {
        final withUsd = await _addUsd(fee);
        await FeeCacheService.cacheFee(withUsd);
        state = AsyncValue.data(withUsd);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) { state = AsyncValue.error(e, st); }
  }

  Future<FeeEstimate> _addUsd(FeeEstimate fee) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['bitcoin']);
      return fee.copyWith(feeInUsd: fee.feeInNative * (prices['bitcoin']?.priceUsd ?? 0.0));
    } catch (_) { return fee; }
  }
}
