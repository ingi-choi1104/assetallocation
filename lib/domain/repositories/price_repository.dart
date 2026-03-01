import '../entities/price_point.dart';

abstract interface class PriceRepository {
  Future<List<PricePoint>> getPriceHistory(int assetId, {int days = 365});
  Future<void> savePriceHistory(List<PricePoint> prices);
  Future<double?> fetchCurrentPrice(int assetId);
  Future<void> syncAllPrices();
}
