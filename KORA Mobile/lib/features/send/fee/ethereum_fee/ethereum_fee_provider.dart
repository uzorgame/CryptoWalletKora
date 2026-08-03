import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/repositories/price_repository.dart';
import '../models/fee_estimate.dart';
import '../services/fee_cache_service.dart';
import 'ethereum_fee_service.dart';

/// Ethereum Fee Provider (works for all EVM chains)
/// Pass blockchain parameter to use for BSC, ETC, etc.
final ethereumFeeProvider = StateNotifierProvider.family<EthereumFeeNotifier, AsyncValue<FeeEstimate?>, EthereumFeeParams>(
  (ref, params) => EthereumFeeNotifier(params: params),
);

class EthereumFeeParams {
  final String blockchain;
  final FeeSpeed? speed;
  final bool isToken;

  const EthereumFeeParams({
    required this.blockchain,
    this.speed,
    this.isToken = false,
  });

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

  /// Fetch fee with cache-first strategy
  Future<void> fetchFee({bool forceRefresh = false}) async {
    debugPrint('[FEE][Provider][${params.blockchain}] fetchFee called (forceRefresh: $forceRefresh)');
    state = const AsyncValue.loading();
    debugPrint('[FEE][Provider][${params.blockchain}] State set to loading');

    try {
      // 1. Try cache first (if not forcing refresh)
      if (!forceRefresh) {
        debugPrint('[FEE][Provider][${params.blockchain}] Checking cache...');
        final cachedFee = await FeeCacheService.getCachedFee(
          blockchain: params.blockchain,
          speed: params.speed,
        );
        
        if (cachedFee != null) {
          debugPrint('[FEE][Provider][${params.blockchain}] Cache hit! Using cached fee');
          final feeWithUsd = await _addUsdPrice(cachedFee);
          state = AsyncValue.data(feeWithUsd);
          debugPrint('[FEE][Provider][${params.blockchain}] State set to data (from cache)');
          return;
        }
        debugPrint('[FEE][Provider][${params.blockchain}] Cache miss');
      } else {
        debugPrint('[FEE][Provider][${params.blockchain}] Skipping cache (forceRefresh=true)');
      }

      // 2. Cache miss or force refresh - fetch from API
      debugPrint('[FEE][Provider][${params.blockchain}] Calling _feeService.getFeeEstimate()...');
      final fee = await _feeService.getFeeEstimate(
        speed: params.speed,
        isToken: params.isToken,
      );
      debugPrint('[FEE][Provider][${params.blockchain}] getFeeEstimate returned: ${fee != null ? 'FeeEstimate' : 'null'}');
      
      if (fee != null) {
        debugPrint('[FEE][Provider][${params.blockchain}] Adding USD price...');
        final feeWithUsd = await _addUsdPrice(fee);
        debugPrint('[FEE][Provider][${params.blockchain}] Fee with USD: ${feeWithUsd.feeInNative} native, ${feeWithUsd.feeInUsd} USD');
        
        debugPrint('[FEE][Provider][${params.blockchain}] Caching fee...');
        await FeeCacheService.cacheFee(feeWithUsd);
        
        state = AsyncValue.data(feeWithUsd);
        debugPrint('[FEE][Provider][${params.blockchain}] State set to data (SUCCESS)');
      } else {
        debugPrint('[FEE][Provider][${params.blockchain}] Fee is null, setting state to null');
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      debugPrint('[FEE][Provider][${params.blockchain}] ERROR caught: $e');
      debugPrint('[FEE][Provider][${params.blockchain}] Stack: $stack');
      state = AsyncValue.error(e, stack);
      debugPrint('[FEE][Provider][${params.blockchain}] State set to error');
    }
  }

  /// Add USD price to fee estimate
  Future<FeeEstimate> _addUsdPrice(FeeEstimate fee) async {
    try {
      final coinGeckoId = _getCoinGeckoId(params.blockchain);
      final prices = await _priceRepository.getPricesOptimized([coinGeckoId]);
      final nativePrice = prices[coinGeckoId]?.priceUsd ?? 0.0;
      final feeInUsd = fee.feeInNative * nativePrice;
      
      return fee.copyWith(feeInUsd: feeInUsd);
    } catch (e) {
      return fee;
    }
  }

  /// Refresh fee (force fetch from API)
  Future<void> refresh() async {
    await fetchFee(forceRefresh: true);
  }

  /// Create manual fee estimate
  void setManualFee(double feeInNative) async {
    try {
      final coinGeckoId = _getCoinGeckoId(params.blockchain);
      final prices = await _priceRepository.getPricesOptimized([coinGeckoId]);
      final nativePrice = prices[coinGeckoId]?.priceUsd ?? 0.0;
      
      final manualFee = FeeEstimate.manual(
        blockchain: params.blockchain,
        feeInNative: feeInNative,
        feeInUsd: feeInNative * nativePrice,
      );
      
      state = AsyncValue.data(manualFee);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Get CoinGecko ID for blockchain
  String _getCoinGeckoId(String blockchain) {
    return switch (blockchain) {
      'ethereum' => 'ethereum',
      'bsc' => 'binancecoin',
      'ethereum_classic' => 'ethereum-classic',
      _ => 'ethereum',
    };
  }
}
