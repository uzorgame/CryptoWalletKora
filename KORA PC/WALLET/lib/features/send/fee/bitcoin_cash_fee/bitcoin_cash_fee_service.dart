import '../models/fee_estimate.dart';
import '../services/fee_api_service.dart';

class BitcoinCashFeeService extends FeeApiService {
  @override
  String get blockchain => 'bitcoin_cash';
  @override
  bool get supportsVariableFees => true;

  @override
  Future<FeeEstimate?> fetchFee({FeeSpeed? speed, bool isToken = false}) async {
    final satPerVByte = _getSatPerVByteForSpeed(speed ?? FeeSpeed.normal);
    return FeeEstimate(
      blockchain: blockchain,
      speed: speed ?? FeeSpeed.normal,
      feeInNative: _calculateFeeInBCH(satPerVByte),
      feeInUsd: 0.0,
      estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
      details: {'satPerVByte': satPerVByte, 'source': 'estimate'},
      fetchedAt: DateTime.now(),
    );
  }

  @override
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false}) async =>
      fetchFee(speed: speed);

  @override
  String? validateFee(double feeInNative) => null;

  int _getSatPerVByteForSpeed(FeeSpeed speed) => switch (speed) {
        FeeSpeed.fast   => 5,
        FeeSpeed.normal => 2,
        FeeSpeed.slow   => 1,
      };

  double _calculateFeeInBCH(int satPerVByte) => satPerVByte * 226 / 100000000;

  String _getEstimatedTime(FeeSpeed speed) => switch (speed) {
        FeeSpeed.fast   => '~10 min',
        FeeSpeed.normal => '~20 min',
        FeeSpeed.slow   => '~60 min',
      };
}
