import '../entities/asset.dart';
import '../entities/price_point.dart';
import '../enums/asset_type.dart';

abstract interface class PriceFetchService {
  /// Fetch current price for a single asset
  Future<double?> fetchCurrentPrice(Asset asset);

  /// Fetch historical price data for chart
  Future<List<PricePoint>> fetchPriceHistory(
    Asset asset, {
    int days = 365,
  });

  /// Fetch price history for all assets (batch)
  Future<Map<int, double?>> fetchCurrentPrices(List<Asset> assets);

  /// Search assets by query
  Future<List<Asset>> searchAssets(String query, AssetType? filterType);
}
