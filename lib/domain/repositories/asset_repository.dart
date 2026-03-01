import '../entities/asset.dart';
import '../entities/portfolio_asset.dart';
import '../entities/transaction.dart';

abstract interface class AssetRepository {
  Future<Asset?> getAssetById(int id);
  Future<Asset?> getAssetBySymbolAndType(String symbol, String assetType);
  Future<int> upsertAsset(Asset asset);
  Future<void> updateLastPrice(int assetId, double price);

  Stream<List<PortfolioAsset>> watchPortfolioAssets(int portfolioId);
  Future<List<PortfolioAsset>> getPortfolioAssets(int portfolioId);
  Future<int> addAssetToPortfolio({
    required int portfolioId,
    required int assetId,
    required double targetWeight,
    required int sortOrder,
  });
  Future<void> updateTargetWeight(int portfolioAssetId, double weight);
  Future<void> updateSortOrders(Map<int, int> idToSortOrder);
  Future<void> removeAssetFromPortfolio(int portfolioAssetId);

  Stream<List<Transaction>> watchTransactions(int portfolioAssetId);
  Future<List<Transaction>> getTransactions(int portfolioAssetId);
  Future<int> addTransaction(Transaction transaction);
  Future<void> deleteTransaction(int transactionId);
}
