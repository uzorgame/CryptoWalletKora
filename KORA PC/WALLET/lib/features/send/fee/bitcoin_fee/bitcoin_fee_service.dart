import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kora_windows/core/config/api_config.dart';
import '../models/fee_estimate.dart';
import '../services/fee_api_service.dart';

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
        final satPerVByte = _getSatPerVByteForSpeed(data, speed ?? FeeSpeed.normal);
        return FeeEstimate(
          blockchain: blockchain,
          speed: speed ?? FeeSpeed.normal,
          feeInNative: _calculateFeeInBTC(satPerVByte),
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
      throw FeeApiException('Failed to fetch Bitcoin fee', blockchain: blockchain, originalError: e);
    }
  }

  @override
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false}) async {
    final satPerVByte = _getFallbackSatPerVByte(speed ?? FeeSpeed.normal);
    return FeeEstimate(
      blockchain: blockchain,
      speed: speed ?? FeeSpeed.normal,
      feeInNative: _calculateFeeInBTC(satPerVByte),
      feeInUsd: 0.0,
      estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
      details: {'satPerVByte': satPerVByte, 'source': 'fallback'},
      fetchedAt: DateTime.now(),
    );
  }

  @override
  String? validateFee(double feeInNative) => null;

  int _getSatPerVByteForSpeed(Map<String, dynamic> data, FeeSpeed speed) => switch (speed) {
        FeeSpeed.fast   => data['fastestFee']  as int? ?? 20,
        FeeSpeed.normal => data['halfHourFee'] as int? ?? 10,
        FeeSpeed.slow   => data['hourFee']     as int? ?? 5,
      };

  double _calculateFeeInBTC(int satPerVByte) => satPerVByte * 144 / 100000000;

  String _getEstimatedTime(FeeSpeed speed) => switch (speed) {
        FeeSpeed.fast   => '~10 min',
        FeeSpeed.normal => '~30 min',
        FeeSpeed.slow   => '~60 min',
      };

  int _getFallbackSatPerVByte(FeeSpeed speed) => switch (speed) {
        FeeSpeed.fast   => 20,
        FeeSpeed.normal => 10,
        FeeSpeed.slow   => 5,
      };
}
