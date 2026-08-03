// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Transaction _$TransactionFromJson(Map<String, dynamic> json) {
  return _Transaction.fromJson(json);
}

/// @nodoc
mixin _$Transaction {
  String get id => throw _privateConstructorUsedError;
  String get hash => throw _privateConstructorUsedError;
  String get blockchain => throw _privateConstructorUsedError;
  String get from => throw _privateConstructorUsedError;
  String get to => throw _privateConstructorUsedError;
  String get amount =>
      throw _privateConstructorUsedError; // String to avoid precision loss
  String get symbol => throw _privateConstructorUsedError;
  TransactionType get type => throw _privateConstructorUsedError;
  TransactionStatus get status => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  int? get blockNumber => throw _privateConstructorUsedError;
  String? get gasUsed => throw _privateConstructorUsedError;
  String? get gasFee => throw _privateConstructorUsedError;
  String? get nonce => throw _privateConstructorUsedError;
  String? get data => throw _privateConstructorUsedError;
  String? get contractAddress =>
      throw _privateConstructorUsedError; // For token transfers
  String? get errorMessage => throw _privateConstructorUsedError;

  /// Serializes this Transaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TransactionCopyWith<Transaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransactionCopyWith<$Res> {
  factory $TransactionCopyWith(
    Transaction value,
    $Res Function(Transaction) then,
  ) = _$TransactionCopyWithImpl<$Res, Transaction>;
  @useResult
  $Res call({
    String id,
    String hash,
    String blockchain,
    String from,
    String to,
    String amount,
    String symbol,
    TransactionType type,
    TransactionStatus status,
    DateTime timestamp,
    int? blockNumber,
    String? gasUsed,
    String? gasFee,
    String? nonce,
    String? data,
    String? contractAddress,
    String? errorMessage,
  });
}

/// @nodoc
class _$TransactionCopyWithImpl<$Res, $Val extends Transaction>
    implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? hash = null,
    Object? blockchain = null,
    Object? from = null,
    Object? to = null,
    Object? amount = null,
    Object? symbol = null,
    Object? type = null,
    Object? status = null,
    Object? timestamp = null,
    Object? blockNumber = freezed,
    Object? gasUsed = freezed,
    Object? gasFee = freezed,
    Object? nonce = freezed,
    Object? data = freezed,
    Object? contractAddress = freezed,
    Object? errorMessage = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            hash: null == hash
                ? _value.hash
                : hash // ignore: cast_nullable_to_non_nullable
                      as String,
            blockchain: null == blockchain
                ? _value.blockchain
                : blockchain // ignore: cast_nullable_to_non_nullable
                      as String,
            from: null == from
                ? _value.from
                : from // ignore: cast_nullable_to_non_nullable
                      as String,
            to: null == to
                ? _value.to
                : to // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as String,
            symbol: null == symbol
                ? _value.symbol
                : symbol // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as TransactionType,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as TransactionStatus,
            timestamp: null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            blockNumber: freezed == blockNumber
                ? _value.blockNumber
                : blockNumber // ignore: cast_nullable_to_non_nullable
                      as int?,
            gasUsed: freezed == gasUsed
                ? _value.gasUsed
                : gasUsed // ignore: cast_nullable_to_non_nullable
                      as String?,
            gasFee: freezed == gasFee
                ? _value.gasFee
                : gasFee // ignore: cast_nullable_to_non_nullable
                      as String?,
            nonce: freezed == nonce
                ? _value.nonce
                : nonce // ignore: cast_nullable_to_non_nullable
                      as String?,
            data: freezed == data
                ? _value.data
                : data // ignore: cast_nullable_to_non_nullable
                      as String?,
            contractAddress: freezed == contractAddress
                ? _value.contractAddress
                : contractAddress // ignore: cast_nullable_to_non_nullable
                      as String?,
            errorMessage: freezed == errorMessage
                ? _value.errorMessage
                : errorMessage // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TransactionImplCopyWith<$Res>
    implements $TransactionCopyWith<$Res> {
  factory _$$TransactionImplCopyWith(
    _$TransactionImpl value,
    $Res Function(_$TransactionImpl) then,
  ) = __$$TransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String hash,
    String blockchain,
    String from,
    String to,
    String amount,
    String symbol,
    TransactionType type,
    TransactionStatus status,
    DateTime timestamp,
    int? blockNumber,
    String? gasUsed,
    String? gasFee,
    String? nonce,
    String? data,
    String? contractAddress,
    String? errorMessage,
  });
}

/// @nodoc
class __$$TransactionImplCopyWithImpl<$Res>
    extends _$TransactionCopyWithImpl<$Res, _$TransactionImpl>
    implements _$$TransactionImplCopyWith<$Res> {
  __$$TransactionImplCopyWithImpl(
    _$TransactionImpl _value,
    $Res Function(_$TransactionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? hash = null,
    Object? blockchain = null,
    Object? from = null,
    Object? to = null,
    Object? amount = null,
    Object? symbol = null,
    Object? type = null,
    Object? status = null,
    Object? timestamp = null,
    Object? blockNumber = freezed,
    Object? gasUsed = freezed,
    Object? gasFee = freezed,
    Object? nonce = freezed,
    Object? data = freezed,
    Object? contractAddress = freezed,
    Object? errorMessage = freezed,
  }) {
    return _then(
      _$TransactionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        hash: null == hash
            ? _value.hash
            : hash // ignore: cast_nullable_to_non_nullable
                  as String,
        blockchain: null == blockchain
            ? _value.blockchain
            : blockchain // ignore: cast_nullable_to_non_nullable
                  as String,
        from: null == from
            ? _value.from
            : from // ignore: cast_nullable_to_non_nullable
                  as String,
        to: null == to
            ? _value.to
            : to // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as String,
        symbol: null == symbol
            ? _value.symbol
            : symbol // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as TransactionType,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as TransactionStatus,
        timestamp: null == timestamp
            ? _value.timestamp
            : timestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        blockNumber: freezed == blockNumber
            ? _value.blockNumber
            : blockNumber // ignore: cast_nullable_to_non_nullable
                  as int?,
        gasUsed: freezed == gasUsed
            ? _value.gasUsed
            : gasUsed // ignore: cast_nullable_to_non_nullable
                  as String?,
        gasFee: freezed == gasFee
            ? _value.gasFee
            : gasFee // ignore: cast_nullable_to_non_nullable
                  as String?,
        nonce: freezed == nonce
            ? _value.nonce
            : nonce // ignore: cast_nullable_to_non_nullable
                  as String?,
        data: freezed == data
            ? _value.data
            : data // ignore: cast_nullable_to_non_nullable
                  as String?,
        contractAddress: freezed == contractAddress
            ? _value.contractAddress
            : contractAddress // ignore: cast_nullable_to_non_nullable
                  as String?,
        errorMessage: freezed == errorMessage
            ? _value.errorMessage
            : errorMessage // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TransactionImpl implements _Transaction {
  const _$TransactionImpl({
    required this.id,
    required this.hash,
    required this.blockchain,
    required this.from,
    required this.to,
    required this.amount,
    required this.symbol,
    required this.type,
    required this.status,
    required this.timestamp,
    this.blockNumber,
    this.gasUsed,
    this.gasFee,
    this.nonce,
    this.data,
    this.contractAddress,
    this.errorMessage,
  });

  factory _$TransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransactionImplFromJson(json);

  @override
  final String id;
  @override
  final String hash;
  @override
  final String blockchain;
  @override
  final String from;
  @override
  final String to;
  @override
  final String amount;
  // String to avoid precision loss
  @override
  final String symbol;
  @override
  final TransactionType type;
  @override
  final TransactionStatus status;
  @override
  final DateTime timestamp;
  @override
  final int? blockNumber;
  @override
  final String? gasUsed;
  @override
  final String? gasFee;
  @override
  final String? nonce;
  @override
  final String? data;
  @override
  final String? contractAddress;
  // For token transfers
  @override
  final String? errorMessage;

  @override
  String toString() {
    return 'Transaction(id: $id, hash: $hash, blockchain: $blockchain, from: $from, to: $to, amount: $amount, symbol: $symbol, type: $type, status: $status, timestamp: $timestamp, blockNumber: $blockNumber, gasUsed: $gasUsed, gasFee: $gasFee, nonce: $nonce, data: $data, contractAddress: $contractAddress, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransactionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.hash, hash) || other.hash == hash) &&
            (identical(other.blockchain, blockchain) ||
                other.blockchain == blockchain) &&
            (identical(other.from, from) || other.from == from) &&
            (identical(other.to, to) || other.to == to) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.blockNumber, blockNumber) ||
                other.blockNumber == blockNumber) &&
            (identical(other.gasUsed, gasUsed) || other.gasUsed == gasUsed) &&
            (identical(other.gasFee, gasFee) || other.gasFee == gasFee) &&
            (identical(other.nonce, nonce) || other.nonce == nonce) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.contractAddress, contractAddress) ||
                other.contractAddress == contractAddress) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    hash,
    blockchain,
    from,
    to,
    amount,
    symbol,
    type,
    status,
    timestamp,
    blockNumber,
    gasUsed,
    gasFee,
    nonce,
    data,
    contractAddress,
    errorMessage,
  );

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      __$$TransactionImplCopyWithImpl<_$TransactionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TransactionImplToJson(this);
  }
}

abstract class _Transaction implements Transaction {
  const factory _Transaction({
    required final String id,
    required final String hash,
    required final String blockchain,
    required final String from,
    required final String to,
    required final String amount,
    required final String symbol,
    required final TransactionType type,
    required final TransactionStatus status,
    required final DateTime timestamp,
    final int? blockNumber,
    final String? gasUsed,
    final String? gasFee,
    final String? nonce,
    final String? data,
    final String? contractAddress,
    final String? errorMessage,
  }) = _$TransactionImpl;

  factory _Transaction.fromJson(Map<String, dynamic> json) =
      _$TransactionImpl.fromJson;

  @override
  String get id;
  @override
  String get hash;
  @override
  String get blockchain;
  @override
  String get from;
  @override
  String get to;
  @override
  String get amount; // String to avoid precision loss
  @override
  String get symbol;
  @override
  TransactionType get type;
  @override
  TransactionStatus get status;
  @override
  DateTime get timestamp;
  @override
  int? get blockNumber;
  @override
  String? get gasUsed;
  @override
  String? get gasFee;
  @override
  String? get nonce;
  @override
  String? get data;
  @override
  String? get contractAddress; // For token transfers
  @override
  String? get errorMessage;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
