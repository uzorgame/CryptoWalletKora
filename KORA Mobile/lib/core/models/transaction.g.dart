// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TransactionImpl _$$TransactionImplFromJson(Map<String, dynamic> json) =>
    _$TransactionImpl(
      id: json['id'] as String,
      hash: json['hash'] as String,
      blockchain: json['blockchain'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      amount: json['amount'] as String,
      symbol: json['symbol'] as String,
      type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
      status: $enumDecode(_$TransactionStatusEnumMap, json['status']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      blockNumber: (json['blockNumber'] as num?)?.toInt(),
      gasUsed: json['gasUsed'] as String?,
      gasFee: json['gasFee'] as String?,
      nonce: json['nonce'] as String?,
      data: json['data'] as String?,
      contractAddress: json['contractAddress'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$$TransactionImplToJson(_$TransactionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'hash': instance.hash,
      'blockchain': instance.blockchain,
      'from': instance.from,
      'to': instance.to,
      'amount': instance.amount,
      'symbol': instance.symbol,
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'status': _$TransactionStatusEnumMap[instance.status]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'blockNumber': instance.blockNumber,
      'gasUsed': instance.gasUsed,
      'gasFee': instance.gasFee,
      'nonce': instance.nonce,
      'data': instance.data,
      'contractAddress': instance.contractAddress,
      'errorMessage': instance.errorMessage,
    };

const _$TransactionTypeEnumMap = {
  TransactionType.send: 'send',
  TransactionType.receive: 'receive',
  TransactionType.swap: 'swap',
  TransactionType.contract: 'contract',
};

const _$TransactionStatusEnumMap = {
  TransactionStatus.pending: 'pending',
  TransactionStatus.confirmed: 'confirmed',
  TransactionStatus.failed: 'failed',
};
