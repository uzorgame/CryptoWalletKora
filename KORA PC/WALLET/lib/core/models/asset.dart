import 'package:freezed_annotation/freezed_annotation.dart';

part 'asset.freezed.dart';
part 'asset.g.dart';

/// Asset model - represents a cryptocurrency or token
@freezed
class Asset with _$Asset {
  const factory Asset({
    required String id,
    required String symbol, // BTC, ETH, USDT
    required String name, // Bitcoin, Ethereum, Tether
    required String blockchain, // bitcoin, ethereum, solana
    required String contractAddress, // For tokens (ERC20, etc)
    required int decimals, // 8 for BTC, 18 for ETH
    required String balance, // String to avoid precision loss
    required double balanceInUsd,
    required double priceUsd,
    required double priceChange24h,
    String? iconUrl,
    @Default(AssetType.native) AssetType type,
    @Default(true) bool isVisible,
  }) = _Asset;

  factory Asset.fromJson(Map<String, dynamic> json) => _$AssetFromJson(json);
}

enum AssetType {
  @JsonValue('native')
  native, // Native blockchain currency (BTC, ETH, SOL)
  
  @JsonValue('token')
  token, // Token (ERC20, SPL, etc)
  
  @JsonValue('nft')
  nft, // NFT
}

extension AssetExtension on Asset {
  /// Get balance as double
  double get balanceAsDouble {
    return double.tryParse(balance) ?? 0.0;
  }
  
  /// Get formatted balance with symbol
  String get formattedBalance {
    final value = balanceAsDouble;
    if (value == 0) return '0 $symbol';
    if (value < 0.000001) return '< 0.000001 $symbol';
    if (value < 1) return '${value.toStringAsFixed(6)} $symbol';
    if (value < 1000) return '${value.toStringAsFixed(4)} $symbol';
    return '${value.toStringAsFixed(2)} $symbol';
  }
  
  /// Get formatted USD value
  String get formattedUsdValue {
    if (balanceInUsd == 0) return '\$0.00';
    if (balanceInUsd < 0.01) return '< \$0.01';
    if (balanceInUsd < 1000) return '\$${balanceInUsd.toStringAsFixed(2)}';
    if (balanceInUsd < 1000000) {
      return '\$${(balanceInUsd / 1000).toStringAsFixed(2)}K';
    }
    return '\$${(balanceInUsd / 1000000).toStringAsFixed(2)}M';
  }
  
  /// Get price change color
  bool get isPriceUp => priceChange24h >= 0;
  
  /// Get formatted price change
  String get formattedPriceChange {
    final abs = priceChange24h.abs();
    final sign = priceChange24h >= 0 ? '+' : '-';
    return '$sign${abs.toStringAsFixed(2)}%';
  }
}
