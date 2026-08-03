import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/repositories/price_repository.dart';
import '../models/fee_estimate.dart';
import '../services/fee_cache_service.dart';
import 'solana_fee_service.dart';

/// Solana Fee Provider
final solanaFeeProvider = StateNotifierProvider.family<SolanaFeeNotifier, AsyncValue<FeeEstimate?>, FeeSpeed?>(
  (ref, speed) => SolanaFeeNotifier(speed: speed),
);

class SolanaFeeNotifier extends StateNotifier<AsyncValue<FeeEstimate?>> {
  final FeeSpeed? speed;
  final SolanaFeeService _feeService = SolanaFeeService();
  final PriceRepository _priceRepository = PriceRepository();

  SolanaFeeNotifier({this.speed}) : super(const AsyncValue.data(null));

  Future<void> fetchFee({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();

    try {
      if (!forceRefresh) {
        final cachedFee = await FeeCacheService.getCachedFee(
          blockchain: 'solana',
          speed: speed,
        );
        
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
      final prices = await _priceRepository.getPricesOptimized(['solana']);
      final solPrice = prices['solana']?.priceUsd ?? 0.0;
      final feeInUsd = fee.feeInNative * solPrice;
      
      return fee.copyWith(feeInUsd: feeInUsd);
    } catch (e) {
      return fee;
    }
  }

  Future<void> refresh() async {
    await fetchFee(forceRefresh: true);
  }

  void setManualFee(double feeInSol) async {
    try {
      final prices = await _priceRepository.getPricesOptimized(['solana']);
      final solPrice = prices['solana']?.priceUsd ?? 0.0;
      
      final manualFee = FeeEstimate.manual(
        blockchain: 'solana',
        feeInNative: feeInSol,
        feeInUsd: feeInSol * solPrice,
      );
      
      state = AsyncValue.data(manualFee);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
