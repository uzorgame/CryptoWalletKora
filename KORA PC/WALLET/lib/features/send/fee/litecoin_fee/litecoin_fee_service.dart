import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kora_windows/core/config/api_config.dart';
import '../models/fee_estimate.dart';
import '../services/fee_api_service.dart';

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
          details: {'satPerVByte': satPerVByte},
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
  String? validateFee(double feeInNative) => null;

  int _getSatPerVByteForSpeed(Map<String, dynamic> data, FeeSpeed speed) => switch (speed) {
        FeeSpeed.fast   => data['fastestFee']  as int? ?? 15,
        FeeSpeed.normal => data['halfHourFee'] as int? ?? 8,
        FeeSpeed.slow   => data['hourFee']     as int? ?? 3,
      };

  double _calculateFeeInLTC(int satPerVByte) => satPerVByte * 144 / 100000000;

  String _getEstimatedTime(FeeSpeed speed) => switch (speed) {
        FeeSpeed.fast   => '~2.5 min',
        FeeSpeed.normal => '~7.5 min',
        FeeSpeed.slow   => '~15 min',
      };

  int _getFallbackSatPerVByte(FeeSpeed speed) => switch (speed) {
        FeeSpeed.fast   => 15,
        FeeSpeed.normal => 8,
        FeeSpeed.slow   => 3,
      };
}
