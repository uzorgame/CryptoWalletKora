import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart' as crypto;
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/utils/api_fallback.dart';

/// Tron Service for blockchain interactions
/// Uses TronGrid API (official Tron API)
class TronService {
  final List<String> _apiUrls;
  final String? _apiKey;
  final bool _testnet;
  
  TronService({
    bool testnet = false,
    String? apiKey,
  })  : _testnet = testnet,
        _apiKey = apiKey,
        _apiUrls = testnet
            ? [APIConfig.tronTestnetApi]
            : List<String>.from(APIConfig.tronMainnetApis);
  
  /// Get TRX balance in sun (1 TRX = 1,000,000 sun)
  Future<int> getBalance(String address) async {
    final response = await _post('/wallet/getaccount', {
      'address': address,
      'visible': true,
    });
    
    if (response['balance'] != null) {
      return response['balance'] as int;
    }
    return 0;
  }
  
  /// Get TRX balance in TRX
  Future<double> getBalanceInTRX(String address) async {
    final sun = await getBalance(address);
    return sun / 1000000;
  }
  
  /// Get account info
  Future<Map<String, dynamic>> getAccountInfo(String address) async {
    final response = await _post('/wallet/getaccount', {
      'address': address,
      'visible': true,
    });
    
    return response;
  }
  
  /// Get transaction by ID
  Future<Map<String, dynamic>?> getTransaction(String txId) async {
    try {
      final response = await _post('/wallet/gettransactionbyid', {
        'value': txId,
      });
      
      return response;
    } catch (e) {
      return null;
    }
  }
  
  /// Get transaction info (confirmed status)
  Future<Map<String, dynamic>?> getTransactionInfo(String txId) async {
    try {
      final response = await _post('/wallet/gettransactioninfobyid', {
        'value': txId,
      });
      
      return response;
    } catch (e) {
      return null;
    }
  }
  
  /// Get account transactions
  Future<List<Map<String, dynamic>>> getTransactions(
    String address, {
    int limit = 50,
  }) async {
    try {
      final response = await _get(
        '/v1/accounts/$address/transactions?limit=$limit',
      );
      
      final data = response['data'] as List? ?? [];
      return data.map((tx) => tx as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Get TRC20 token balance
  Future<BigInt> getTRC20Balance({
    required String contractAddress,
    required String ownerAddress,
  }) async {
    try {
      final response = await _post('/wallet/triggerconstantcontract', {
        'owner_address': ownerAddress,
        'contract_address': contractAddress,
        'function_selector': 'balanceOf(address)',
        'parameter': _encodeAddress(ownerAddress),
        'visible': true,
      });

      if (response['constant_result'] != null) {
        final result = (response['constant_result'][0] as String).trim();
        if (result.isEmpty) return BigInt.zero;
        return BigInt.parse(result, radix: 16);
      }

      return BigInt.zero;
    } catch (e) {
      return BigInt.zero;
    }
  }
  
  /// High-level: create, sign and broadcast a TRX transfer.
  /// [signer] receives the 32-byte SHA256 hash of the raw transaction bytes
  /// and must return a 64-byte ECDSA signature hex string
  /// (use TronWallet.signTransactionHash).
  Future<String> sendTRX({
    required String from,
    required String to,
    required int amount,
    required String Function(Uint8List) signer,
  }) async {
    // 1. Create unsigned transaction via TronGrid
    final txResponse = await _post('/wallet/createtransaction', {
      'owner_address': from,
      'to_address': to,
      'amount': amount,
      'visible': true,
    });

    // 2. SHA256 hash of raw_data_hex bytes → sign
    final rawDataHex = txResponse['raw_data_hex'] as String?;
    if (rawDataHex == null) {
      final errMsg = _extractTronError(txResponse);
      throw Exception('Tron createtransaction failed: $errMsg');
    }
    final rawBytes   = _hexDecode(rawDataHex);
    final txHash     = Uint8List.fromList(
        List<int>.from(_sha256(rawBytes)));
    final signatureHex = signer(txHash);

    // 3. Attach signature and broadcast
    final signedTx = <String, dynamic>{
      'txID':         txResponse['txID'],
      'raw_data':     txResponse['raw_data'],
      'raw_data_hex': txResponse['raw_data_hex'],
      'signature':    [signatureHex],
      'visible':      true,
    };

    return broadcastTransaction(signedTx);
  }

  /// High-level: create, sign and broadcast a TRC-20 token transfer.
  /// Uses ABI encoding for transfer(address,uint256).
  Future<String> sendTRC20({
    required String from,
    required String to,
    required String contractAddress,
    required BigInt amount,
    required String Function(Uint8List) signer,
  }) async {
    // ABI-encode transfer(address,uint256)
    final toHex    = _base58CheckTo20ByteHex(to);
    final toParam  = toHex.padLeft(64, '0');                          // 32 bytes
    final amtParam = amount.toRadixString(16).padLeft(64, '0');       // 32 bytes
    final parameter = '$toParam$amtParam';

    // Dry-run to get accurate energy estimate (accounts for cold-address SSTORE)
    final energyEstimate = await _estimateEnergy(
      from: from,
      contractAddress: contractAddress,
      functionSelector: 'transfer(address,uint256)',
      parameter: parameter,
    );
    final energyPrice = await _getEnergyPrice();
    // 1.3× buffer on dry-run estimate; clamp to [5 TRX, 40 TRX]
    final feeLimitSun = (energyEstimate * 1.3 * energyPrice)
        .round()
        .clamp(5000000, 40000000);

    final txResponse = await _post('/wallet/triggersmartcontract', {
      'owner_address':    from,
      'contract_address': contractAddress,
      'function_selector': 'transfer(address,uint256)',
      'parameter': parameter,
      'fee_limit': feeLimitSun,
      'call_value': 0,
      'visible': true,
    });

    final transaction = txResponse['transaction'] as Map<String, dynamic>?;
    if (transaction == null) {
      final errMsg = _extractTronError(txResponse);
      throw Exception('Tron triggersmartcontract failed: $errMsg');
    }
    final rawDataHex = transaction['raw_data_hex'] as String;
    final rawBytes   = _hexDecode(rawDataHex);
    final txHash     = Uint8List.fromList(List<int>.from(_sha256(rawBytes)));
    final sigHex     = signer(txHash);

    final signedTx = Map<String, dynamic>.from(transaction)
      ..['signature'] = [sigHex]
      ..['visible'] = true;

    final txId = await broadcastTransaction(signedTx);

    // Verify on-chain execution result (poll up to 5× every 3 s)
    await _checkTransactionResult(txId);

    return txId;
  }

  // ── private helpers ────────────────────────────────────────────────────────

  /// Dry-run a contract call and return the estimated energy consumed.
  Future<int> _estimateEnergy({
    required String from,
    required String contractAddress,
    required String functionSelector,
    required String parameter,
  }) async {
    try {
      final response = await _post('/wallet/triggerconstantcontract', {
        'owner_address':    from,
        'contract_address': contractAddress,
        'function_selector': functionSelector,
        'parameter': parameter,
        'visible': true,
      });
      return (response['energy_used'] as int?) ?? 65000;
    } catch (_) {
      return 65000;
    }
  }

  /// Fetch the current energy price (SUN per unit) from chain parameters.
  Future<int> _getEnergyPrice() async {
    try {
      final response = await _post('/wallet/getchainparameters', {});
      final params   = response['chainParameter'] as List?;
      if (params != null) {
        for (final p in params) {
          if ((p as Map)['key'] == 'getEnergyFee') {
            return (p['value'] as int?) ?? 420;
          }
        }
      }
    } catch (_) {}
    return 420;
  }

  /// Poll [txId] up to 5 times (3 s apart) and throw if the on-chain result
  /// is REVERT, OUT_OF_ENERGY, or any non-SUCCESS status.
  Future<void> _checkTransactionResult(String txId) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      await Future.delayed(const Duration(seconds: 3));
      final info = await getTransactionInfo(txId);
      if (info == null || info.isEmpty) continue;

      final receipt = info['receipt'] as Map<String, dynamic>?;
      final result  = receipt?['result'] as String?;
      if (result == null) continue; // not yet confirmed

      if (result == 'SUCCESS') return;

      final energyUsed = (receipt?['energy_usage_total'] as int?) ?? 0;
      throw TronServiceException(
        'Transaction confirmed but FAILED on-chain ($result). '
        'Energy consumed: $energyUsed units. '
        'TRX fee was charged but the transfer was not completed.',
      );
    }
    // Timeout — tx is pending, assume it will confirm
  }

  /// Decode a Base58Check address and return the 20-byte account ID as a hex string.
  /// Works for both Tron (T...) and Bitcoin-style addresses.
  static String _base58CheckTo20ByteHex(String address) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var num = BigInt.zero;
    for (final c in address.codeUnits) {
      final idx = alphabet.indexOf(String.fromCharCode(c));
      if (idx == -1) throw ArgumentError('Invalid Base58 char: ${String.fromCharCode(c)}');
      num = num * BigInt.from(58) + BigInt.from(idx);
    }
    final bytes = List<int>.filled(25, 0);
    for (var i = 24; i >= 0; i--) {
      bytes[i] = (num % BigInt.from(256)).toInt();
      num = num ~/ BigInt.from(256);
    }
    // bytes[0] = version (0x41 for Tron), bytes[1..20] = account ID
    return bytes
        .sublist(1, 21)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Broadcast a signed transaction map (from sendTRX or manual signing).
  Future<String> broadcastTransaction(Map<String, dynamic> signedTx) async {
    final response = await _post('/wallet/broadcasttransaction', signedTx);

    if (response['result'] == true) {
      return response['txid'] as String;
    }
    // TronGrid returns error messages as hex-encoded ASCII
    String errMsg = '${response['message'] ?? response}';
    try {
      final hex = response['message'] as String?;
      if (hex != null && hex.length > 2) {
        final bytes = List.generate(hex.length ~/ 2,
            (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
        errMsg = String.fromCharCodes(bytes);
      }
    } catch (_) {}
    throw TronServiceException('Broadcast failed: $errMsg');
  }

  static Uint8List _hexDecode(String hex) => Uint8List.fromList(
        List.generate(hex.length ~/ 2,
            (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));

  static Uint8List _sha256(Uint8List data) =>
      Uint8List.fromList(crypto.sha256.convert(data).bytes);
  
  /// Get current block number
  Future<int> getBlockNumber() async {
    final response = await _post('/wallet/getnowblock', {});
    
    if (response['block_header'] != null) {
      return response['block_header']['raw_data']['number'] as int;
    }
    
    return 0;
  }
  
  /// Get block by number
  Future<Map<String, dynamic>> getBlock(int blockNumber) async {
    final response = await _post('/wallet/getblockbynum', {
      'num': blockNumber,
    });
    
    return response;
  }
  
  /// Estimate energy for transaction
  Future<int> estimateEnergy({
    required String from,
    required String to,
    required int amount,
  }) async {
    // Tron uses energy and bandwidth instead of gas
    // Simple TRX transfer uses ~0 energy, only bandwidth
    // Smart contract calls use energy
    return 0; // TRX transfer
  }
  
  /// Get account resources (energy, bandwidth)
  Future<TronAccountResources> getAccountResources(String address) async {
    final response = await _post('/wallet/getaccountresource', {
      'address': address,
      'visible': true,
    });
    
    return TronAccountResources.fromJson(response);
  }
  
  /// Make POST request with fallback URLs
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    return tryWithFallbacks(_apiUrls, (base) async {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (_apiKey != null) 'TRON-PRO-API-KEY': _apiKey!,
      };
      final response = await http.post(
        Uri.parse('$base$path'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      throw TronServiceException('HTTP ${response.statusCode}: ${response.body}');
    });
  }
  
  /// Make GET request with fallback URLs
  Future<Map<String, dynamic>> _get(String path) async {
    return tryWithFallbacks(_apiUrls, (base) async {
      final headers = <String, String>{
        if (_apiKey != null) 'TRON-PRO-API-KEY': _apiKey!,
      };
      final response = await http.get(
        Uri.parse('$base$path'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      throw TronServiceException('HTTP ${response.statusCode}: ${response.body}');
    });
  }
  
  /// Encode a Tron Base58Check address as a 32-byte ABI parameter (left-padded).
  String _encodeAddress(String address) {
    final hex20 = _base58CheckTo20ByteHex(address);
    return hex20.padLeft(64, '0');
  }
  
  /// Get network name
  String get network => _testnet ? 'shasta' : 'mainnet';

  /// Extracts a human-readable error message from a Tron API error response.
  String _extractTronError(Map<String, dynamic> response) {
    try {
      final result = response['result'] as Map<String, dynamic>?;
      if (result != null) {
        final msg = result['message'] as String?;
        if (msg != null && msg.isNotEmpty) {
          // message is hex-encoded ASCII
          final bytes = List<int>.generate(
            msg.length ~/ 2,
            (i) => int.parse(msg.substring(i * 2, i * 2 + 2), radix: 16),
          );
          return String.fromCharCodes(bytes);
        }
        final code = result['code'];
        if (code != null) return 'Error code: $code';
      }
      final error = response['Error'] as String?;
      if (error != null) return error;
    } catch (_) {}
    return 'Unknown error — API response: $response';
  }
}

/// Tron Account Resources
class TronAccountResources {
  final int freeNetLimit;
  final int freeNetUsed;
  final int netLimit;
  final int netUsed;
  final int energyLimit;
  final int energyUsed;
  
  TronAccountResources({
    required this.freeNetLimit,
    required this.freeNetUsed,
    required this.netLimit,
    required this.netUsed,
    required this.energyLimit,
    required this.energyUsed,
  });
  
  factory TronAccountResources.fromJson(Map<String, dynamic> json) {
    return TronAccountResources(
      freeNetLimit: json['freeNetLimit'] ?? 0,
      freeNetUsed: json['freeNetUsed'] ?? 0,
      netLimit: json['NetLimit'] ?? 0,
      netUsed: json['NetUsed'] ?? 0,
      energyLimit: json['EnergyLimit'] ?? 0,
      energyUsed: json['EnergyUsed'] ?? 0,
    );
  }
  
  /// Get available bandwidth
  int get availableBandwidth => (freeNetLimit - freeNetUsed) + (netLimit - netUsed);
  
  /// Get available energy
  int get availableEnergy => energyLimit - energyUsed;
}

/// Tron Service Exception
class TronServiceException implements Exception {
  final String message;
  TronServiceException(this.message);
  
  @override
  String toString() => 'TronServiceException: $message';
}

/// Tron Constants
class TronConstants {
  /// Sun per TRX
  static const int sunPerTrx = 1000000;
  
  /// Bandwidth for simple transfer
  static const int transferBandwidth = 268;
  
  /// Convert TRX to sun
  static int trxToSun(double trx) {
    return (trx * sunPerTrx).round();
  }
  
  /// Convert sun to TRX
  static double sunToTrx(int sun) {
    return sun / sunPerTrx;
  }
}

/// Popular TRC20 Token Addresses (Mainnet)
class TRC20Tokens {
  // Stablecoins
  static const String usdt = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t';
  static const String usdc = 'TEkxiTehnzSmSe2XqrBj4w32RUN966rdz8';
  static const String tusd = 'TUpMhErZL2fhh4sVNULAbNKLokS4GjC1F4';
  
  // Wrapped Tokens
  static const String wbtc = 'TXpw8XeWYeTUd4quDskoUqeQPowRh4jY65';
  static const String weth = 'TXWkP3jLBqRGojUih1ShzNyDaN5Csnebok';
  
  /// Get token address by symbol
  static String? getAddressBySymbol(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'USDT':
        return usdt;
      case 'USDC':
        return usdc;
      case 'TUSD':
        return tusd;
      case 'WBTC':
        return wbtc;
      case 'WETH':
        return weth;
      default:
        return null;
    }
  }
}
