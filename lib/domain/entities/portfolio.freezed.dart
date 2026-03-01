// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'portfolio.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Portfolio {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String get baseCurrency => throw _privateConstructorUsedError;
  String? get rebalancePeriod => throw _privateConstructorUsedError;
  DateTime? get nextRebalanceDate => throw _privateConstructorUsedError;
  double get deviationThreshold => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of Portfolio
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PortfolioCopyWith<Portfolio> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PortfolioCopyWith<$Res> {
  factory $PortfolioCopyWith(Portfolio value, $Res Function(Portfolio) then) =
      _$PortfolioCopyWithImpl<$Res, Portfolio>;
  @useResult
  $Res call(
      {int id,
      String name,
      String? description,
      String baseCurrency,
      String? rebalancePeriod,
      DateTime? nextRebalanceDate,
      double deviationThreshold,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$PortfolioCopyWithImpl<$Res, $Val extends Portfolio>
    implements $PortfolioCopyWith<$Res> {
  _$PortfolioCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Portfolio
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? baseCurrency = null,
    Object? rebalancePeriod = freezed,
    Object? nextRebalanceDate = freezed,
    Object? deviationThreshold = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      baseCurrency: null == baseCurrency
          ? _value.baseCurrency
          : baseCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      rebalancePeriod: freezed == rebalancePeriod
          ? _value.rebalancePeriod
          : rebalancePeriod // ignore: cast_nullable_to_non_nullable
              as String?,
      nextRebalanceDate: freezed == nextRebalanceDate
          ? _value.nextRebalanceDate
          : nextRebalanceDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deviationThreshold: null == deviationThreshold
          ? _value.deviationThreshold
          : deviationThreshold // ignore: cast_nullable_to_non_nullable
              as double,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PortfolioImplCopyWith<$Res>
    implements $PortfolioCopyWith<$Res> {
  factory _$$PortfolioImplCopyWith(
          _$PortfolioImpl value, $Res Function(_$PortfolioImpl) then) =
      __$$PortfolioImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String name,
      String? description,
      String baseCurrency,
      String? rebalancePeriod,
      DateTime? nextRebalanceDate,
      double deviationThreshold,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$PortfolioImplCopyWithImpl<$Res>
    extends _$PortfolioCopyWithImpl<$Res, _$PortfolioImpl>
    implements _$$PortfolioImplCopyWith<$Res> {
  __$$PortfolioImplCopyWithImpl(
      _$PortfolioImpl _value, $Res Function(_$PortfolioImpl) _then)
      : super(_value, _then);

  /// Create a copy of Portfolio
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? baseCurrency = null,
    Object? rebalancePeriod = freezed,
    Object? nextRebalanceDate = freezed,
    Object? deviationThreshold = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$PortfolioImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      baseCurrency: null == baseCurrency
          ? _value.baseCurrency
          : baseCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      rebalancePeriod: freezed == rebalancePeriod
          ? _value.rebalancePeriod
          : rebalancePeriod // ignore: cast_nullable_to_non_nullable
              as String?,
      nextRebalanceDate: freezed == nextRebalanceDate
          ? _value.nextRebalanceDate
          : nextRebalanceDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deviationThreshold: null == deviationThreshold
          ? _value.deviationThreshold
          : deviationThreshold // ignore: cast_nullable_to_non_nullable
              as double,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc

class _$PortfolioImpl implements _Portfolio {
  const _$PortfolioImpl(
      {required this.id,
      required this.name,
      this.description,
      required this.baseCurrency,
      this.rebalancePeriod,
      this.nextRebalanceDate,
      required this.deviationThreshold,
      required this.createdAt,
      required this.updatedAt});

  @override
  final int id;
  @override
  final String name;
  @override
  final String? description;
  @override
  final String baseCurrency;
  @override
  final String? rebalancePeriod;
  @override
  final DateTime? nextRebalanceDate;
  @override
  final double deviationThreshold;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Portfolio(id: $id, name: $name, description: $description, baseCurrency: $baseCurrency, rebalancePeriod: $rebalancePeriod, nextRebalanceDate: $nextRebalanceDate, deviationThreshold: $deviationThreshold, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PortfolioImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.baseCurrency, baseCurrency) ||
                other.baseCurrency == baseCurrency) &&
            (identical(other.rebalancePeriod, rebalancePeriod) ||
                other.rebalancePeriod == rebalancePeriod) &&
            (identical(other.nextRebalanceDate, nextRebalanceDate) ||
                other.nextRebalanceDate == nextRebalanceDate) &&
            (identical(other.deviationThreshold, deviationThreshold) ||
                other.deviationThreshold == deviationThreshold) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      baseCurrency,
      rebalancePeriod,
      nextRebalanceDate,
      deviationThreshold,
      createdAt,
      updatedAt);

  /// Create a copy of Portfolio
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PortfolioImplCopyWith<_$PortfolioImpl> get copyWith =>
      __$$PortfolioImplCopyWithImpl<_$PortfolioImpl>(this, _$identity);
}

abstract class _Portfolio implements Portfolio {
  const factory _Portfolio(
      {required final int id,
      required final String name,
      final String? description,
      required final String baseCurrency,
      final String? rebalancePeriod,
      final DateTime? nextRebalanceDate,
      required final double deviationThreshold,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$PortfolioImpl;

  @override
  int get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  String get baseCurrency;
  @override
  String? get rebalancePeriod;
  @override
  DateTime? get nextRebalanceDate;
  @override
  double get deviationThreshold;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Portfolio
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PortfolioImplCopyWith<_$PortfolioImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
