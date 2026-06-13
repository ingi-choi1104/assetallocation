import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/assets_table.dart';

part 'asset_dao.g.dart';

@DriftAccessor(tables: [Assets])
class AssetDao extends DatabaseAccessor<AppDatabase>
    with _$AssetDaoMixin {
  AssetDao(super.db);

  Future<List<AssetRecord>> getAll() => select(assets).get();

  Future<AssetRecord?> getById(int id) =>
      (select(assets)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<AssetRecord?> getBySymbolAndType(
          String symbol, String assetType) =>
      (select(assets)
            ..where((a) =>
                a.symbol.equals(symbol) & a.assetType.equals(assetType)))
          .getSingleOrNull();

  Future<int> upsert(AssetsCompanion companion) =>
      into(assets).insertOnConflictUpdate(companion);

  Future<void> updateLastPrice(int id, double price) =>
      (update(assets)..where((a) => a.id.equals(id))).write(
        AssetsCompanion(
          lastPrice: Value(price),
          lastPriceUpdatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> updateLastPriceAndPreviousClose(
    int id,
    double price,
    double? previousClose,
  ) =>
      (update(assets)..where((a) => a.id.equals(id))).write(
        AssetsCompanion(
          lastPrice: Value(price),
          lastPreviousClose: Value(previousClose),
          lastPriceUpdatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> updateNameBySymbol(String symbol, String name) =>
      (update(assets)..where((a) => a.symbol.equals(symbol)))
          .write(AssetsCompanion(name: Value(name)));
}
