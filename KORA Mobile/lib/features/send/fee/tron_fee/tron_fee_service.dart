import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora/core/config/api_config.dart';
import '../models/fee_estimate.dart';
import '../services/fee_api_service.dart';

/// Tron Fee Service
/// Calculates bandwidth + energy costs for TRX and TRC-20 transfers
/// IMPORTANT: TRC-20 transfers need ~13-15 TRX for energy
class TronFeeService extends FeeApiService {
  @override
  String get blockchain => 'tron';

  @override
  bool get supportsVariableFees => false; // Fixed fee structure

  @override
  Future<FeeEstimate?> fetchFee({FeeSpeed? speed, bool isToken = false}) async {
    try {
      debugPrint('[FEE][tron] fetchFee START (isToken=$isToken)');

      // Native TRX: bandwidth only (~0.3 TRX)
      // TRC-20 tokens: bandwidth + energy (~13-15 TRX)
      if (!isToken) {
        // ── Native TRX transfer ─────────────────────────────────────────
        // Only costs bandwidth: ~345 bytes × 1000 SUN/byte = 345,000 SUN
        const bandwidthCostSun = 345 * 1000;
        final feeInTrx = bandwidthCostSun / 1000000;
        debugPrint('[FEE][tron] Native TRX fee: $feeInTrx TRX');

        return FeeEstimate(
          blockchain: blockchain,
          speed: null,
          feeInNative: feeInTrx,
          feeInUsd: 0.0,
          estimatedTime: '~3 sec',
          details: {
            'bandwidthCostSun': bandwidthCostSun,
            'type': 'native',
          },
          fetchedAt: DateTime.now(),
        );
      }

      // ── TRC-20 token transfer ──────────────────────────────────────
      final energyPrice = await _getEnergyPrice();
      debugPrint('[FEE][tron] Energy price: $energyPrice SUN/unit');

      // ~65k energy for warm address, ~130k for cold (first-time recipient)
      const trc20EnergyNeeded = 130000;
      final energyCostSun = trc20EnergyNeeded * energyPrice;
      const bandwidthCostSun = 345 * 1000;
      final totalSun = energyCostSun + bandwidthCostSun;
      final feeInTrx = totalSun / 1000000;
      debugPrint('[FEE][tron] TRC-20 fee: $feeInTrx TRX '
          '(energy=$energyCostSun + bw=$bandwidthCostSun = $totalSun SUN)');

      return FeeEstimate(
        blockchain: blockchain,
        speed: null,
        feeInNative: feeInTrx,
        feeInUsd: 0.0,
        estimatedTime: '~3 sec',
        details: {
          'energyNeeded': trc20EnergyNeeded,
          'energyPrice': energyPrice,
          'energyCostSun': energyCostSun,
          'bandwidthCostSun': bandwidthCostSun,
          'totalSun': totalSun,
          'type': 'TRC-20',
        },
        fetchedAt: DateTime.now(),
      );
    } catch (e, stack) {
      debugPrint('[FEE][tron] fetchFee ERROR: $e');
      debugPrint('[FEE][tron] Stack: $stack');
      throw FeeApiException(
        'Failed to fetch Tron fee from TronGrid',
        blockchain: blockchain,
        originalError: e,
      );
    }
  }

  @override
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false}) async {
    try {
      // Use TronScan API as backup
      final response = await http.get(
        Uri.parse('${APIConfig.tronscanApi}/system/status'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final feeInTrx = isToken ? 14.0 : 0.345;
        return FeeEstimate(
          blockchain: blockchain,
          speed: null,
          feeInNative: feeInTrx,
          feeInUsd: 0.0,
          estimatedTime: '~3 sec',
          details: {
            'source': 'tronscan_fallback',
            'type': isToken ? 'TRC-20' : 'native',
          },
          fetchedAt: DateTime.now(),
        );
      }
      
      return _getFallbackFee(isToken: isToken);
    } catch (e) {
      return _getFallbackFee(isToken: isToken);
    }
  }

  @override
  String? validateFee(double feeInNative) {
    const minFeeTrx = 0.1;
    const maxFee = 30.0;
    if (feeInNative < minFeeTrx) return 'Fee too low. Minimum: $minFeeTrx TRX';
    if (feeInNative > maxFee)    return 'Fee too high. Maximum: $maxFee TRX';
    return null;
  }

  /// Get current energy price from Tron network
  /// Returns the latest energy price in SUN per energy unit
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
          // Format: "timestamp1:price1,timestamp2:price2,..."
          // Get the last (most recent) price
          final priceEntries = pricesStr.split(',');
          if (priceEntries.isNotEmpty) {
            final lastEntry = priceEntries.last;
            final parts = lastEntry.split(':');
            if (parts.length == 2) {
              final price = int.tryParse(parts[1]);
              if (price != null && price > 0) {
                debugPrint('[FEE][tron] Latest energy price from API: $price SUN/unit');
                return price;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[FEE][tron] Failed to get energy price: $e');
      // Fallback to typical energy price
    }
    debugPrint('[FEE][tron] Using fallback energy price: 420 SUN/unit');
    return 420; // Current Tron energy price in SUN per unit
  }

  /// Fallback fee when all APIs fail
  FeeEstimate _getFallbackFee({bool isToken = false}) {
    final feeInTrx = isToken ? 14.0 : 0.345;
    return FeeEstimate(
      blockchain: blockchain,
      speed: null,
      feeInNative: feeInTrx,
      feeInUsd: 0.0,
      estimatedTime: '~3 sec',
      details: {
        'source': 'fallback',
        'type': isToken ? 'TRC-20' : 'native',
      },
      fetchedAt: DateTime.now(),
    );
  }
}
