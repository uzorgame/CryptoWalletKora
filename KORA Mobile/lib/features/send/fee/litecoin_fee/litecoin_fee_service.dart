import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kora/core/config/api_config.dart';
import '../models/fee_estimate.dart';
import '../services/fee_api_service.dart';

/// Litecoin Fee Service (similar to Bitcoin)
class LitecoinFeeService extends FeeApiService {
  @override
  String get blockchain => 'litecoin';

  @override
  bool get supportsVariableFees => true;

  @override
  Future<FeeEstimate?> fetchFee({FeeSpeed? speed, bool isToken = false}) async {
    try {
      final response = await http
          .get(Uri.parse(APIConfig.mempoolSpaceLtcFee))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final satPerVByte = _getSatPerVByteForSpeed(data, speed ?? FeeSpeed.normal);
        
        return FeeEstimate(
          blockchain: blockchain,
          speed: speed ?? FeeSpeed.normal,
          feeInNative: _calculateFeeInLTC(satPerVByte),
          feeInUsd: 0.0,
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
      throw FeeApiException('Failed to fetch Litecoin fee', blockchain: blockchain, originalError: e);
    }
  }

  @override
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false}) async {
    final satPerVByte = _getFallbackSatPerVByte(speed ?? FeeSpeed.normal);
    return FeeEstimate(
      blockchain: blockchain,
      speed: speed ?? FeeSpeed.normal,
      feeInNative: _calculateFeeInLTC(satPerVByte),
      feeInUsd: 0.0,
      estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
      details: {'satPerVByte': satPerVByte, 'source': 'fallback'},
      fetchedAt: DateTime.now(),
    );
  }

  @override
  String? validateFee(double feeInNative) {
    const minFee = 0.000001;
    const maxFee = 0.001;
    if (feeInNative < minFee) return 'Fee too low. Minimum: $minFee LTC';
    if (feeInNative > maxFee) return 'Fee too high. Maximum: $maxFee LTC';
    return null;
  }

  int _getSatPerVByteForSpeed(Map<String, dynamic> data, FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast => data['fastestFee'] as int? ?? 15,
      FeeSpeed.normal => data['halfHourFee'] as int? ?? 8,
      FeeSpeed.slow => data['hourFee'] as int? ?? 3,
    };
  }

  double _calculateFeeInLTC(int satPerVByte) {
    const avgTxSize = 144; // 11 overhead + 68 P2WPKH input + 34 P2PKH output + 31 P2WPKH change
    final totalSats = satPerVByte * avgTxSize;
    return totalSats / 100000000;
  }

  String _getEstimatedTime(FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast => '~2.5 min',
      FeeSpeed.normal => '~7.5 min',
      FeeSpeed.slow => '~15 min',
    };
  }

  int _getFallbackSatPerVByte(FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast => 15,
      FeeSpeed.normal => 8,
      FeeSpeed.slow => 3,
    };
  }
}
