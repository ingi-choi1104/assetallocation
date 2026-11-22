import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assetallocation/data/database/app_database.dart';

/// `migrateKrStockAssetType()` — 계좌 가져오기가 저장해 온 `'stock_kr'`을
/// enum 값 `'krStock'`으로 통일하는 마이그레이션.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> insertAsset({
    required String symbol,
    required String assetType,
    String currency = 'KRW',
    String? name,
  }) =>
      db.into(db.assets).insert(AssetsCompanion.insert(
            symbol: symbol,
            name: name ?? symbol,
            assetType: assetType,
            currency: currency,
          ));

  Future<int> insertPortfolio(String name) =>
      db.into(db.portfolios).insert(PortfoliosCompanion.insert(name: name));

  Future<int> link(int portfolioId, int assetId) =>
      db.into(db.portfolioAssets).insert(PortfolioAssetsCompanion.insert(
            portfolioId: portfolioId,
            assetId: assetId,
            targetWeight: 0,
          ));

  Future<int> insertBuy(int portfolioAssetId, double qty) =>
      db.into(db.transactions).insert(TransactionsCompanion.insert(
            portfolioAssetId: portfolioAssetId,
            type: 'buy',
            quantity: qty,
            price: 1000,
            transactionDate: DateTime(2026, 1, 2),
          ));

  test('stock_kr 행이 krStock/KRW로 바뀐다', () async {
    await insertAsset(symbol: '005930', assetType: 'stock_kr', currency: 'USD');

    await db.assetDao.migrateKrStockAssetType();

    final row = await db.assetDao.getBySymbolAndType('005930', 'krStock');
    expect(row, isNotNull);
    expect(row!.currency, 'KRW');
    expect(await db.assetDao.getBySymbolAndType('005930', 'stock_kr'), isNull);
  });

  test('같은 symbol의 krStock 행이 이미 있으면 하나만 남는다', () async {
    await insertAsset(symbol: '005930', assetType: 'krStock');
    await insertAsset(symbol: '005930', assetType: 'stock_kr');

    await db.assetDao.migrateKrStockAssetType();

    final all = await db.assetDao.getAll();
    expect(all.where((a) => a.symbol == '005930').length, 1);
    expect(all.single.assetType, 'krStock');
  });

  test('중복 병합 시 portfolio_assets가 남은 행을 가리킨다', () async {
    final keep = await insertAsset(symbol: '005930', assetType: 'krStock');
    final dupe = await insertAsset(symbol: '005930', assetType: 'stock_kr');
    final portfolio = await insertPortfolio('테스트');
    await link(portfolio, dupe);

    await db.assetDao.migrateKrStockAssetType();

    final links = await db.select(db.portfolioAssets).get();
    expect(links.single.assetId, keep);
  });

  test('중복 자산이 같은 포트폴리오에 둘 다 연결돼 있어도 터지지 않고 거래가 보존된다',
      () async {
    final keep = await insertAsset(symbol: '005930', assetType: 'krStock');
    final dupe = await insertAsset(symbol: '005930', assetType: 'stock_kr');
    final portfolio = await insertPortfolio('테스트');
    final keepLink = await link(portfolio, keep);
    final dupeLink = await link(portfolio, dupe);
    await insertBuy(keepLink, 10);
    await insertBuy(dupeLink, 5);

    await db.assetDao.migrateKrStockAssetType();

    final links = await db.select(db.portfolioAssets).get();
    expect(links.length, 1, reason: '중복 연결은 하나로 합쳐진다');
    expect(links.single.assetId, keep);

    final txns = await db.select(db.transactions).get();
    expect(txns.length, 2, reason: '양쪽 거래가 모두 남아야 한다');
    expect(txns.every((t) => t.portfolioAssetId == links.single.id), isTrue);
  });

  // 여기까지는 DAO를 직접 부른다. 아래는 **실제 업그레이드 경로**를 돌린다 —
  // 이 경로가 던지면 기존 사용자의 앱이 시작되지 않는다. from < 3의
  // ALTER TABLE에는 IF NOT EXISTS가 없고 setSchemaVersion은 전략이 전부
  // 성공한 뒤에야 돌기 때문에, from < 4가 던지면 버전이 3에 머문 채
  // 다음 실행에서 "duplicate column name"으로 영구히 부팅 불가가 된다.
  group('v3 → v4 업그레이드', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aa_migration_test');
      dbFile = File('${tempDir.path}/test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    /// 현재 스키마로 만든 뒤 user_version을 3으로 되돌려 v3 DB를 흉내낸다.
    Future<void> seedV3(
      Future<void> Function(AppDatabase db) insertLegacyData,
    ) async {
      final seed = AppDatabase(NativeDatabase(dbFile));
      await insertLegacyData(seed);
      await seed.customStatement('PRAGMA user_version = 3');
      await seed.close();
    }

    test('앱을 열면 stock_kr 자산이 krStock으로 바뀐다', () async {
      await seedV3((seed) async {
        await seed.into(seed.assets).insert(AssetsCompanion.insert(
              symbol: '005930',
              name: '삼성전자',
              assetType: 'stock_kr',
              currency: 'KRW',
            ));
      });

      final upgraded = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgraded.close);

      final row =
          await upgraded.assetDao.getBySymbolAndType('005930', 'krStock');
      expect(row, isNotNull);
      expect(row!.name, '삼성전자');
      expect(upgraded.schemaVersion, 4);
    });

    test('중복 자산이 있어도 업그레이드가 터지지 않고 하나로 합쳐진다', () async {
      await seedV3((seed) async {
        final keep = await seed.into(seed.assets).insert(
              AssetsCompanion.insert(
                symbol: '005930',
                name: '삼성전자',
                assetType: 'krStock',
                currency: 'KRW',
              ),
            );
        final dupe = await seed.into(seed.assets).insert(
              AssetsCompanion.insert(
                symbol: '005930',
                name: '삼성전자',
                assetType: 'stock_kr',
                currency: 'KRW',
              ),
            );
        final portfolio = await seed
            .into(seed.portfolios)
            .insert(PortfoliosCompanion.insert(name: '테스트'));
        for (final assetId in [keep, dupe]) {
          await seed.into(seed.portfolioAssets).insert(
                PortfolioAssetsCompanion.insert(
                  portfolioId: portfolio,
                  assetId: assetId,
                  targetWeight: 0,
                ),
              );
        }
      });

      final upgraded = AppDatabase(NativeDatabase(dbFile));
      addTearDown(upgraded.close);

      final all = await upgraded.assetDao.getAll();
      expect(all.length, 1);
      expect(all.single.assetType, 'krStock');
      expect((await upgraded.select(upgraded.portfolioAssets).get()).length, 1);
    });
  });

  test('stock_kr 행이 없으면 아무 일도 없다', () async {
    await insertAsset(symbol: 'AAPL', assetType: 'usStock', currency: 'USD');

    await db.assetDao.migrateKrStockAssetType();

    final all = await db.assetDao.getAll();
    expect(all.single.assetType, 'usStock');
    expect(all.single.currency, 'USD');
  });
}
