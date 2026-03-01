import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/portfolio_assets_table.dart';
import '../tables/assets_table.dart';

part 'portfolio_asset_dao.g.dart';

class PortfolioAssetWithAsset {
  final PortfolioAssetRecord portfolioAsset;
  final AssetRecord asset;

  PortfolioAssetWithAsset(this.portfolioAsset, this.asset);
}

@DriftAccessor(tables: [PortfolioAssets, Assets])
class PortfolioAssetDao extends DatabaseAccessor<AppDatabase>
    with _$PortfolioAssetDaoMixin {
  PortfolioAssetDao(super.db);

  Stream<List<PortfolioAssetWithAsset>> watchByPortfolio(
      int portfolioId) {
    final query = select(portfolioAssets).join([
      innerJoin(assets, assets.id.equalsExp(portfolioAssets.assetId)),
    ])
      ..where(portfolioAssets.portfolioId.equals(portfolioId))
      ..orderBy([OrderingTerm.asc(portfolioAssets.sortOrder)]);

    return query.watch().map((rows) => rows
        .map((row) => PortfolioAssetWithAsset(
              row.readTable(portfolioAssets),
              row.readTable(assets),
            ))
        .toList());
  }

  Future<List<PortfolioAssetWithAsset>> getByPortfolio(
      int portfolioId) async {
    final query = select(portfolioAssets).join([
      innerJoin(assets, assets.id.equalsExp(portfolioAssets.assetId)),
    ])
      ..where(portfolioAssets.portfolioId.equals(portfolioId))
      ..orderBy([OrderingTerm.asc(portfolioAssets.sortOrder)]);

    final rows = await query.get();
    return rows
        .map((row) => PortfolioAssetWithAsset(
              row.readTable(portfolioAssets),
              row.readTable(assets),
            ))
        .toList();
  }

  Future<int> insert(PortfolioAssetsCompanion companion) =>
      into(portfolioAssets).insert(companion);

  Future<void> updateWeight(int id, double weight) =>
      (update(portfolioAssets)..where((pa) => pa.id.equals(id))).write(
        PortfolioAssetsCompanion(targetWeight: Value(weight)),
      );

  Future<int> deleteById(int id) =>
      (delete(portfolioAssets)..where((pa) => pa.id.equals(id))).go();

  Future<PortfolioAssetRecord?> getById(int id) =>
      (select(portfolioAssets)..where((pa) => pa.id.equals(id)))
          .getSingleOrNull();

  Future<void> updateSortOrders(Map<int, int> idToSortOrder) async {
    await batch((b) {
      for (final entry in idToSortOrder.entries) {
        b.update(
          portfolioAssets,
          PortfolioAssetsCompanion(sortOrder: Value(entry.value)),
          where: (pa) => pa.id.equals(entry.key),
        );
      }
    });
  }
}
