import 'package:flutter/foundation.dart';
import '../models/fee_estimate.dart';

/// Base class for all blockchain fee API services
/// Each blockchain implements this to fetch real-time fee data
abstract class FeeApiService {
  /// Blockchain identifier
  String get blockchain;

  /// Whether this blockchain supports variable fee speeds (slow/normal/fast)
  bool get supportsVariableFees;

  /// Fetch fee estimate from primary API
  /// Returns null if API fails
  Future<FeeEstimate?> fetchFee({FeeSpeed? speed, bool isToken = false});

  /// Fetch fee estimate from backup API (fallback)
  /// Returns null if backup API also fails
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false});

  /// Get fee estimate with automatic fallback chain:
  /// 1. Try cache first
  /// 2. Try primary API
  /// 3. Try backup API
  /// 4. Return null (caller should handle manual input)
  Future<FeeEstimate?> getFeeEstimate({FeeSpeed? speed, bool isToken = false}) async {
    debugPrint('[FEE][Service][$blockchain] getFeeEstimate START');
    
    // Try primary API first
    try {
      debugPrint('[FEE][Service][$blockchain] Trying primary API...');
      final fee = await fetchFee(speed: speed, isToken: isToken);
      if (fee != null) {
        debugPrint('[FEE][Service][$blockchain] Primary API SUCCESS');
        return fee;
      }
      debugPrint('[FEE][Service][$blockchain] Primary API returned null');
    } catch (e) {
      debugPrint('[FEE][Service][$blockchain] Primary API FAILED: $e');
      // Primary API failed, continue to backup
    }

    // Try backup API
    try {
      debugPrint('[FEE][Service][$blockchain] Trying backup API...');
      final fee = await fetchFeeFromBackup(speed: speed, isToken: isToken);
      if (fee != null) {
        debugPrint('[FEE][Service][$blockchain] Backup API SUCCESS');
        return fee;
      }
      debugPrint('[FEE][Service][$blockchain] Backup API returned null');
    } catch (e) {
      debugPrint('[FEE][Service][$blockchain] Backup API FAILED: $e');
      // Backup API also failed
    }

    // All APIs failed
    debugPrint('[FEE][Service][$blockchain] All APIs failed, returning null');
    return null;
  }

  /// Validate fee amount (blockchain-specific validation)
  /// Returns error message if invalid, null if valid
  String? validateFee(double feeInNative);

  /// Get display name for blockchain
  String get displayName => _blockchainDisplayNames[blockchain] ?? blockchain;

  static const _blockchainDisplayNames = {
    'bitcoin': 'Bitcoin',
    'ethereum': 'Ethereum',
    'solana': 'Solana',
    'tron': 'Tron',
    'bsc': 'BNB Smart Chain',
    'ethereum_classic': 'Ethereum Classic',
    'litecoin': 'Litecoin',
    'bitcoin_cash': 'Bitcoin Cash',
  };
}

/// Exception thrown when fee API fails
class FeeApiException implements Exception {
  final String message;
  final String? blockchain;
  final dynamic originalError;

  FeeApiException(this.message, {this.blockchain, this.originalError});

  @override
  String toString() {
    if (blockchain != null) {
      return 'FeeApiException [$blockchain]: $message';
    }
    return 'FeeApiException: $message';
  }
}
