import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora_windows/core/repositories/price_repository.dart';
import '../models/fee_estimate.dart';
import '../services/fee_cache_service.dart';
import 'bitcoin_cash_fee_service.dart';

final bitcoinCashFeeProvider = StateNotifierProvider.family<BitcoinCashFeeNotifier, AsyncValue<FeeEstimate?>, FeeSpeed?>(
  (ref, speed) => BitcoinCashFeeNotifier(speed: speed),
);

class BitcoinCashFeeNotifier extends StateNotifier<AsyncValue<FeeEstimate?>> {
  final FeeSpeed? speed;
  final BitcoinCashFeeService _feeService = BitcoinCashFeeService();
  final PriceRepository _priceRepository = PriceRepository();

  BitcoinCashFeeNotifier({this.speed}) : super(const AsyncValue.data(null));

  Future<void> fetchFee({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    try {
      if (!forceRefresh) {
        final cached = await FeeCacheService.getCachedFee(blockchain: 'bitcoin_cash', speed: speed);
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
      final prices = await _priceRepository.getPricesOptimized(['bitcoin-cash']);
      return fee.copyWith(feeInUsd: fee.feeInNative * (prices['bitcoin-cash']?.priceUsd ?? 0.0));
    } catch (_) { return fee; }
  }
}
