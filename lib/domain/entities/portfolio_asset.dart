import 'package:freezed_annotation/freezed_annotation.dart';
import 'asset.dart';

part 'portfolio_asset.freezed.dart';

@freezed
class PortfolioAsset with _$PortfolioAsset {
  const factory PortfolioAsset({
    required int id,
    required int portfolioId,
    required int assetId,
    required double targetWeight,
    required int sortOrder,
    required DateTime addedAt,
    // Joined field
    Asset? asset,
  }) = _PortfolioAsset;
}
