import 'package:flutter/foundation.dart';
import '../models/fee_estimate.dart';

abstract class FeeApiService {
  String get blockchain;
  bool get supportsVariableFees;

  Future<FeeEstimate?> fetchFee({FeeSpeed? speed, bool isToken = false});
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false});

  String? validateFee(double feeInNative);

  String get displayName => _blockchainDisplayNames[blockchain] ?? blockchain;

  Future<FeeEstimate?> getFeeEstimate({FeeSpeed? speed, bool isToken = false}) async {
    try {
      final fee = await fetchFee(speed: speed, isToken: isToken);
      if (fee != null) return fee;
    } catch (e) {
      debugPrint('[FEE][Service][$blockchain] Primary FAILED: $e');
    }
    try {
      final fee = await fetchFeeFromBackup(speed: speed, isToken: isToken);
      if (fee != null) return fee;
    } catch (e) {
      debugPrint('[FEE][Service][$blockchain] Backup FAILED: $e');
    }
    return null;
  }

  static const _blockchainDisplayNames = {
    'bitcoin': 'Bitcoin', 'ethereum': 'Ethereum', 'solana': 'Solana',
    'tron': 'Tron', 'bsc': 'BNB Smart Chain',
    'ethereum_classic': 'Ethereum Classic',
    'litecoin': 'Litecoin', 'bitcoin_cash': 'Bitcoin Cash',
  };
}

class FeeApiException implements Exception {
  final String message;
  final String? blockchain;
  final dynamic originalError;
  FeeApiException(this.message, {this.blockchain, this.originalError});

  @override
  String toString() => blockchain != null
      ? 'FeeApiException [$blockchain]: $message'
      : 'FeeApiException: $message';
}
