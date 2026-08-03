import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kora_windows/core/models/asset.dart';

part 'wallet.freezed.dart';
part 'wallet.g.dart';

/// Wallet model - represents a crypto wallet
@freezed
class Wallet with _$Wallet {
  const factory Wallet({
    required String id,
    required String name,
    required WalletType type,
    required String mainAddress, // Primary address (Ethereum)
    @Default({}) Map<String, String> addresses, // blockchain -> address
    @Default([]) List<Asset> assets,
    required DateTime createdAt,
    DateTime? lastBackup,
    @Default(false) bool isBackedUp,
    String? derivationPath, // BIP44 path
  }) = _Wallet;

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);
}

enum WalletType {
  @JsonValue('seed_phrase')
  seedPhrase,
  
  @JsonValue('mpc')
  mpc,
  
  @JsonValue('imported')
  imported,
}

extension WalletTypeExtension on WalletType {
  String get displayName {
    switch (this) {
      case WalletType.seedPhrase:
        return 'Seed Phrase Wallet';
      case WalletType.mpc:
        return 'MPC Wallet';
      case WalletType.imported:
        return 'Imported Wallet';
    }
  }
  
  String get description {
    switch (this) {
      case WalletType.seedPhrase:
        return 'Most popular and easy to use';
      case WalletType.mpc:
        return 'Co-manage assets with others';
      case WalletType.imported:
        return 'Restored from existing wallet';
    }
  }
}
