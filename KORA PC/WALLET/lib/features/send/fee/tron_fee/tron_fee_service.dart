import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora_windows/core/config/api_config.dart';
import '../models/fee_estimate.dart';
import '../services/fee_api_service.dart';

class TronFeeService extends FeeApiService {
  @override
  String get blockchain => 'tron';
  @override
  bool get supportsVariableFees => false;

  @override
  Future<FeeEstimate?> fetchFee({FeeSpeed? speed, bool isToken = false}) async {
    try {
      if (!isToken) {
        const bandwidthCostSun = 345 * 1000;
        final feeInTrx = bandwidthCostSun / 1000000;
        return FeeEstimate(
          blockchain: blockchain, speed: null,
          feeInNative: feeInTrx, feeInUsd: 0.0,
          estimatedTime: '~3 sec',
          details: {'bandwidthCostSun': bandwidthCostSun, 'type': 'native'},
          fetchedAt: DateTime.now(),
        );
      }
      final energyPrice = await _getEnergyPrice();
      const trc20EnergyNeeded = 130000;
      final energyCostSun = trc20EnergyNeeded * energyPrice;
      const bandwidthCostSun = 345 * 1000;
      final totalSun = energyCostSun + bandwidthCostSun;
      final feeInTrx = totalSun / 1000000;
      return FeeEstimate(
        blockchain: blockchain, speed: null,
        feeInNative: feeInTrx, feeInUsd: 0.0,
        estimatedTime: '~3 sec',
        details: {
          'energyNeeded': trc20EnergyNeeded, 'energyPrice': energyPrice,
          'energyCostSun': energyCostSun, 'bandwidthCostSun': bandwidthCostSun,
          'totalSun': totalSun, 'type': 'TRC-20',
        },
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      throw FeeApiException('Failed to fetch Tron fee', blockchain: blockchain, originalError: e);
    }
  }

  @override
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false}) async =>
      _getFallbackFee(isToken: isToken);

  @override
  String? validateFee(double feeInNative) => null;

  Future<int> _getEnergyPrice() async {
    try {
      final response = await http.post(
        Uri.parse('${APIConfig.tronMainnetApi}/wallet/getenergyprices'),
        headers: {
          'Content-Type': 'application/json',
          if (APIConfig.trongridKey.isNotEmpty) 'TRON-PRO-API-KEY': APIConfig.trongridKey,
        },
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final pricesStr = data['prices'] as String? ?? '';
        if (pricesStr.isNotEmpty) {
          final parts = pricesStr.split(',').last.split(':');
          if (parts.length == 2) {
            final price = int.tryParse(parts[1]);
            if (price != null && price > 0) return price;
          }
        }
      }
    } catch (e) {
      debugPrint('[FEE][tron] Failed to get energy price: $e');
    }
    return 420;
  }

  FeeEstimate _getFallbackFee({bool isToken = false}) => FeeEstimate(
        blockchain: blockchain, speed: null,
        feeInNative: isToken ? 14.0 : 0.345, feeInUsd: 0.0,
        estimatedTime: '~3 sec',
        details: {'source': 'fallback', 'type': isToken ? 'TRC-20' : 'native'},
        fetchedAt: DateTime.now(),
      );
}
