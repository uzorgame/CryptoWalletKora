import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora_windows/core/config/api_config.dart';
import '../models/fee_estimate.dart';
import '../services/fee_api_service.dart';

class SolanaFeeService extends FeeApiService {
  @override
  String get blockchain => 'solana';
  @override
  bool get supportsVariableFees => false;

  @override
  Future<FeeEstimate?> fetchFee({FeeSpeed? speed, bool isToken = false}) async {
    try {
      final response = await http.post(
        Uri.parse(APIConfig.solanaMainnetRpc),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0', 'id': 1,
          'method': 'getRecentPrioritizationFees',
          'params': [[]],
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
            blockchain: blockchain, speed: speed ?? FeeSpeed.normal,
            feeInNative: feeInSol, feeInUsd: 0.0,
            estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
            details: {'baseFee': baseFee, 'priorityFee': priorityFee, 'totalLamports': totalFee},
            fetchedAt: DateTime.now(),
          );
        }
      }
      return null;
    } catch (e) {
      throw FeeApiException('Failed to fetch Solana fee', blockchain: blockchain, originalError: e);
    }
  }

  @override
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false}) async {
    try {
      final response = await http.post(
        Uri.parse(APIConfig.heliusSolanaRpc),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0', 'id': 1,
          'method': 'getRecentPrioritizationFees',
          'params': [[]],
        }),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] != null) {
          final fees = data['result'] as List;
          final priorityFees = fees.map((f) => f['prioritizationFee'] as int).toList();
          final avgPriorityFee = priorityFees.isEmpty ? 0 : priorityFees.reduce((a, b) => a + b) ~/ priorityFees.length;
          const baseFee = 5000;
          final priorityFee = _getPriorityFeeForSpeed(avgPriorityFee, speed ?? FeeSpeed.normal);
          final totalFee = baseFee + priorityFee;
          return FeeEstimate(
            blockchain: blockchain, speed: speed ?? FeeSpeed.normal,
            feeInNative: totalFee / 1000000000, feeInUsd: 0.0,
            estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
            details: {'baseFee': baseFee, 'priorityFee': priorityFee, 'totalLamports': totalFee, 'source': 'helius'},
            fetchedAt: DateTime.now(),
          );
        }
      }
      return _getFallbackFee(speed ?? FeeSpeed.normal);
    } catch (e) {
      debugPrint('[FEE][solana] backup error: $e');
      return _getFallbackFee(speed ?? FeeSpeed.normal);
    }
  }

  @override
  String? validateFee(double feeInNative) => null;

  int _getPriorityFeeForSpeed(int avgPriorityFee, FeeSpeed speed) => switch (speed) {
        FeeSpeed.fast   => (avgPriorityFee * 2).toInt(),
        FeeSpeed.normal => avgPriorityFee,
        FeeSpeed.slow   => (avgPriorityFee * 0.5).toInt(),
      };

  String _getEstimatedTime(FeeSpeed speed) => switch (speed) {
        FeeSpeed.fast   => '~1 sec',
        FeeSpeed.normal => '~2 sec',
        FeeSpeed.slow   => '~5 sec',
      };

  FeeEstimate _getFallbackFee(FeeSpeed speed) {
    const baseFee = 5000;
    final priorityFee = switch (speed) {
      FeeSpeed.fast   => 10000,
      FeeSpeed.normal => 5000,
      FeeSpeed.slow   => 1000,
    };
    final totalFee = baseFee + priorityFee;
    return FeeEstimate(
      blockchain: blockchain, speed: speed,
      feeInNative: totalFee / 1000000000, feeInUsd: 0.0,
      estimatedTime: _getEstimatedTime(speed),
      details: {'baseFee': baseFee, 'priorityFee': priorityFee, 'totalLamports': totalFee, 'source': 'fallback'},
      fetchedAt: DateTime.now(),
    );
  }
}
