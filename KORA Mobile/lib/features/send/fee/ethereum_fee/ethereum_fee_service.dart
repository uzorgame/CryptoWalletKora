import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:kora/core/config/api_config.dart';
import '../models/fee_estimate.dart';
import '../services/fee_api_service.dart';

/// Ethereum Fee Service
/// Fetches real-time gas prices using eth_gasPrice RPC method
/// Backup: Etherscan Gas Oracle API
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
      debugPrint('[FEE][$_blockchain] fetchFee START (speed: ${speed?.name ?? 'null'})');
      final rpcUrl = APIConfig.getEvmRpcUrl(_blockchain);
      debugPrint('[FEE][$_blockchain] RPC URL: $rpcUrl');
      
      if (rpcUrl == null) {
        debugPrint('[FEE][$_blockchain] ERROR: No RPC URL configured');
        return null;
      }

      debugPrint('[FEE][$_blockchain] Creating Web3Client...');
      final client = Web3Client(rpcUrl, http.Client());
      
      // Get current gas price
      debugPrint('[FEE][$_blockchain] Calling getGasPrice()...');
      final gasPrice = await client.getGasPrice().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[FEE][$_blockchain] ERROR: getGasPrice() timeout after 15s');
          throw Exception('getGasPrice timeout');
        },
      );
      debugPrint('[FEE][$_blockchain] Gas price received: ${gasPrice.getInWei} Wei');
      // Convert Wei to Gwei: 1 Gwei = 1,000,000 Wei (NOT 1 billion!)
      final gasPriceGwei = gasPrice.getInWei / BigInt.from(1000000);
      debugPrint('[FEE][$_blockchain] Gas price in Gwei: $gasPriceGwei');
      
      // Adjust gas price based on speed
      final adjustedGasPrice = _adjustGasPriceForSpeed(gasPriceGwei.toDouble(), speed ?? FeeSpeed.normal);
      debugPrint('[FEE][$_blockchain] Adjusted gas price: $adjustedGasPrice Gwei');
      
      // Gas limit: 21000 for native ETH transfer, 65000 for ERC-20 token transfer
      final gasLimit = isToken ? 65000 : 21000;
      
      // Calculate fee in ETH
      // Gwei to Wei: multiply by 1,000,000
      // Wei to ETH: divide by 1,000,000,000,000,000,000
      final feeInWei = adjustedGasPrice * gasLimit * 1000000; // Convert Gwei to Wei
      final feeInEth = feeInWei / 1000000000000000000; // Convert Wei to ETH
      debugPrint('[FEE][$_blockchain] Calculated fee: $feeInEth ETH');
      
      client.dispose();
      
      final estimate = FeeEstimate(
        blockchain: blockchain,
        speed: speed ?? FeeSpeed.normal,
        feeInNative: feeInEth,
        feeInUsd: 0.0, // Will be calculated by provider
        estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
        details: {
          'gasPriceGwei': adjustedGasPrice,
          'gasLimit': gasLimit,
          'source': 'rpc',
        },
        fetchedAt: DateTime.now(),
      );
      debugPrint('[FEE][$_blockchain] fetchFee SUCCESS');
      return estimate;
    } catch (e, stack) {
      debugPrint('[FEE][$_blockchain] fetchFee ERROR: $e');
      debugPrint('[FEE][$_blockchain] Stack trace: $stack');
      throw FeeApiException(
        'Failed to fetch $_blockchain fee from RPC',
        blockchain: blockchain,
        originalError: e,
      );
    }
  }

  @override
  Future<FeeEstimate?> fetchFeeFromBackup({FeeSpeed? speed, bool isToken = false}) async {
    try {
      final url = APIConfig.etherscanGasOracle(_blockchain);
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == '1' && data['result'] != null) {
          final result = data['result'] as Map<String, dynamic>;
          
          // Etherscan returns: SafeGasPrice, ProposeGasPrice, FastGasPrice (in Gwei)
          final gasPriceGwei = _getGasPriceForSpeed(result, speed ?? FeeSpeed.normal);
          
          final gasLimit = isToken ? 65000 : 21000;
          // Gwei to Wei: multiply by 1,000,000 (NOT 1 billion!)
          final feeInWei = gasPriceGwei * gasLimit * 1000000;
          final feeInEth = feeInWei / 1000000000000000000;
          
          return FeeEstimate(
            blockchain: blockchain,
            speed: speed ?? FeeSpeed.normal,
            feeInNative: feeInEth,
            feeInUsd: 0.0,
            estimatedTime: _getEstimatedTime(speed ?? FeeSpeed.normal),
            details: {
              'gasPriceGwei': gasPriceGwei,
              'gasLimit': gasLimit,
              'source': 'etherscan',
              'safeGasPrice': result['SafeGasPrice'],
              'proposeGasPrice': result['ProposeGasPrice'],
              'fastGasPrice': result['FastGasPrice'],
            },
            fetchedAt: DateTime.now(),
          );
        }
      }
      return null;
    } catch (e) {
      throw FeeApiException(
        'Failed to fetch $_blockchain fee from Etherscan',
        blockchain: blockchain,
        originalError: e,
      );
    }
  }

  @override
  String? validateFee(double feeInNative) {
    // Minimum fee: ~1 Gwei * 21000 gas = 0.000021 ETH
    const minFee = 0.000021;
    // Maximum reasonable fee: ~500 Gwei * 21000 gas = 0.0105 ETH
    const maxFee = 0.0105;

    if (feeInNative < minFee) {
      return 'Fee too low. Minimum: $minFee ${_nativeSymbol()}';
    }
    if (feeInNative > maxFee) {
      return 'Fee too high. Maximum: $maxFee ${_nativeSymbol()}';
    }
    return null;
  }

  /// Adjust gas price based on speed (multiply by factor)
  double _adjustGasPriceForSpeed(double baseGasPrice, FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast => baseGasPrice * 1.5,
      FeeSpeed.normal => baseGasPrice,
      FeeSpeed.slow => baseGasPrice * 0.8,
    };
  }

  /// Get gas price from Etherscan response based on speed
  double _getGasPriceForSpeed(Map<String, dynamic> result, FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast => double.tryParse(result['FastGasPrice']?.toString() ?? '0') ?? 50.0,
      FeeSpeed.normal => double.tryParse(result['ProposeGasPrice']?.toString() ?? '0') ?? 30.0,
      FeeSpeed.slow => double.tryParse(result['SafeGasPrice']?.toString() ?? '0') ?? 20.0,
    };
  }

  /// Get estimated confirmation time
  String _getEstimatedTime(FeeSpeed speed) {
    return switch (speed) {
      FeeSpeed.fast => '~15 sec',
      FeeSpeed.normal => '~30 sec',
      FeeSpeed.slow => '~1 min',
    };
  }

  /// Get native token symbol
  String _nativeSymbol() {
    return switch (_blockchain) {
      'ethereum' => 'ETH',
      'bsc' => 'BNB',
      'ethereum_classic' => 'ETC',
      _ => 'ETH',
    };
  }
}
