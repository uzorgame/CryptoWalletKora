import 'dart:typed_data';
import 'package:kora_windows/core/models/asset.dart';

Uint8List bigIntTo32Bytes(BigInt n) {
  final result = Uint8List(32);
  var val = n;
  for (var i = 31; i >= 0; i--) {
    result[i] = (val & BigInt.from(0xff)).toInt();
    val >>= 8;
  }
  return result;
}

BigInt bytesToBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (final b in bytes) result = (result << 8) | BigInt.from(b);
  return result;
}

BigInt toTokenAmount(String amountStr, int decimals) {
  final parts = amountStr.split('.');
  final whole = parts[0].isEmpty ? '0' : parts[0];
  final frac  = parts.length > 1 ? parts[1] : '';
  final fracPadded = frac.padRight(decimals, '0').substring(0, decimals);
  return BigInt.parse('$whole$fracPadded');
}

abstract class TransactionExecutor {
  String get blockchain;
  String? validateAddress(String address);
  Future<String> execute({
    required String mnemonic,
    required Asset asset,
    required String toAddress,
    required String amount,
  });
}
