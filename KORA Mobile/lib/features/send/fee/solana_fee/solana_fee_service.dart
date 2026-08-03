import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora/core/config/api_config.dart';
import '../models/fee_estimate.dart';
import '../services/fee_api_service.dart';

/// Solana Fee Service
/// Fetches real-time priority fees using getRecentPrioritizationFees RPC method
/// Backup: Helius RPC
class SolanaFeeService extends FeeApiService {
  @override
  String get blockchain => 'solana';

  @override
  bool get supportsVariableFees => true;

  @override
  Future<FeeEstimate?> fetchFee({FeeSpeed? speed, bool isToken = false}) async {
    try {
      debugPrint('[FEE][solana] fetchFee START');
      final response = await http.post(
        Uri.parse(APIConfig.solanaMainnetRpc),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getRecentPrioritizationFees',
          'params': [[]], // Empty array to get recent fees for all accounts
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[FEE][solana] Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[FEE][solana] Response data keys: ${data.keys}');
        
        if (data['result'] != null) {
          final fees = data['result'] as List;
          debugPrint('[FEE][solana] Received ${fees.length} fee entries');
          
          // Calculate average priority fee from recent blocks
          final priorityFees = fees.map((f) => f['prioritizationFee'] as int).toList();
          final avgPriorityFee = priorityFees.isEmpty 
              ? 0 
              : priorityFees.reduce((a, b) => a + b) ~/ priorityFees.length;
          debugPrint('[FEE][solana] Average priority fee: $avgPriorityFee lamports');
          
          // Base fee is 5000 lamports per signature
          const baseFee = 5000;
          final priorityFee = _getPriorityFeeForSpeed(avgPriorityFee, speed ?? FeeSpeed.normal);
          final totalFee = baseFee + priorityFee;
          debugPrint('[FEE][solana] Total fee: $totalFee lamports (base: $baseFee + priority: $priorityFee)');
          
          // Convert lamports to SOL
          final feeInSol = totalFee / 1000000000;
          debugPrint('[FEE][solana] Fee in SOL: $feeInSol');
          
          debugPrint('[FEE][solana] fetchFee SUCCESS');
          return FeeEstimate(
            blockchain: blockchain,
            speed: speed ?? FeeSpeed.normal,
            feeInNative: feeInSol,
            feeInUsd: 0.0,
            estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
            details: {
              'baseFee': baseFee,
              'priorityFee': priorityFee,
              'totalLamports': totalFee,
              'avgPriorityFee': avgPriorityFee,
            },
            fetchedAt: DateTime.now(),
          );
        }
        debugPrint('[FEE][solana] No result in response');
      }
      debugPrint('[FEE][solana] Response status != 200 or no result');
      return null;
    } catch (e, stack) {
      debugPrint('[FEE][solana] fetchFee ERROR: $e');
      debugPrint('[FEE][solana] Stack: $stack');
      throw FeeApiException(
        'Failed to fetch Solana fee from mainnet RPC',
        blockchain: blockchain,
        originalError: e,
      );
    }
  }

  @override
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false}) async {
    try {
      // Try Helius backup RPC
      final response = await http.post(
        Uri.parse(APIConfig.heliusSolanaRpc),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getRecentPrioritizationFees',
          'params': [[]], // Empty array for all accounts
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['result'] != null) {
          final fees = data['result'] as List;
          final priorityFees = fees.map((f) => f['prioritizationFee'] as int).toList();
          final avgPriorityFee = priorityFees.isEmpty 
              ? 0 
              : priorityFees.reduce((a, b) => a + b) ~/ priorityFees.length;
          
          const baseFee = 5000;
          final priorityFee = _getPriorityFeeForSpeed(avgPriorityFee, speed ?? FeeSpeed.normal);
          final totalFee = baseFee + priorityFee;
          final feeInSol = totalFee / 1000000000;
          
          return FeeEstimate(
            blockchain: blockchain,
            speed: speed ?? FeeSpeed.normal,
            feeInNative: feeInSol,
            feeInUsd: 0.0,
            estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
            details: {
              'baseFee': baseFee,
              'priorityFee': priorityFee,
              'totalLamports': totalFee,
              'source': 'helius',
            },
            fetchedAt: DateTime.now(),
          );
        }
      }
      
      // If backup also fails, use conservative fallback
      return _getFallbackFee(speed ?? FeeSpeed.normal);
    } catch (e) {
      return _getFallbackFee(speed ?? FeeSpeed.normal);
    }
  }

  @override
  String? validateFee(double feeInNative) {
    // Minimum fee: 5000 lamports = 0.000005 SOL
    const minFee = 0.000005;
    // Maximum reasonable fee: 1000000 lamports = 0.001 SOL
    const maxFee = 0.001;

    if (feeInNative < minFee) {
      return 'Fee too low. Minimum: $minFee SOL';
    }
    if (feeInNative > maxFee) {
      return 'Fee too high. Maximum: $maxFee SOL';
    }
    return null;
  }

  /// Get priority fee based on speed
  int _getPriorityFeeForSpeed(int avgPriorityFee, FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast => (avgPriorityFee * 2).toInt(),
      FeeSpeed.normal => avgPriorityFee,
      FeeSpeed.slow => (avgPriorityFee * 0.5).toInt(),
    };
  }

  /// Get estimated confirmation time
  String _getEstimatedTime(FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast => '~1 sec',
      FeeSpeed.normal => '~2 sec',
      FeeSpeed.slow => '~5 sec',
    };
  }

  /// Fallback fee when all APIs fail
  FeeEstimate _getFallbackFee(FeeSpeed speed) {
    const baseFee = 5000;
    final priorityFee = switch (speed) {
      FeeSpeed.fast => 10000,
      FeeSpeed.normal => 5000,
      FeeSpeed.slow => 1000,
    };
    final totalFee = baseFee + priorityFee;
    final feeInSol = totalFee / 1000000000;
    
    return FeeEstimate(
      blockchain: blockchain,
      speed: speed,
      feeInNative: feeInSol,
      feeInUsd: 0.0,
      estimatedTime: _getEstimatedTime(speed),
      details: {
        'baseFee': baseFee,
        'priorityFee': priorityFee,
        'totalLamports': totalFee,
        'source': 'fallback',
      },
      fetchedAt: DateTime.now(),
    );
  }
}
