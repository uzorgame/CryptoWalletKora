// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WalletImpl _$$WalletImplFromJson(Map<String, dynamic> json) => _$WalletImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$WalletTypeEnumMap, json['type']),
  mainAddress: json['mainAddress'] as String,
  addresses:
      (json['addresses'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  assets:
      (json['assets'] as List<dynamic>?)
          ?.map((e) => Asset.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastBackup: json['lastBackup'] == null
      ? null
      : DateTime.parse(json['lastBackup'] as String),
  isBackedUp: json['isBackedUp'] as bool? ?? false,
  derivationPath: json['derivationPath'] as String?,
);

Map<String, dynamic> _$$WalletImplToJson(_$WalletImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$WalletTypeEnumMap[instance.type]!,
      'mainAddress': instance.mainAddress,
      'addresses': instance.addresses,
      'assets': instance.assets,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastBackup': instance.lastBackup?.toIso8601String(),
      'isBackedUp': instance.isBackedUp,
      'derivationPath': instance.derivationPath,
    };

const _$WalletTypeEnumMap = {
  WalletType.seedPhrase: 'seed_phrase',
  WalletType.mpc: 'mpc',
  WalletType.imported: 'imported',
};
