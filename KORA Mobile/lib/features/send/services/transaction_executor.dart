import 'dart:typed_data';
import 'package:kora/core/models/asset.dart';

/// Converts a [BigInt] to a fixed 32-byte big-endian [Uint8List].
/// Shared by multiple executors.
Uint8List bigIntTo32Bytes(BigInt n) {
  final result = Uint8List(32);
  var val = n;
  for (var i = 31; i >= 0; i--) {
    result[i] = (val & BigInt.from(0xff)).toInt();
    val >>= 8;
  }
  return result;
}

/// Interprets a big-endian [Uint8List] as an unsigned [BigInt].
BigInt bytesToBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (final b in bytes) result = (result << 8) | BigInt.from(b);
  return result;
}

/// Shared utility used by every executor to convert a decimal string amount
/// (e.g. "1.5") to the smallest on-chain unit (e.g. 1500000 for 6 decimals).
BigInt toTokenAmount(String amountStr, int decimals) {
  final parts = amountStr.split('.');
  final whole = parts[0].isEmpty ? '0' : parts[0];
  final frac  = parts.length > 1 ? parts[1] : '';
  final fracPadded = frac.padRight(decimals, '0').substring(0, decimals);
  return BigInt.parse('$whole$fracPadded');
}

/// Base interface for blockchain transaction executors
abstract class TransactionExecutor {
  /// Blockchain identifier (e.g., 'ethereum', 'bitcoin', 'solana')
  String get blockchain;
  
  /// Validate recipient address format
  /// Returns null if valid, error message if invalid
  String? validateAddress(String address);
  
  /// Execute transaction and return transaction hash
  Future<String> execute({
    required String mnemonic,
    required Asset asset,
    required String toAddress,
    required String amount,
  });
}
