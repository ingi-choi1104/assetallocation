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

  /// Writes many price updates in a single batch so Drift emits only ONE
  /// change notification for the assets table (instead of one per asset).
  /// Prevents a stream/rebuild storm during background price refresh.
  Future<void> updatePricesBatch(
    Map<int, ({double price, double? previousClose})> updates,
  ) async {
    if (updates.isEmpty) return;
    final now = DateTime.now();
    await batch((b) {
      updates.forEach((id, v) {
        b.update(
          assets,
          AssetsCompanion(
            lastPrice: Value(v.price),
            lastPreviousClose: Value(v.previousClose),
            lastPriceUpdatedAt: Value(now),
          ),
          where: (a) => a.id.equals(id),
        );
      });
    });
  }

  /// One-time migration: gold assets are now priced as 국내 금 현물 (KRX, 원/g),
  /// so their currency must be KRW instead of the old USD/oz basis. The stale
  /// USD lastPrice is cleared so a wrong value isn't shown before the next
  /// price refresh repopulates it in KRW/gram.
  Future<void> migrateGoldCurrencyToKrw() async {
    await (update(assets)
          ..where((a) => a.assetType.equals('gold') & a.currency.equals('USD')))
        .write(const AssetsCompanion(
      currency: Value('KRW'),
      lastPrice: Value(null),
      lastPreviousClose: Value(null),
    ));
  }

  Future<void> updateNameBySymbol(String symbol, String name) =>
      (update(assets)..where((a) => a.symbol.equals(symbol)))
          .write(AssetsCompanion(name: Value(name)));
}
