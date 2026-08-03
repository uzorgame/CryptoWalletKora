import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:kora/core/config/api_config.dart';

/// Solana Service for blockchain interactions
/// Uses Solana JSON RPC API
class SolanaService {
  final String _rpcUrl;
  final bool _devnet;

  static const _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
  ];

  SolanaService({bool devnet = false})
      : _devnet = devnet,
        _rpcUrl = devnet
            ? APIConfig.solanaDevnetRpc
            : APIConfig.solanaMainnetRpcDefault;
  
  /// Get SOL balance in lamports
  Future<int> getBalance(String address) async {
    final response = await _rpcCall('getBalance', [address]);
    return response['value'] as int;
  }
  
  /// Get SOL balance in SOL (1 SOL = 1,000,000,000 lamports)
  Future<double> getBalanceInSOL(String address) async {
    final lamports = await getBalance(address);
    return lamports / 1000000000;
  }
  
  /// Get account info
  Future<Map<String, dynamic>?> getAccountInfo(String address) async {
    final response = await _rpcCall('getAccountInfo', [
      address,
      {'encoding': 'jsonParsed'}
    ]);
    return response['value'];
  }
  
  /// Get transaction details
  Future<Map<String, dynamic>?> getTransaction(String signature) async {
    final response = await _rpcCall('getTransaction', [
      signature,
      {'encoding': 'jsonParsed'}
    ]);
    return response;
  }
  
  /// Get transaction history
  Future<List<String>> getTransactionHistory(
    String address, {
    int limit = 50,
  }) async {
    final response = await _rpcCall('getSignaturesForAddress', [
      address,
      {'limit': limit}
    ]);
    
    final signatures = response as List;
    return signatures.map((sig) => sig['signature'] as String).toList();
  }
  
  /// Get latest blockhash (replaces deprecated getRecentBlockhash)
  Future<String> getLatestBlockhash() async {
    final response = await _rpcCall('getLatestBlockhash', []);
    return response['value']['blockhash'];
  }

  /// Deprecated — use getLatestBlockhash() instead
  @Deprecated('Use getLatestBlockhash() instead')
  Future<String> getRecentBlockhash() => getLatestBlockhash();
  
  /// Get minimum balance for rent exemption
  Future<int> getMinimumBalanceForRentExemption(int dataLength) async {
    final response = await _rpcCall(
      'getMinimumBalanceForRentExemption',
      [dataLength],
    );
    return response as int;
  }
  
  /// High-level: build, sign and send a SOL transfer.
  /// [signer] is called with the serialized message bytes and must return
  /// a 64-byte Ed25519 signature (use SolanaWallet.signTransaction).
  Future<String> sendSOL({
    required String fromAddress,
    required String toAddress,
    required int lamports,
    required Uint8List Function(Uint8List) signer,
  }) async {
    final blockhash   = await getLatestBlockhash();
    final message     = _buildTransferMessage(fromAddress, toAddress, lamports, blockhash);
    final signature   = signer(message);
    final txBytes     = Uint8List(1 + 64 + message.length)
      ..[0] = 1                              // number of signatures
      ..setRange(1, 65, signature)           // 64-byte Ed25519 sig
      ..setRange(65, 65 + message.length, message);
    return sendTransaction(base64Encode(txBytes));
  }

  /// Builds a SOL SystemProgram.transfer message (without signatures)
  Uint8List _buildTransferMessage(
    String fromAddress,
    String toAddress,
    int lamports,
    String recentBlockhash,
  ) {
    final fromPubkey   = _base58Decode(fromAddress);
    final toPubkey     = _base58Decode(toAddress);
    final sysPubkey    = _base58Decode(SolanaConstants.systemProgramId);
    final blockhashBytes = _base58Decode(recentBlockhash);

    // Transfer instruction data: [2 (u32 LE), lamports (u64 LE)]
    final instrData = Uint8List(12)
      ..buffer.asByteData().setUint32(0, 2, Endian.little)
      ..buffer.asByteData().setInt64(4, lamports, Endian.little);

    final buf = BytesBuilder()
      // Header: [numRequiredSignatures=1, numReadonlySignedAccounts=0, numReadonlyUnsignedAccounts=1]
      ..add([1, 0, 1])
      // Account keys count (compact-u16 = 3)
      ..add([3])
      ..add(fromPubkey)
      ..add(toPubkey)
      ..add(sysPubkey)
      // Recent blockhash
      ..add(blockhashBytes)
      // Instructions count (compact-u16 = 1)
      ..add([1])
      // Instruction: program_id_index=2, accounts=[0,1], data
      ..addByte(2)                          // SystemProgram index
      ..add([2, 0, 1])                      // 2 accounts: indices 0, 1
      ..add(_compactU16(instrData.length))
      ..add(instrData);

    return buf.toBytes();
  }

  static Uint8List _base58Decode(String input) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var num = BigInt.zero;
    for (final c in input.runes) {
      final digit = alphabet.indexOf(String.fromCharCode(c));
      if (digit < 0) throw ArgumentError('Invalid Base58 char: $c');
      num = num * BigInt.from(58) + BigInt.from(digit);
    }
    var hex = num.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    final bytes = List<int>.generate(hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
    // Pad to 32 bytes
    while (bytes.length < 32) bytes.insert(0, 0);
    return Uint8List.fromList(bytes);
  }

  static Uint8List _compactU16(int n) {
    if (n < 0x80) return Uint8List.fromList([n]);
    return Uint8List.fromList([0x80 | (n & 0x7f), n >> 7]);
  }

  /// Send SPL token (e.g. USDC on Solana).
  /// Both sender and receiver must already have an associated token account
  /// for the given [mintAddress]. Throws [SolanaServiceException] otherwise.
  Future<String> sendSPLToken({
    required String fromAddress,
    required String toAddress,
    required String mintAddress,
    required BigInt amount,
    required Uint8List Function(Uint8List) signer,
  }) async {
    final srcAccounts = await getTokenAccountsByOwner(fromAddress, mintAddress);
    if (srcAccounts.isEmpty) {
      throw SolanaServiceException('Sender has no token account for this mint');
    }
    final dstAccounts = await getTokenAccountsByOwner(toAddress, mintAddress);
    if (dstAccounts.isEmpty) {
      throw SolanaServiceException(
          'Recipient has no token account. They need to receive SOL first.');
    }

    final sourceTokenAccount = srcAccounts.first['pubkey'] as String;
    final destTokenAccount   = dstAccounts.first['pubkey']  as String;

    final blockhash = await getLatestBlockhash();
    final message   = _buildSPLTransferMessage(
        fromAddress, sourceTokenAccount, destTokenAccount, amount, blockhash);
    final signature = signer(message);
    final txBytes   = Uint8List(1 + 64 + message.length)
      ..[0] = 1
      ..setRange(1, 65, signature)
      ..setRange(65, 65 + message.length, message);
    return sendTransaction(base64Encode(txBytes));
  }

  /// Build an unsigned SPL token Transfer message.
  Uint8List _buildSPLTransferMessage(
    String owner,
    String sourceTokenAccount,
    String destTokenAccount,
    BigInt amount,
    String recentBlockhash,
  ) {
    final ownerPubkey    = _base58Decode(owner);
    final sourcePubkey   = _base58Decode(sourceTokenAccount);
    final destPubkey     = _base58Decode(destTokenAccount);
    final tokenProgKey   = _base58Decode(SolanaConstants.tokenProgramId);
    final blockhashBytes = _base58Decode(recentBlockhash);

    // SPL Transfer instruction: code=3 (1 byte) + amount u64 LE (8 bytes)
    final instrData = Uint8List(9)..[0] = 3;
    instrData.setRange(1, 9, _bigIntToU64LE(amount));

    // Message layout:
    //   Header [1, 0, 1]: 1 required sig, 0 readonly signed, 1 readonly unsigned
    //   Accounts (4): owner(signer) | source | dest | tokenProgram(readonly)
    //   Blockhash (32 bytes)
    //   Instructions (1):
    //     program_id_index = 3 (tokenProgram)
    //     accounts = [3]: indices 1(source), 2(dest), 0(authority)
    //     data = instrData
    final buf = BytesBuilder()
      ..add([1, 0, 1])
      ..add([4])
      ..add(ownerPubkey)
      ..add(sourcePubkey)
      ..add(destPubkey)
      ..add(tokenProgKey)
      ..add(blockhashBytes)
      ..add([1])
      ..addByte(3)
      ..add([3, 1, 2, 0])
      ..add(_compactU16(instrData.length))
      ..add(instrData);
    return buf.toBytes();
  }

  /// Encode [n] as an 8-byte little-endian unsigned integer.
  static Uint8List _bigIntToU64LE(BigInt n) {
    final bytes = Uint8List(8);
    var v = n;
    for (var i = 0; i < 8; i++) {
      bytes[i] = (v & BigInt.from(0xff)).toInt();
      v >>= 8;
    }
    return bytes;
  }

  /// Send transaction
  Future<String> sendTransaction(String signedTransaction) async {
    final response = await _rpcCall('sendTransaction', [
      signedTransaction,
      {'encoding': 'base64'}
    ]);
    return response as String;
  }
  
  /// Get current slot
  Future<int> getSlot() async {
    final response = await _rpcCall('getSlot', []);
    return response as int;
  }
  
  /// Get block height
  Future<int> getBlockHeight() async {
    final response = await _rpcCall('getBlockHeight', []);
    return response as int;
  }
  
  /// Get epoch info
  Future<Map<String, dynamic>> getEpochInfo() async {
    final response = await _rpcCall('getEpochInfo', []);
    return response;
  }
  
  /// Get token accounts by owner
  Future<List<Map<String, dynamic>>> getTokenAccountsByOwner(
    String ownerAddress,
    String mintAddress,
  ) async {
    final response = await _rpcCall('getTokenAccountsByOwner', [
      ownerAddress,
      {'mint': mintAddress},
      {'encoding': 'jsonParsed'}
    ]);
    
    final accounts = response['value'] as List;
    return accounts.map((acc) => acc as Map<String, dynamic>).toList();
  }
  
  /// Get SPL token balance
  Future<double> getTokenBalance(
    String tokenAccountAddress,
  ) async {
    final response = await _rpcCall('getTokenAccountBalance', [
      tokenAccountAddress,
    ]);
    
    final uiAmount = response['value']['uiAmount'];
    return (uiAmount as num).toDouble();
  }
  
  /// Make RPC call; retries up to 3× on HTTP 429 with increasing delays.
  Future<dynamic> _rpcCall(String method, List<dynamic> params) async {
    final url = _devnet
        ? APIConfig.solanaDevnetRpc
        : APIConfig.solanaMainnetRpc;

    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': method,
      'params': params,
    });
    const headers = {'Content-Type': 'application/json'};

    for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
      final response = await http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 429) {
        if (attempt < _retryDelays.length) {
          await Future<void>.delayed(_retryDelays[attempt]);
          continue;
        }
        throw SolanaServiceException('HTTP Error: 429 (rate limited)');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] != null) {
          throw SolanaServiceException(
              'RPC Error: ${data['error']['message']}');
        }
        return data['result'];
      }

      throw SolanaServiceException('HTTP Error: ${response.statusCode}');
    }

    throw SolanaServiceException('HTTP Error: 429 (rate limited)');
  }
  
  /// Get network name
  String get network => _devnet ? 'devnet' : 'mainnet-beta';
  
  /// Get RPC URL
  String get rpcUrl => _rpcUrl;
}

/// Solana Service Exception
class SolanaServiceException implements Exception {
  final String message;
  SolanaServiceException(this.message);
  
  @override
  String toString() => 'SolanaServiceException: $message';
}

/// Solana Constants
class SolanaConstants {
  /// Lamports per SOL
  static const int lamportsPerSol = 1000000000;
  
  /// System Program ID
  static const String systemProgramId = '11111111111111111111111111111111';
  
  /// Token Program ID
  static const String tokenProgramId = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
  
  /// Associated Token Program ID
  static const String associatedTokenProgramId = 'ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL';
}
