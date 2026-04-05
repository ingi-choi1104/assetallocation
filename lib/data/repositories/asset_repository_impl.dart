import 'package:drift/drift.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/portfolio_asset.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/enums/asset_type.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/repositories/asset_repository.dart';
import '../database/app_database.dart';
import '../database/daos/portfolio_asset_dao.dart';

class AssetRepositoryImpl implements AssetRepository {
  final AppDatabase _db;

  AssetRepositoryImpl(this._db);

  @override
  Future<Asset?> getAssetById(int id) async {
    final row = await _db.assetDao.getById(id);
    return row != null ? _assetToEntity(row) : null;
  }

  @override
  Future<Asset?> getAssetBySymbolAndType(
      String symbol, String assetType) async {
    final row =
        await _db.assetDao.getBySymbolAndType(symbol, assetType);
    return row != null ? _assetToEntity(row) : null;
  }

  @override
  Future<int> upsertAsset(Asset asset) async {
    // Check by (symbol, asset_type) first to avoid UNIQUE constraint violation.
    // Search results come in with id:0, so ON CONFLICT(id) doesn't help here.
    final existing = await _db.assetDao
        .getBySymbolAndType(asset.symbol, asset.assetType.value);
    if (existing != null) return existing.id;

    return _db.assetDao.upsert(
      AssetsCompanion.insert(
        symbol: asset.symbol,
        name: asset.name,
        assetType: asset.assetType.value,
        currency: asset.currency,
        fundCode: Value(asset.fundCode),
        lastPrice: Value(asset.lastPrice),
        lastPriceUpdatedAt: Value(asset.lastPriceUpdatedAt),
      ),
    );
  }

  @override
  Future<void> updateLastPrice(int assetId, double price) {
    return _db.assetDao.updateLastPrice(assetId, price);
  }

  @override
  Stream<List<PortfolioAsset>> watchPortfolioAssets(int portfolioId) =>
      _db.portfolioAssetDao.watchByPortfolio(portfolioId).map(
            (rows) => rows.map(_paToEntity).toList(),
          );

  @override
  Future<List<PortfolioAsset>> getPortfolioAssets(int portfolioId) async {
    final rows = await _db.portfolioAssetDao.getByPortfolio(portfolioId);
    return rows.map(_paToEntity).toList();
  }

  @override
  Future<int> addAssetToPortfolio({
    required int portfolioId,
    required int assetId,
    required double targetWeight,
    required int sortOrder,
  }) {
    return _db.portfolioAssetDao.insert(
      PortfolioAssetsCompanion.insert(
        portfolioId: portfolioId,
        assetId: assetId,
        targetWeight: targetWeight,
        sortOrder: Value(sortOrder),
      ),
    );
  }

  @override
  Future<void> updateTargetWeight(int portfolioAssetId, double weight) {
    return _db.portfolioAssetDao.updateWeight(portfolioAssetId, weight);
  }

  @override
  Future<void> updateSortOrders(Map<int, int> idToSortOrder) {
    return _db.portfolioAssetDao.updateSortOrders(idToSortOrder);
  }

  @override
  Future<void> removeAssetFromPortfolio(int portfolioAssetId) async {
    await _db.portfolioAssetDao.deleteById(portfolioAssetId);
  }

  @override
  Stream<List<Transaction>> watchTransactions(int portfolioAssetId) =>
      _db.transactionDao.watchByPortfolioAsset(portfolioAssetId).map(
            (rows) => rows.map(_txToEntity).toList(),
          );

  @override
  Future<List<Transaction>> getTransactions(int portfolioAssetId) async {
    final rows =
        await _db.transactionDao.getByPortfolioAsset(portfolioAssetId);
    return rows.map(_txToEntity).toList();
  }

  @override
  Future<int> addTransaction(Transaction transaction) {
    return _db.transactionDao.insert(
      TransactionsCompanion.insert(
        portfolioAssetId: transaction.portfolioAssetId,
        type: transaction.type.value,
        quantity: transaction.quantity,
        price: transaction.price,
        exchangeRate: Value(transaction.exchangeRate),
        fee: Value(transaction.fee),
        transactionDate: transaction.transactionDate,
        memo: Value(transaction.memo),
      ),
    );
  }

  @override
  Future<void> deleteTransaction(int transactionId) async {
    await _db.transactionDao.deleteById(transactionId);
  }

  Asset _assetToEntity(AssetRecord r) => Asset(
        id: r.id,
        symbol: r.symbol,
        name: r.name,
        assetType: AssetType.fromValue(r.assetType),
        currency: r.currency,
        fundCode: r.fundCode,
        lastPrice: r.lastPrice,
        lastPreviousClose: r.lastPreviousClose,
        lastPriceUpdatedAt: r.lastPriceUpdatedAt,
        createdAt: r.createdAt,
      );

  PortfolioAsset _paToEntity(PortfolioAssetWithAsset row) => PortfolioAsset(
        id: row.portfolioAsset.id,
        portfolioId: row.portfolioAsset.portfolioId,
        assetId: row.portfolioAsset.assetId,
        targetWeight: row.portfolioAsset.targetWeight,
        sortOrder: row.portfolioAsset.sortOrder,
        addedAt: row.portfolioAsset.addedAt,
        asset: _assetToEntity(row.asset),
      );

  Transaction _txToEntity(TransactionRecord r) => Transaction(
        id: r.id,
        portfolioAssetId: r.portfolioAssetId,
        type: TransactionType.fromValue(r.type),
        quantity: r.quantity,
        price: r.price,
        exchangeRate: r.exchangeRate,
        fee: r.fee,
        transactionDate: r.transactionDate,
        memo: r.memo,
        createdAt: r.createdAt,
      );
}
