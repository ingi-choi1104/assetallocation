// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'portfolio_asset.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$PortfolioAsset {
  int get id => throw _privateConstructorUsedError;
  int get portfolioId => throw _privateConstructorUsedError;
  int get assetId => throw _privateConstructorUsedError;
  double get targetWeight => throw _privateConstructorUsedError;
  int get sortOrder => throw _privateConstructorUsedError;
  DateTime get addedAt => throw _privateConstructorUsedError; // Joined field
  Asset? get asset => throw _privateConstructorUsedError;

  /// Create a copy of PortfolioAsset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PortfolioAssetCopyWith<PortfolioAsset> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PortfolioAssetCopyWith<$Res> {
  factory $PortfolioAssetCopyWith(
          PortfolioAsset value, $Res Function(PortfolioAsset) then) =
      _$PortfolioAssetCopyWithImpl<$Res, PortfolioAsset>;
  @useResult
  $Res call(
      {int id,
      int portfolioId,
      int assetId,
      double targetWeight,
      int sortOrder,
      DateTime addedAt,
      Asset? asset});

  $AssetCopyWith<$Res>? get asset;
}

/// @nodoc
class _$PortfolioAssetCopyWithImpl<$Res, $Val extends PortfolioAsset>
    implements $PortfolioAssetCopyWith<$Res> {
  _$PortfolioAssetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PortfolioAsset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? portfolioId = null,
    Object? assetId = null,
    Object? targetWeight = null,
    Object? sortOrder = null,
    Object? addedAt = null,
    Object? asset = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      portfolioId: null == portfolioId
          ? _value.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as int,
      assetId: null == assetId
          ? _value.assetId
          : assetId // ignore: cast_nullable_to_non_nullable
              as int,
      targetWeight: null == targetWeight
          ? _value.targetWeight
          : targetWeight // ignore: cast_nullable_to_non_nullable
              as double,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      addedAt: null == addedAt
          ? _value.addedAt
          : addedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      asset: freezed == asset
          ? _value.asset
          : asset // ignore: cast_nullable_to_non_nullable
              as Asset?,
    ) as $Val);
  }

  /// Create a copy of PortfolioAsset
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AssetCopyWith<$Res>? get asset {
    if (_value.asset == null) {
      return null;
    }

    return $AssetCopyWith<$Res>(_value.asset!, (value) {
      return _then(_value.copyWith(asset: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PortfolioAssetImplCopyWith<$Res>
    implements $PortfolioAssetCopyWith<$Res> {
  factory _$$PortfolioAssetImplCopyWith(_$PortfolioAssetImpl value,
          $Res Function(_$PortfolioAssetImpl) then) =
      __$$PortfolioAssetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      int portfolioId,
      int assetId,
      double targetWeight,
      int sortOrder,
      DateTime addedAt,
      Asset? asset});

  @override
  $AssetCopyWith<$Res>? get asset;
}

/// @nodoc
class __$$PortfolioAssetImplCopyWithImpl<$Res>
    extends _$PortfolioAssetCopyWithImpl<$Res, _$PortfolioAssetImpl>
    implements _$$PortfolioAssetImplCopyWith<$Res> {
  __$$PortfolioAssetImplCopyWithImpl(
      _$PortfolioAssetImpl _value, $Res Function(_$PortfolioAssetImpl) _then)
      : super(_value, _then);

  /// Create a copy of PortfolioAsset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? portfolioId = null,
    Object? assetId = null,
    Object? targetWeight = null,
    Object? sortOrder = null,
    Object? addedAt = null,
    Object? asset = freezed,
  }) {
    return _then(_$PortfolioAssetImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      portfolioId: null == portfolioId
          ? _value.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as int,
      assetId: null == assetId
          ? _value.assetId
          : assetId // ignore: cast_nullable_to_non_nullable
              as int,
      targetWeight: null == targetWeight
          ? _value.targetWeight
          : targetWeight // ignore: cast_nullable_to_non_nullable
              as double,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      addedAt: null == addedAt
          ? _value.addedAt
          : addedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      asset: freezed == asset
          ? _value.asset
          : asset // ignore: cast_nullable_to_non_nullable
              as Asset?,
    ));
  }
}

/// @nodoc

class _$PortfolioAssetImpl implements _PortfolioAsset {
  const _$PortfolioAssetImpl(
      {required this.id,
      required this.portfolioId,
      required this.assetId,
      required this.targetWeight,
      required this.sortOrder,
      required this.addedAt,
      this.asset});

  @override
  final int id;
  @override
  final int portfolioId;
  @override
  final int assetId;
  @override
  final double targetWeight;
  @override
  final int sortOrder;
  @override
  final DateTime addedAt;
// Joined field
  @override
  final Asset? asset;

  @override
  String toString() {
    return 'PortfolioAsset(id: $id, portfolioId: $portfolioId, assetId: $assetId, targetWeight: $targetWeight, sortOrder: $sortOrder, addedAt: $addedAt, asset: $asset)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PortfolioAssetImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.targetWeight, targetWeight) ||
                other.targetWeight == targetWeight) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.addedAt, addedAt) || other.addedAt == addedAt) &&
            (identical(other.asset, asset) || other.asset == asset));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, portfolioId, assetId,
      targetWeight, sortOrder, addedAt, asset);

  /// Create a copy of PortfolioAsset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PortfolioAssetImplCopyWith<_$PortfolioAssetImpl> get copyWith =>
      __$$PortfolioAssetImplCopyWithImpl<_$PortfolioAssetImpl>(
          this, _$identity);
}

abstract class _PortfolioAsset implements PortfolioAsset {
  const factory _PortfolioAsset(
      {required final int id,
      required final int portfolioId,
      required final int assetId,
      required final double targetWeight,
      required final int sortOrder,
      required final DateTime addedAt,
      final Asset? asset}) = _$PortfolioAssetImpl;

  @override
  int get id;
  @override
  int get portfolioId;
  @override
  int get assetId;
  @override
  double get targetWeight;
  @override
  int get sortOrder;
  @override
  DateTime get addedAt; // Joined field
  @override
  Asset? get asset;

  /// Create a copy of PortfolioAsset
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PortfolioAssetImplCopyWith<_$PortfolioAssetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
