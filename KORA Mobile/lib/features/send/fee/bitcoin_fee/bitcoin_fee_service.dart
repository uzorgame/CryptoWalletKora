import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kora/core/config/api_config.dart';
import '../models/fee_estimate.dart';
import '../services/fee_api_service.dart';

/// Bitcoin Fee Service
/// Fetches real-time fee estimates from mempool.space API
/// Backup: BlockCypher API
class BitcoinFeeService extends FeeApiService {
  @override
  String get blockchain => 'bitcoin';

  @override
  bool get supportsVariableFees => true;

  @override
  Future<FeeEstimate?> fetchFee({FeeSpeed? speed, bool isToken = false}) async {
    try {
      final response = await http
          .get(Uri.parse(APIConfig.mempoolSpaceBtcFee))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // mempool.space returns: {fastestFee, halfHourFee, hourFee, economyFee, minimumFee}
        final satPerVByte = _getSatPerVByteForSpeed(data, speed ?? FeeSpeed.normal);
        
        return FeeEstimate(
          blockchain: blockchain,
          speed: speed ?? FeeSpeed.normal,
          feeInNative: _calculateFeeInBTC(satPerVByte),
          feeInUsd: 0.0, // Will be calculated by provider using price
          estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
          details: {
            'satPerVByte': satPerVByte,
            'fastestFee': data['fastestFee'],
            'halfHourFee': data['halfHourFee'],
            'hourFee': data['hourFee'],
          },
          fetchedAt: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      throw FeeApiException(
        'Failed to fetch Bitcoin fee from mempool.space',
        blockchain: blockchain,
        originalError: e,
      );
    }
  }

  @override
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false}) async {
    try {
      // BlockCypher doesn't provide fee estimation in free tier
      // Use conservative fallback values based on current network conditions
      final satPerVByte = _getFallbackSatPerVByte(speed ?? FeeSpeed.normal);
      
      return FeeEstimate(
        blockchain: blockchain,
        speed: speed ?? FeeSpeed.normal,
        feeInNative: _calculateFeeInBTC(satPerVByte),
        feeInUsd: 0.0,
        estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
        details: {
          'satPerVByte': satPerVByte,
          'source': 'fallback',
        },
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      throw FeeApiException(
        'Failed to fetch Bitcoin fee from backup',
        blockchain: blockchain,
        originalError: e,
      );
    }
  }

  @override
  String? validateFee(double feeInNative) {
    // Minimum fee: 2 sat/vB × 144 vBytes = 288 sats = 0.00000288 BTC
    const minFee = 0.00000288;
    // Maximum reasonable fee: 1000 sat/vB × 144 vBytes = ~0.00144 BTC
    const maxFee = 0.00144;

    if (feeInNative < minFee) {
      return 'Fee too low. Minimum: $minFee BTC';
    }
    if (feeInNative > maxFee) {
      return 'Fee too high. Maximum: $maxFee BTC';
    }
    return null;
  }

  /// Get sat/vByte for selected speed from mempool.space response
  int _getSatPerVByteForSpeed(Map<String, dynamic> data, FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast => data['fastestFee'] as int? ?? 20,
      FeeSpeed.normal => data['halfHourFee'] as int? ?? 10,
      FeeSpeed.slow => data['hourFee'] as int? ?? 5,
    };
  }

  /// Calculate fee in BTC from sat/vByte
  /// 1 P2WPKH input + 2 outputs (P2PKH recipient + P2WPKH change):
  ///   overhead 11 + input 68 + P2PKH output 34 + P2WPKH change 31 = 144 vBytes
  double _calculateFeeInBTC(int satPerVByte) {
    const avgTxSize = 144; // vBytes — P2WPKH 1-in/2-out (BIP141 weight formula)
    final totalSats = satPerVByte * avgTxSize;
    return totalSats / 100000000; // Convert satoshis to BTC
  }

  /// Get estimated confirmation time for speed
  String _getEstimatedTime(FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast => '~10 min',
      FeeSpeed.normal => '~30 min',
      FeeSpeed.slow => '~60 min',
    };
  }

  /// Fallback sat/vByte values when API fails
  int _getFallbackSatPerVByte(FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast => 20,
      FeeSpeed.normal => 10,
      FeeSpeed.slow => 5,
    };
  }
}
