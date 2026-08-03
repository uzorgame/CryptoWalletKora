import '../models/fee_estimate.dart';
import '../services/fee_api_service.dart';

/// Bitcoin Cash Fee Service
class BitcoinCashFeeService extends FeeApiService {
  @override
  String get blockchain => 'bitcoin_cash';

  @override
  bool get supportsVariableFees => true;

  @override
  Future<FeeEstimate?> fetchFee({FeeSpeed? speed, bool isToken = false}) async {
    // BCH has very low fees, use conservative estimates
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
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false}) async {
    return fetchFee(speed: speed);
  }

  @override
  String? validateFee(double feeInNative) {
    const minFee = 0.00000001;
    const maxFee = 0.0001;
    if (feeInNative < minFee) return 'Fee too low. Minimum: $minFee BCH';
    if (feeInNative > maxFee) return 'Fee too high. Maximum: $maxFee BCH';
    return null;
  }

  int _getSatPerVByteForSpeed(FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast   => 5, // confirmed next block
      FeeSpeed.normal => 2, // confirmed within a few blocks
      FeeSpeed.slow   => 1, // low-priority, BCH mempool is usually near-empty
    };
  }

  double _calculateFeeInBCH(int satPerVByte) {
    // P2PKH: 10 overhead + 148 input + 34 recipient output + 34 change output = 226 bytes
    const avgTxSize = 226;
    final totalSats = satPerVByte * avgTxSize;
    return totalSats / 100000000;
  }

  String _getEstimatedTime(FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast   => '~10 min',
      FeeSpeed.normal => '~20 min',
      FeeSpeed.slow   => '~60 min',
    };
  }
}
