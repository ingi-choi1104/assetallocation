import 'package:freezed_annotation/freezed_annotation.dart';

part 'price_point.freezed.dart';

@freezed
class PricePoint with _$PricePoint {
  const factory PricePoint({
    required int assetId,
    required double closePrice,
    required DateTime date,
    required DateTime fetchedAt,
  }) = _PricePoint;
}
