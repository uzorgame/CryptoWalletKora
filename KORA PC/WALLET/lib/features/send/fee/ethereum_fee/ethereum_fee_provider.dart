import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora_windows/core/repositories/price_repository.dart';
import '../models/fee_estimate.dart';
import '../services/fee_cache_service.dart';
import 'ethereum_fee_service.dart';

final ethereumFeeProvider = StateNotifierProvider.family<EthereumFeeNotifier, AsyncValue<FeeEstimate?>, EthereumFeeParams>(
  (ref, params) => EthereumFeeNotifier(params: params),
);

class EthereumFeeParams {
  final String blockchain;
  final FeeSpeed? speed;
  final bool isToken;
  const EthereumFeeParams({required this.blockchain, this.speed, this.isToken = false});

  @override
  bool operator ==(Object other) =>
      other is EthereumFeeParams &&
      other.blockchain == blockchain &&
      other.speed == speed &&
      other.isToken == isToken;

  @override
  int get hashCode => Object.hash(blockchain, speed, isToken);
}

class EthereumFeeNotifier extends StateNotifier<AsyncValue<FeeEstimate?>> {
  final EthereumFeeParams params;
  late final EthereumFeeService _feeService;
  final PriceRepository _priceRepository = PriceRepository();

  EthereumFeeNotifier({required this.params}) : super(const AsyncValue.data(null)) {
    _feeService = EthereumFeeService(params.blockchain);
  }

  Future<void> fetchFee({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    try {
      if (!forceRefresh) {
        final cached = await FeeCacheService.getCachedFee(blockchain: params.blockchain, speed: params.speed, isToken: params.isToken);
        if (cached != null) { state = AsyncValue.data(await _addUsd(cached)); return; }
      }
      final fee = await _feeService.getFeeEstimate(speed: params.speed, isToken: params.isToken);
      if (fee != null) {
        final withUsd = await _addUsd(fee);
        await FeeCacheService.cacheFee(withUsd, isToken: params.isToken);
        state = AsyncValue.data(withUsd);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      debugPrint('[FEE][${params.blockchain}] ERROR: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<FeeEstimate> _addUsd(FeeEstimate fee) async {
    try {
      final coinGeckoId = switch (params.blockchain) {
        'bsc'               => 'binancecoin',
        'ethereum_classic'  => 'ethereum-classic',
        _                   => 'ethereum',
      };
      final prices = await _priceRepository.getPricesOptimized([coinGeckoId]);
      return fee.copyWith(feeInUsd: fee.feeInNative * (prices[coinGeckoId]?.priceUsd ?? 0.0));
    } catch (_) { return fee; }
  }
}
