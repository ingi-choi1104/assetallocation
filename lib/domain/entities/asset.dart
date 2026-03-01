import 'package:freezed_annotation/freezed_annotation.dart';
import '../enums/asset_type.dart';

part 'asset.freezed.dart';

@freezed
class Asset with _$Asset {
  const factory Asset({
    required int id,
    required String symbol,
    required String name,
    required AssetType assetType,
    required String currency,
    String? fundCode,
    double? lastPrice,
    DateTime? lastPriceUpdatedAt,
    required DateTime createdAt,
  }) = _Asset;
}
