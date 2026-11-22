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

  /// One-time migration: 계좌 가져오기(KIS) 화면이 한국 종목을
  /// `assetType: 'stock_kr'`로 저장해 왔는데, `AssetType`의 실제 값은
  /// `'krStock'`이다. `AssetType.fromValue('stock_kr')`는 `orElse`로 빠져
  /// **`usStock`을 반환**하므로 그 자산들은 미국 주식으로 읽히고, 쓰기 경로를
  /// 고치면 같은 종목이 `krStock`으로 한 번 더 생겨 중복된다.
  ///
  /// 그래서 이름만 바꾸는 게 아니라 **중복을 병합**한다. 같은 symbol의
  /// `krStock` 행이 이미 있으면 포트폴리오 연결과 거래 기록을 그쪽으로 옮기고
  /// `stock_kr` 행을 지운다.
  ///
  /// 문자열은 일부러 리터럴로 박아 둔다 — 마이그레이션은 과거에 일어난 일을
  /// 되돌리는 코드이므로, 나중에 enum 값이 바뀌어도 하던 일을 그대로 해야 한다.
  Future<void> migrateKrStockAssetType() async {
    const legacyType = 'stock_kr';
    const krStockType = 'krStock';

    final legacyRows =
        await (select(assets)..where((a) => a.assetType.equals(legacyType)))
            .get();
    if (legacyRows.isEmpty) return;

    final db = attachedDatabase;

    await db.transaction(() async {
      for (final legacy in legacyRows) {
        final keeper = await (select(assets)
              ..where((a) =>
                  a.symbol.equals(legacy.symbol) &
                  a.assetType.equals(krStockType)))
            .getSingleOrNull();

        // 충돌 없음 — 이름표만 바꿔 준다.
        if (keeper == null) {
          await (update(assets)..where((a) => a.id.equals(legacy.id))).write(
            const AssetsCompanion(
              assetType: Value(krStockType),
              currency: Value('KRW'),
            ),
          );
          continue;
        }

        // 충돌 — legacy 행을 keeper로 접어 넣고 지운다.
        final legacyLinks = await (db.select(db.portfolioAssets)
              ..where((pa) => pa.assetId.equals(legacy.id)))
            .get();

        for (final legacyLink in legacyLinks) {
          final keeperLink = await (db.select(db.portfolioAssets)
                ..where((pa) =>
                    pa.portfolioId.equals(legacyLink.portfolioId) &
                    pa.assetId.equals(keeper.id)))
              .getSingleOrNull();

          if (keeperLink == null) {
            await (db.update(db.portfolioAssets)
                  ..where((pa) => pa.id.equals(legacyLink.id)))
                .write(PortfolioAssetsCompanion(assetId: Value(keeper.id)));
            continue;
          }

          // 같은 포트폴리오에 양쪽이 다 연결돼 있다. 거래를 keeper 쪽으로
          // 옮기고 중복 연결을 지운다 — 그냥 두면 {portfolioId, assetId}
          // UNIQUE가 터져 onUpgrade 전체가 실패하고 앱이 시작되지 않는다.
          await (db.update(db.transactions)
                ..where((t) => t.portfolioAssetId.equals(legacyLink.id)))
              .write(
            TransactionsCompanion(portfolioAssetId: Value(keeperLink.id)),
          );
          await (db.delete(db.portfolioAssets)
                ..where((pa) => pa.id.equals(legacyLink.id)))
              .go();
        }

        await (delete(assets)..where((a) => a.id.equals(legacy.id))).go();
      }
    });
  }

  Future<void> updateNameBySymbol(String symbol, String name) =>
      (update(assets)..where((a) => a.symbol.equals(symbol)))
          .write(AssetsCompanion(name: Value(name)));
}
