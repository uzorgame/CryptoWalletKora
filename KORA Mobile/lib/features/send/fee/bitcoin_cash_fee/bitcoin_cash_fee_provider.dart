import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/repositories/price_repository.dart';
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
        final cachedFee = await FeeCacheService.getCachedFee(blockchain: 'bitcoin_cash', speed: speed);
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
      final prices = await _priceRepository.getPricesOptimized(['bitcoin-cash']);
      final bchPrice = prices['bitcoin-cash']?.priceUsd ?? 0.0;
      return fee.copyWith(feeInUsd: fee.feeInNative * bchPrice);
    } catch (e) {
      return fee;
    }
  }

  Future<void> refresh() => fetchFee(forceRefresh: true);

  void setManualFee(double feeInBch) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['bitcoin-cash']);
      final bchPrice = prices['bitcoin-cash']?.priceUsd ?? 0.0;
      final manualFee = FeeEstimate.manual(
        blockchain: 'bitcoin_cash',
        feeInNative: feeInBch,
        feeInUsd: feeInBch * bchPrice,
      );
      state = AsyncValue.data(manualFee);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
