// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'asset.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Asset _$AssetFromJson(Map<String, dynamic> json) {
  return _Asset.fromJson(json);
}

/// @nodoc
mixin _$Asset {
  String get id => throw _privateConstructorUsedError;
  String get symbol => throw _privateConstructorUsedError; // BTC, ETH, USDT
  String get name =>
      throw _privateConstructorUsedError; // Bitcoin, Ethereum, Tether
  String get blockchain =>
      throw _privateConstructorUsedError; // bitcoin, ethereum, solana
  String get contractAddress =>
      throw _privateConstructorUsedError; // For tokens (ERC20, etc)
  int get decimals =>
      throw _privateConstructorUsedError; // 8 for BTC, 18 for ETH
  String get balance =>
      throw _privateConstructorUsedError; // String to avoid precision loss
  double get balanceInUsd => throw _privateConstructorUsedError;
  double get priceUsd => throw _privateConstructorUsedError;
  double get priceChange24h => throw _privateConstructorUsedError;
  String? get iconUrl => throw _privateConstructorUsedError;
  AssetType get type => throw _privateConstructorUsedError;
  bool get isVisible => throw _privateConstructorUsedError;

  /// Serializes this Asset to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Asset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AssetCopyWith<Asset> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AssetCopyWith<$Res> {
  factory $AssetCopyWith(Asset value, $Res Function(Asset) then) =
      _$AssetCopyWithImpl<$Res, Asset>;
  @useResult
  $Res call({
    String id,
    String symbol,
    String name,
    String blockchain,
    String contractAddress,
    int decimals,
    String balance,
    double balanceInUsd,
    double priceUsd,
    double priceChange24h,
    String? iconUrl,
    AssetType type,
    bool isVisible,
  });
}

/// @nodoc
class _$AssetCopyWithImpl<$Res, $Val extends Asset>
    implements $AssetCopyWith<$Res> {
  _$AssetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Asset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? symbol = null,
    Object? name = null,
    Object? blockchain = null,
    Object? contractAddress = null,
    Object? decimals = null,
    Object? balance = null,
    Object? balanceInUsd = null,
    Object? priceUsd = null,
    Object? priceChange24h = null,
    Object? iconUrl = freezed,
    Object? type = null,
    Object? isVisible = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            symbol: null == symbol
                ? _value.symbol
                : symbol // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            blockchain: null == blockchain
                ? _value.blockchain
                : blockchain // ignore: cast_nullable_to_non_nullable
                      as String,
            contractAddress: null == contractAddress
                ? _value.contractAddress
                : contractAddress // ignore: cast_nullable_to_non_nullable
                      as String,
            decimals: null == decimals
                ? _value.decimals
                : decimals // ignore: cast_nullable_to_non_nullable
                      as int,
            balance: null == balance
                ? _value.balance
                : balance // ignore: cast_nullable_to_non_nullable
                      as String,
            balanceInUsd: null == balanceInUsd
                ? _value.balanceInUsd
                : balanceInUsd // ignore: cast_nullable_to_non_nullable
                      as double,
            priceUsd: null == priceUsd
                ? _value.priceUsd
                : priceUsd // ignore: cast_nullable_to_non_nullable
                      as double,
            priceChange24h: null == priceChange24h
                ? _value.priceChange24h
                : priceChange24h // ignore: cast_nullable_to_non_nullable
                      as double,
            iconUrl: freezed == iconUrl
                ? _value.iconUrl
                : iconUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as AssetType,
            isVisible: null == isVisible
                ? _value.isVisible
                : isVisible // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AssetImplCopyWith<$Res> implements $AssetCopyWith<$Res> {
  factory _$$AssetImplCopyWith(
    _$AssetImpl value,
    $Res Function(_$AssetImpl) then,
  ) = __$$AssetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String symbol,
    String name,
    String blockchain,
    String contractAddress,
    int decimals,
    String balance,
    double balanceInUsd,
    double priceUsd,
    double priceChange24h,
    String? iconUrl,
    AssetType type,
    bool isVisible,
  });
}

/// @nodoc
class __$$AssetImplCopyWithImpl<$Res>
    extends _$AssetCopyWithImpl<$Res, _$AssetImpl>
    implements _$$AssetImplCopyWith<$Res> {
  __$$AssetImplCopyWithImpl(
    _$AssetImpl _value,
    $Res Function(_$AssetImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Asset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? symbol = null,
    Object? name = null,
    Object? blockchain = null,
    Object? contractAddress = null,
    Object? decimals = null,
    Object? balance = null,
    Object? balanceInUsd = null,
    Object? priceUsd = null,
    Object? priceChange24h = null,
    Object? iconUrl = freezed,
    Object? type = null,
    Object? isVisible = null,
  }) {
    return _then(
      _$AssetImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        symbol: null == symbol
            ? _value.symbol
            : symbol // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        blockchain: null == blockchain
            ? _value.blockchain
            : blockchain // ignore: cast_nullable_to_non_nullable
                  as String,
        contractAddress: null == contractAddress
            ? _value.contractAddress
            : contractAddress // ignore: cast_nullable_to_non_nullable
                  as String,
        decimals: null == decimals
            ? _value.decimals
            : decimals // ignore: cast_nullable_to_non_nullable
                  as int,
        balance: null == balance
            ? _value.balance
            : balance // ignore: cast_nullable_to_non_nullable
                  as String,
        balanceInUsd: null == balanceInUsd
            ? _value.balanceInUsd
            : balanceInUsd // ignore: cast_nullable_to_non_nullable
                  as double,
        priceUsd: null == priceUsd
            ? _value.priceUsd
            : priceUsd // ignore: cast_nullable_to_non_nullable
                  as double,
        priceChange24h: null == priceChange24h
            ? _value.priceChange24h
            : priceChange24h // ignore: cast_nullable_to_non_nullable
                  as double,
        iconUrl: freezed == iconUrl
            ? _value.iconUrl
            : iconUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as AssetType,
        isVisible: null == isVisible
            ? _value.isVisible
            : isVisible // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AssetImpl implements _Asset {
  const _$AssetImpl({
    required this.id,
    required this.symbol,
    required this.name,
    required this.blockchain,
    required this.contractAddress,
    required this.decimals,
    required this.balance,
    required this.balanceInUsd,
    required this.priceUsd,
    required this.priceChange24h,
    this.iconUrl,
    this.type = AssetType.native,
    this.isVisible = true,
  });

  factory _$AssetImpl.fromJson(Map<String, dynamic> json) =>
      _$$AssetImplFromJson(json);

  @override
  final String id;
  @override
  final String symbol;
  // BTC, ETH, USDT
  @override
  final String name;
  // Bitcoin, Ethereum, Tether
  @override
  final String blockchain;
  // bitcoin, ethereum, solana
  @override
  final String contractAddress;
  // For tokens (ERC20, etc)
  @override
  final int decimals;
  // 8 for BTC, 18 for ETH
  @override
  final String balance;
  // String to avoid precision loss
  @override
  final double balanceInUsd;
  @override
  final double priceUsd;
  @override
  final double priceChange24h;
  @override
  final String? iconUrl;
  @override
  @JsonKey()
  final AssetType type;
  @override
  @JsonKey()
  final bool isVisible;

  @override
  String toString() {
    return 'Asset(id: $id, symbol: $symbol, name: $name, blockchain: $blockchain, contractAddress: $contractAddress, decimals: $decimals, balance: $balance, balanceInUsd: $balanceInUsd, priceUsd: $priceUsd, priceChange24h: $priceChange24h, iconUrl: $iconUrl, type: $type, isVisible: $isVisible)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AssetImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.blockchain, blockchain) ||
                other.blockchain == blockchain) &&
            (identical(other.contractAddress, contractAddress) ||
                other.contractAddress == contractAddress) &&
            (identical(other.decimals, decimals) ||
                other.decimals == decimals) &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.balanceInUsd, balanceInUsd) ||
                other.balanceInUsd == balanceInUsd) &&
            (identical(other.priceUsd, priceUsd) ||
                other.priceUsd == priceUsd) &&
            (identical(other.priceChange24h, priceChange24h) ||
                other.priceChange24h == priceChange24h) &&
            (identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.isVisible, isVisible) ||
                other.isVisible == isVisible));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    symbol,
    name,
    blockchain,
    contractAddress,
    decimals,
    balance,
    balanceInUsd,
    priceUsd,
    priceChange24h,
    iconUrl,
    type,
    isVisible,
  );

  /// Create a copy of Asset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AssetImplCopyWith<_$AssetImpl> get copyWith =>
      __$$AssetImplCopyWithImpl<_$AssetImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AssetImplToJson(this);
  }
}

abstract class _Asset implements Asset {
  const factory _Asset({
    required final String id,
    required final String symbol,
    required final String name,
    required final String blockchain,
    required final String contractAddress,
    required final int decimals,
    required final String balance,
    required final double balanceInUsd,
    required final double priceUsd,
    required final double priceChange24h,
    final String? iconUrl,
    final AssetType type,
    final bool isVisible,
  }) = _$AssetImpl;

  factory _Asset.fromJson(Map<String, dynamic> json) = _$AssetImpl.fromJson;

  @override
  String get id;
  @override
  String get symbol; // BTC, ETH, USDT
  @override
  String get name; // Bitcoin, Ethereum, Tether
  @override
  String get blockchain; // bitcoin, ethereum, solana
  @override
  String get contractAddress; // For tokens (ERC20, etc)
  @override
  int get decimals; // 8 for BTC, 18 for ETH
  @override
  String get balance; // String to avoid precision loss
  @override
  double get balanceInUsd;
  @override
  double get priceUsd;
  @override
  double get priceChange24h;
  @override
  String? get iconUrl;
  @override
  AssetType get type;
  @override
  bool get isVisible;

  /// Create a copy of Asset
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AssetImplCopyWith<_$AssetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
