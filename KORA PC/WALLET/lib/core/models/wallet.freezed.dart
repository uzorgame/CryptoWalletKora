// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wallet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Wallet _$WalletFromJson(Map<String, dynamic> json) {
  return _Wallet.fromJson(json);
}

/// @nodoc
mixin _$Wallet {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  WalletType get type => throw _privateConstructorUsedError;
  String get mainAddress =>
      throw _privateConstructorUsedError; // Primary address (Ethereum)
  Map<String, String> get addresses =>
      throw _privateConstructorUsedError; // blockchain -> address
  List<Asset> get assets => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get lastBackup => throw _privateConstructorUsedError;
  bool get isBackedUp => throw _privateConstructorUsedError;
  String? get derivationPath => throw _privateConstructorUsedError;

  /// Serializes this Wallet to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WalletCopyWith<Wallet> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WalletCopyWith<$Res> {
  factory $WalletCopyWith(Wallet value, $Res Function(Wallet) then) =
      _$WalletCopyWithImpl<$Res, Wallet>;
  @useResult
  $Res call({
    String id,
    String name,
    WalletType type,
    String mainAddress,
    Map<String, String> addresses,
    List<Asset> assets,
    DateTime createdAt,
    DateTime? lastBackup,
    bool isBackedUp,
    String? derivationPath,
  });
}

/// @nodoc
class _$WalletCopyWithImpl<$Res, $Val extends Wallet>
    implements $WalletCopyWith<$Res> {
  _$WalletCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? mainAddress = null,
    Object? addresses = null,
    Object? assets = null,
    Object? createdAt = null,
    Object? lastBackup = freezed,
    Object? isBackedUp = null,
    Object? derivationPath = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as WalletType,
            mainAddress: null == mainAddress
                ? _value.mainAddress
                : mainAddress // ignore: cast_nullable_to_non_nullable
                      as String,
            addresses: null == addresses
                ? _value.addresses
                : addresses // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>,
            assets: null == assets
                ? _value.assets
                : assets // ignore: cast_nullable_to_non_nullable
                      as List<Asset>,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            lastBackup: freezed == lastBackup
                ? _value.lastBackup
                : lastBackup // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            isBackedUp: null == isBackedUp
                ? _value.isBackedUp
                : isBackedUp // ignore: cast_nullable_to_non_nullable
                      as bool,
            derivationPath: freezed == derivationPath
                ? _value.derivationPath
                : derivationPath // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WalletImplCopyWith<$Res> implements $WalletCopyWith<$Res> {
  factory _$$WalletImplCopyWith(
    _$WalletImpl value,
    $Res Function(_$WalletImpl) then,
  ) = __$$WalletImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    WalletType type,
    String mainAddress,
    Map<String, String> addresses,
    List<Asset> assets,
    DateTime createdAt,
    DateTime? lastBackup,
    bool isBackedUp,
    String? derivationPath,
  });
}

/// @nodoc
class __$$WalletImplCopyWithImpl<$Res>
    extends _$WalletCopyWithImpl<$Res, _$WalletImpl>
    implements _$$WalletImplCopyWith<$Res> {
  __$$WalletImplCopyWithImpl(
    _$WalletImpl _value,
    $Res Function(_$WalletImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? mainAddress = null,
    Object? addresses = null,
    Object? assets = null,
    Object? createdAt = null,
    Object? lastBackup = freezed,
    Object? isBackedUp = null,
    Object? derivationPath = freezed,
  }) {
    return _then(
      _$WalletImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as WalletType,
        mainAddress: null == mainAddress
            ? _value.mainAddress
            : mainAddress // ignore: cast_nullable_to_non_nullable
                  as String,
        addresses: null == addresses
            ? _value._addresses
            : addresses // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
        assets: null == assets
            ? _value._assets
            : assets // ignore: cast_nullable_to_non_nullable
                  as List<Asset>,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        lastBackup: freezed == lastBackup
            ? _value.lastBackup
            : lastBackup // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        isBackedUp: null == isBackedUp
            ? _value.isBackedUp
            : isBackedUp // ignore: cast_nullable_to_non_nullable
                  as bool,
        derivationPath: freezed == derivationPath
            ? _value.derivationPath
            : derivationPath // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WalletImpl implements _Wallet {
  const _$WalletImpl({
    required this.id,
    required this.name,
    required this.type,
    required this.mainAddress,
    final Map<String, String> addresses = const {},
    final List<Asset> assets = const [],
    required this.createdAt,
    this.lastBackup,
    this.isBackedUp = false,
    this.derivationPath,
  }) : _addresses = addresses,
       _assets = assets;

  factory _$WalletImpl.fromJson(Map<String, dynamic> json) =>
      _$$WalletImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final WalletType type;
  @override
  final String mainAddress;
  // Primary address (Ethereum)
  final Map<String, String> _addresses;
  // Primary address (Ethereum)
  @override
  @JsonKey()
  Map<String, String> get addresses {
    if (_addresses is EqualUnmodifiableMapView) return _addresses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_addresses);
  }

  // blockchain -> address
  final List<Asset> _assets;
  // blockchain -> address
  @override
  @JsonKey()
  List<Asset> get assets {
    if (_assets is EqualUnmodifiableListView) return _assets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_assets);
  }

  @override
  final DateTime createdAt;
  @override
  final DateTime? lastBackup;
  @override
  @JsonKey()
  final bool isBackedUp;
  @override
  final String? derivationPath;

  @override
  String toString() {
    return 'Wallet(id: $id, name: $name, type: $type, mainAddress: $mainAddress, addresses: $addresses, assets: $assets, createdAt: $createdAt, lastBackup: $lastBackup, isBackedUp: $isBackedUp, derivationPath: $derivationPath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WalletImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.mainAddress, mainAddress) ||
                other.mainAddress == mainAddress) &&
            const DeepCollectionEquality().equals(
              other._addresses,
              _addresses,
            ) &&
            const DeepCollectionEquality().equals(other._assets, _assets) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastBackup, lastBackup) ||
                other.lastBackup == lastBackup) &&
            (identical(other.isBackedUp, isBackedUp) ||
                other.isBackedUp == isBackedUp) &&
            (identical(other.derivationPath, derivationPath) ||
                other.derivationPath == derivationPath));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    type,
    mainAddress,
    const DeepCollectionEquality().hash(_addresses),
    const DeepCollectionEquality().hash(_assets),
    createdAt,
    lastBackup,
    isBackedUp,
    derivationPath,
  );

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WalletImplCopyWith<_$WalletImpl> get copyWith =>
      __$$WalletImplCopyWithImpl<_$WalletImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WalletImplToJson(this);
  }
}

abstract class _Wallet implements Wallet {
  const factory _Wallet({
    required final String id,
    required final String name,
    required final WalletType type,
    required final String mainAddress,
    final Map<String, String> addresses,
    final List<Asset> assets,
    required final DateTime createdAt,
    final DateTime? lastBackup,
    final bool isBackedUp,
    final String? derivationPath,
  }) = _$WalletImpl;

  factory _Wallet.fromJson(Map<String, dynamic> json) = _$WalletImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  WalletType get type;
  @override
  String get mainAddress; // Primary address (Ethereum)
  @override
  Map<String, String> get addresses; // blockchain -> address
  @override
  List<Asset> get assets;
  @override
  DateTime get createdAt;
  @override
  DateTime? get lastBackup;
  @override
  bool get isBackedUp;
  @override
  String? get derivationPath;

  /// Create a copy of Wallet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WalletImplCopyWith<_$WalletImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
