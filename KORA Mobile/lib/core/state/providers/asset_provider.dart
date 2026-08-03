import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';

/// Provider для отримання всіх активів поточного гаманця
final assetsProvider = Provider<List<Asset>>((ref) {
  final walletAsync = ref.watch(currentWalletProvider);
  
  return walletAsync.when(
    data: (wallet) => wallet?.assets ?? [],
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider для отримання видимих активів
final visibleAssetsProvider = Provider<List<Asset>>((ref) {
  final assets = ref.watch(assetsProvider);
  return assets.where((asset) => asset.isVisible).toList();
});

/// Provider для отримання загального балансу в USD
final totalBalanceProvider = Provider<double>((ref) {
  final assets = ref.watch(visibleAssetsProvider);
  return assets.fold(0.0, (sum, asset) => sum + asset.balanceInUsd);
});

/// Provider для отримання активу за символом
final assetBySymbolProvider = Provider.family<Asset?, String>((ref, symbol) {
  final assets = ref.watch(assetsProvider);
  try {
    return assets.firstWhere((asset) => asset.symbol == symbol);
  } catch (e) {
    return null;
  }
});

/// Provider для отримання активів за блокчейном
final assetsByBlockchainProvider = Provider.family<List<Asset>, String>((ref, blockchain) {
  final assets = ref.watch(assetsProvider);
  return assets.where((asset) => asset.blockchain == blockchain).toList();
});

/// Provider для сортованих активів (за балансом USD)
final sortedAssetsByValueProvider = Provider<List<Asset>>((ref) {
  final assets = ref.watch(visibleAssetsProvider);
  final sorted = List<Asset>.from(assets);
  sorted.sort((a, b) => b.balanceInUsd.compareTo(a.balanceInUsd));
  return sorted;
});

/// Provider для native активів (не токенів)
final nativeAssetsProvider = Provider<List<Asset>>((ref) {
  final assets = ref.watch(visibleAssetsProvider);
  return assets.where((asset) => asset.type == AssetType.native).toList();
});

/// Provider для токенів
final tokenAssetsProvider = Provider<List<Asset>>((ref) {
  final assets = ref.watch(visibleAssetsProvider);
  return assets.where((asset) => asset.type == AssetType.token).toList();
});
