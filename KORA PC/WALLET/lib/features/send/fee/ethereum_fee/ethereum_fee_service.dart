import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:kora_windows/core/config/api_config.dart';
import '../models/fee_estimate.dart';
import '../services/fee_api_service.dart';

class EthereumFeeService extends FeeApiService {
  final String _blockchain;
  EthereumFeeService([this._blockchain = 'ethereum']);

  @override
  String get blockchain => _blockchain;
  @override
  bool get supportsVariableFees => true;

  @override
  Future<FeeEstimate?> fetchFee({FeeSpeed? speed, bool isToken = false}) async {
    try {
      final rpcUrl = APIConfig.getEvmRpcUrl(_blockchain);
      if (rpcUrl == null) return null;
      final client = Web3Client(rpcUrl, http.Client());
      final gasPrice = await client.getGasPrice().timeout(const Duration(seconds: 15));
      final gasPriceGwei = gasPrice.getInWei / BigInt.from(1000000);
      final adjustedGasPrice = _adjustForSpeed(gasPriceGwei.toDouble(), speed ?? FeeSpeed.normal);
      final gasLimit = isToken ? 65000 : 21000;
      final feeInWei = adjustedGasPrice * gasLimit * 1000000;
      final feeInEth = feeInWei / 1000000000000000000;
      client.dispose();
      return FeeEstimate(
        blockchain: blockchain,
        speed: speed ?? FeeSpeed.normal,
        feeInNative: feeInEth,
        feeInUsd: 0.0,
        estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
        details: {'gasPriceGwei': adjustedGasPrice, 'gasLimit': gasLimit, 'source': 'rpc'},
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      throw FeeApiException('Failed to fetch $blockchain fee', blockchain: _blockchain, originalError: e);
    }
  }

  @override
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false}) async {
    try {
      final gasLimit = isToken ? 65000 : 21000;
      final gasPriceGwei = _getFallbackGasPrice(_blockchain, speed ?? FeeSpeed.normal);
      final feeInEth = gasPriceGwei * gasLimit * 1000000 / 1000000000000000000;
      return FeeEstimate(
        blockchain: blockchain,
        speed: speed ?? FeeSpeed.normal,
        feeInNative: feeInEth,
        feeInUsd: 0.0,
        estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
        details: {'gasPriceGwei': gasPriceGwei, 'gasLimit': gasLimit, 'source': 'fallback'},
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      throw FeeApiException('Failed to fetch $blockchain backup fee', blockchain: _blockchain, originalError: e);
    }
  }

  @override
  String? validateFee(double feeInNative) => null;

  double _adjustForSpeed(double gasPriceGwei, FeeSpeed speed) => switch (speed) {
        FeeSpeed.fast   => gasPriceGwei * 1.2,
        FeeSpeed.normal => gasPriceGwei,
        FeeSpeed.slow   => gasPriceGwei * 0.8,
      };

  double _getFallbackGasPrice(String blockchain, FeeSpeed speed) {
    final base = switch (blockchain) {
      'bsc'               => 3.0,
      'ethereum_classic'  => 1.0,
      _                   => 20.0,
    };
    return switch (speed) {
      FeeSpeed.fast   => base * 1.5,
      FeeSpeed.normal => base,
      FeeSpeed.slow   => base * 0.7,
    };
  }

  String _getEstimatedTime(FeeSpeed speed) => switch (speed) {
        FeeSpeed.fast   => '~15 sec',
        FeeSpeed.normal => '~1 min',
        FeeSpeed.slow   => '~3 min',
      };
}
