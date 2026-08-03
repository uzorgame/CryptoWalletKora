import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kora/core/config/api_config.dart';

/// Bitcoin Service using BlockCypher API
/// Provides methods for interacting with Bitcoin blockchain
class BitcoinService {
  final String _apiUrl;
  final String? _apiToken;
  final bool _testnet;
  
  BitcoinService({
    bool testnet = false,
    String? apiToken,
  })  : _testnet = testnet,
        _apiToken = apiToken,
        _apiUrl = testnet
          ? APIConfig.blockcypherBtcTestnet
          : APIConfig.blockcypherEndpoints['bitcoin']!;
  
  /// Get balance in satoshis
  Future<int> getBalance(String address) async {
    final url = _buildUrl('/addrs/$address/balance');
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['balance'] as int;
    }
    throw BitcoinServiceException('Failed to get balance: ${response.statusCode}');
  }
  
  /// Get balance in BTC
  Future<double> getBalanceInBTC(String address) async {
    final satoshis = await getBalance(address);
    return satoshis / 100000000; // 1 BTC = 100,000,000 satoshis
  }
  
  /// Get unconfirmed balance in satoshis
  Future<int> getUnconfirmedBalance(String address) async {
    final url = _buildUrl('/addrs/$address/balance');
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['unconfirmed_balance'] as int;
    }
    throw BitcoinServiceException('Failed to get unconfirmed balance: ${response.statusCode}');
  }
  
  /// Get total balance (confirmed + unconfirmed) in satoshis
  Future<int> getTotalBalance(String address) async {
    final url = _buildUrl('/addrs/$address/balance');
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['final_balance'] as int;
    }
    throw BitcoinServiceException('Failed to get total balance: ${response.statusCode}');
  }
  
  /// Get UTXOs (Unspent Transaction Outputs)
  Future<List<UTXO>> getUTXOs(String address) async {
    final url = _buildUrl('/addrs/$address?unspentOnly=true');
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final txrefs = data['txrefs'] as List? ?? [];
      
      return txrefs.map((tx) => UTXO.fromJson(tx)).toList();
    }
    throw BitcoinServiceException('Failed to get UTXOs: ${response.statusCode}');
  }
  
  /// Send raw transaction
  Future<String> sendTransaction(String signedTxHex) async {
    final url = _buildUrl('/txs/push');
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'tx': signedTxHex}),
    );
    
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['tx']['hash'];
    }
    throw BitcoinServiceException('Failed to send transaction: ${response.body}');
  }
  
  /// Get transaction details
  Future<BitcoinTransaction> getTransaction(String txHash) async {
    final url = _buildUrl('/txs/$txHash');
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return BitcoinTransaction.fromJson(data);
    }
    throw BitcoinServiceException('Failed to get transaction: ${response.statusCode}');
  }
  
  /// Get transaction history for address
  Future<List<BitcoinTransaction>> getTransactionHistory(
    String address, {
    int limit = 50,
  }) async {
    final url = _buildUrl('/addrs/$address/full?limit=$limit');
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final txs = data['txs'] as List? ?? [];
      
      return txs.map((tx) => BitcoinTransaction.fromJson(tx)).toList();
    }
    throw BitcoinServiceException('Failed to get transaction history: ${response.statusCode}');
  }
  
  /// Get current block height
  Future<int> getBlockHeight() async {
    final url = _buildUrl('');
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['height'] as int;
    }
    throw BitcoinServiceException('Failed to get block height: ${response.statusCode}');
  }
  
  /// Get block details
  Future<Map<String, dynamic>> getBlock(int height) async {
    final url = _buildUrl('/blocks/$height');
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw BitcoinServiceException('Failed to get block: ${response.statusCode}');
  }
  
  String _buildUrl(String path) {
    final token = _apiToken != null ? '?token=$_apiToken' : '';
    return '$_apiUrl$path$token';
  }
  
  /// Get network name
  String get network => _testnet ? 'testnet' : 'mainnet';
}

/// UTXO (Unspent Transaction Output) Model
class UTXO {
  final String txHash;
  final int outputIndex;
  final int value; // satoshis
  final String? scriptPubKey;
  final int confirmations;
  
  UTXO({
    required this.txHash,
    required this.outputIndex,
    required this.value,
    this.scriptPubKey,
    required this.confirmations,
  });
  
  factory UTXO.fromJson(Map<String, dynamic> json) {
    return UTXO(
      txHash: json['tx_hash'],
      outputIndex: json['tx_output_n'],
      value: json['value'],
      scriptPubKey: json['script'],
      confirmations: json['confirmations'] ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'tx_hash': txHash,
    'tx_output_n': outputIndex,
    'value': value,
    'script': scriptPubKey,
    'confirmations': confirmations,
  };
}

/// Bitcoin Transaction Model
class BitcoinTransaction {
  final String hash;
  final int blockHeight;
  final DateTime? confirmed;
  final int fees;
  final List<TransactionInput> inputs;
  final List<TransactionOutput> outputs;
  final int confirmations;
  
  BitcoinTransaction({
    required this.hash,
    required this.blockHeight,
    this.confirmed,
    required this.fees,
    required this.inputs,
    required this.outputs,
    required this.confirmations,
  });
  
  factory BitcoinTransaction.fromJson(Map<String, dynamic> json) {
    return BitcoinTransaction(
      hash: json['hash'],
      blockHeight: json['block_height'] ?? 0,
      confirmed: json['confirmed'] != null 
        ? DateTime.parse(json['confirmed'])
        : null,
      fees: json['fees'] ?? 0,
      inputs: (json['inputs'] as List? ?? [])
        .map((i) => TransactionInput.fromJson(i))
        .toList(),
      outputs: (json['outputs'] as List? ?? [])
        .map((o) => TransactionOutput.fromJson(o))
        .toList(),
      confirmations: json['confirmations'] ?? 0,
    );
  }
  
  /// Get total input value
  int get totalInput => inputs.fold(0, (sum, input) => sum + input.value);
  
  /// Get total output value
  int get totalOutput => outputs.fold(0, (sum, output) => sum + output.value);
  
  /// Is confirmed
  bool get isConfirmed => confirmations > 0;
}

/// Transaction Input
class TransactionInput {
  final String? prevHash;
  final int outputIndex;
  final int value;
  final List<String> addresses;
  
  TransactionInput({
    this.prevHash,
    required this.outputIndex,
    required this.value,
    required this.addresses,
  });
  
  factory TransactionInput.fromJson(Map<String, dynamic> json) {
    return TransactionInput(
      prevHash: json['prev_hash'],
      outputIndex: json['output_index'] ?? 0,
      value: json['output_value'] ?? 0,
      addresses: List<String>.from(json['addresses'] ?? []),
    );
  }
}

/// Transaction Output
class TransactionOutput {
  final int value;
  final List<String> addresses;
  final String? scriptPubKey;
  
  TransactionOutput({
    required this.value,
    required this.addresses,
    this.scriptPubKey,
  });
  
  factory TransactionOutput.fromJson(Map<String, dynamic> json) {
    return TransactionOutput(
      value: json['value'] ?? 0,
      addresses: List<String>.from(json['addresses'] ?? []),
      scriptPubKey: json['script'],
    );
  }
}

/// Bitcoin Service Exception
class BitcoinServiceException implements Exception {
  final String message;
  BitcoinServiceException(this.message);
  
  @override
  String toString() => 'BitcoinServiceException: $message';
}
