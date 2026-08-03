import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

/// Transaction model - represents a blockchain transaction
@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required String hash,
    required String blockchain,
    required String from,
    required String to,
    required String amount, // String to avoid precision loss
    required String symbol,
    required TransactionType type,
    required TransactionStatus status,
    required DateTime timestamp,
    int? blockNumber,
    String? gasUsed,
    String? gasFee,
    String? nonce,
    String? data,
    String? contractAddress, // For token transfers
    String? errorMessage,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) => 
      _$TransactionFromJson(json);
}

enum TransactionType {
  @JsonValue('send')
  send,
  
  @JsonValue('receive')
  receive,
  
  @JsonValue('swap')
  swap,
  
  @JsonValue('contract')
  contract,
}

enum TransactionStatus {
  @JsonValue('pending')
  pending,
  
  @JsonValue('confirmed')
  confirmed,
  
  @JsonValue('failed')
  failed,
}

extension TransactionExtension on Transaction {
  /// Get formatted amount
  String get formattedAmount {
    final value = double.tryParse(amount) ?? 0.0;
    if (value == 0) return '0 $symbol';
    if (value < 0.000001) return '< 0.000001 $symbol';
    if (value < 1) return '${value.toStringAsFixed(6)} $symbol';
    if (value < 1000) return '${value.toStringAsFixed(4)} $symbol';
    return '${value.toStringAsFixed(2)} $symbol';
  }
  
  /// Get short hash (first 6 + last 4 chars)
  String get shortHash {
    if (hash.length <= 10) return hash;
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
  }
  
  /// Get short address
  String shortAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
  
  /// Check if transaction is outgoing
  bool isOutgoing(String myAddress) {
    return from.toLowerCase() == myAddress.toLowerCase();
  }
  
  /// Get status color
  String get statusColor {
    switch (status) {
      case TransactionStatus.pending:
        return '#FFA500'; // Orange
      case TransactionStatus.confirmed:
        return '#4CAF50'; // Green
      case TransactionStatus.failed:
        return '#F44336'; // Red
    }
  }
  
  /// Get type icon
  String get typeIcon {
    switch (type) {
      case TransactionType.send:
        return '↑';
      case TransactionType.receive:
        return '↓';
      case TransactionType.swap:
        return '⇄';
      case TransactionType.contract:
        return '📄';
    }
  }
}
