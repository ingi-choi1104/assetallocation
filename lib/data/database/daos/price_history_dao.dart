import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/price_history_table.dart';

part 'price_history_dao.g.dart';

@DriftAccessor(tables: [PriceHistory])
class PriceHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$PriceHistoryDaoMixin {
  PriceHistoryDao(super.db);

  Future<List<PriceHistoryData>> getByAsset(
    int assetId, {
    int days = 365,
  }) {
    final since = DateTime.now().subtract(Duration(days: days));
    return (select(priceHistory)
          ..where((ph) =>
              ph.assetId.equals(assetId) &
              ph.date.isBiggerOrEqualValue(since))
          ..orderBy([(ph) => OrderingTerm.asc(ph.date)]))
        .get();
  }

  Future<void> insertOrReplace(PriceHistoryCompanion companion) =>
      into(priceHistory).insertOnConflictUpdate(companion);

  Future<void> insertManyOrReplace(
      List<PriceHistoryCompanion> companions) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(priceHistory, companions);
    });
  }

  Future<PriceHistoryData?> getLatest(int assetId) =>
      (select(priceHistory)
            ..where((ph) => ph.assetId.equals(assetId))
            ..orderBy([(ph) => OrderingTerm.desc(ph.date)])
            ..limit(1))
          .getSingleOrNull();
}
