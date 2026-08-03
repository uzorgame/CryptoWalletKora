// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AssetImpl _$$AssetImplFromJson(Map<String, dynamic> json) => _$AssetImpl(
  id: json['id'] as String,
  symbol: json['symbol'] as String,
  name: json['name'] as String,
  blockchain: json['blockchain'] as String,
  contractAddress: json['contractAddress'] as String,
  decimals: (json['decimals'] as num).toInt(),
  balance: json['balance'] as String,
  balanceInUsd: (json['balanceInUsd'] as num).toDouble(),
  priceUsd: (json['priceUsd'] as num).toDouble(),
  priceChange24h: (json['priceChange24h'] as num).toDouble(),
  iconUrl: json['iconUrl'] as String?,
  type:
      $enumDecodeNullable(_$AssetTypeEnumMap, json['type']) ?? AssetType.native,
  isVisible: json['isVisible'] as bool? ?? true,
);

Map<String, dynamic> _$$AssetImplToJson(_$AssetImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'symbol': instance.symbol,
      'name': instance.name,
      'blockchain': instance.blockchain,
      'contractAddress': instance.contractAddress,
      'decimals': instance.decimals,
      'balance': instance.balance,
      'balanceInUsd': instance.balanceInUsd,
      'priceUsd': instance.priceUsd,
      'priceChange24h': instance.priceChange24h,
      'iconUrl': instance.iconUrl,
      'type': _$AssetTypeEnumMap[instance.type]!,
      'isVisible': instance.isVisible,
    };

const _$AssetTypeEnumMap = {
  AssetType.native: 'native',
  AssetType.token: 'token',
  AssetType.nft: 'nft',
};
