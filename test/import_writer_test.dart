import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assetallocation/data/database/app_database.dart';
import 'package:assetallocation/domain/entities/import_table.dart';
import 'package:assetallocation/domain/enums/asset_type.dart';
import 'package:assetallocation/data/repositories/import_writer.dart';

ImportRow _row({
  required String symbol,
  required AssetType type,
  double qty = 1,
  double? price,
  DateTime? date,
  String? name,
}) =>
    ImportRow(
      rowIndex: 0,
      symbol: symbol,
      name: name ?? symbol,
      quantity: qty,
      avgPrice: price,
      currentPrice: null,
      buyDate: date ?? DateTime(2026, 1, 2),
      assetType: type,
    );

ImportRow _kr({double qty = 1, double? price, DateTime? date}) =>
    _row(symbol: '005930', type: AssetType.krStock, qty: qty, price: price, date: date);

ImportRow _us({double qty = 1, double? price, DateTime? date}) =>
    _row(symbol: 'QQQ', type: AssetType.usStock, qty: qty, price: price, date: date);

void main() {
  group('totalInvestmentKrw', () {
    test('한국 종목은 수량×평단 그대로', () {
      expect(
        ImportWriter.totalInvestmentKrw([_kr(qty: 10, price: 71200)], 1400),
        712000,
      );
    });

    test('미국 종목은 환율로 환산한다', () {
      expect(
        ImportWriter.totalInvestmentKrw([_us(qty: 5, price: 100)], 1400),
        700000,
      );
    });

    test('섞여 있으면 합산한다', () {
      expect(
        ImportWriter.totalInvestmentKrw(
          [_kr(qty: 10, price: 71200), _us(qty: 5, price: 100)],
          1400,
        ),
        1412000,
      );
    });

    test('avgPrice가 null인 줄은 합계에서 제외한다', () {
      expect(ImportWriter.totalInvestmentKrw([_kr(qty: 10)], 1400), 0);
    });

    test('빈 목록은 0', () {
      expect(ImportWriter.totalInvestmentKrw([], 1400), 0);
    });
  });

  group('earliestDate', () {
    test('줄마다 날짜가 다르면 가장 이른 날짜', () {
      final rows = [
        _kr(date: DateTime(2026, 5, 1)),
        _us(date: DateTime(2025, 3, 4)),
        _row(symbol: 'SPY', type: AssetType.usStock, date: DateTime(2026, 1, 1)),
      ];
      expect(ImportWriter.earliestDate(rows), DateTime(2025, 3, 4));
    });

    test('한 줄이면 그 날짜', () {
      expect(
        ImportWriter.earliestDate([_kr(date: DateTime(2024, 7, 9))]),
        DateTime(2024, 7, 9),
      );
    });
  });

  group('write', () {
    late AppDatabase db;
    late ImportWriter writer;
    late int portfolioId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      writer = ImportWriter(db);
      portfolioId = await db.portfolioDao
          .insert(PortfoliosCompanion.insert(name: '테스트'));
    });

    tearDown(() => db.close());

    test('자산·포트폴리오연결·거래·투자원금을 모두 만든다', () async {
      final count = await writer.write(
        portfolioId: portfolioId,
        rows: [_kr(qty: 10, price: 71200, date: DateTime(2025, 3, 4))],
        fileName: '잔고.csv',
        usdKrwRate: 1400,
      );

      expect(count, 1);

      final asset = await db.assetDao.getBySymbolAndType('005930', 'krStock');
      expect(asset, isNotNull);
      expect(asset!.currency, 'KRW');
      expect(asset.lastPrice, isNull, reason: '파일 가격을 시세로 쓰지 않는다');

      final links = await db.select(db.portfolioAssets).get();
      expect(links.single.assetId, asset.id);
      expect(links.single.targetWeight, 0);

      final txns = await db.select(db.transactions).get();
      expect(txns.single.type, 'buy');
      expect(txns.single.quantity, 10);
      expect(txns.single.price, 71200);
      expect(txns.single.transactionDate, DateTime(2025, 3, 4));
      expect(txns.single.memo, '파일 가져오기: 잔고.csv');

      final investments = await db.select(db.investments).get();
      expect(investments.single.amount, 712000);
      expect(investments.single.investmentDate, DateTime(2025, 3, 4));
    });

    test('이미 있는 자산은 다시 만들지 않고 그 id를 쓴다', () async {
      final existing = await db.into(db.assets).insert(
            AssetsCompanion.insert(
              symbol: '005930',
              name: '삼성전자',
              assetType: 'krStock',
              currency: 'KRW',
            ),
          );

      await writer.write(
        portfolioId: portfolioId,
        rows: [_kr(qty: 10, price: 71200)],
        fileName: 'a.csv',
        usdKrwRate: 1400,
      );

      final assets = await db.assetDao.getAll();
      expect(assets.length, 1, reason: '{symbol, assetType} UNIQUE를 안 터뜨린다');

      final links = await db.select(db.portfolioAssets).get();
      expect(links.single.assetId, existing);
    });

    test('미국 종목은 환율을 거래에 기록한다', () async {
      await writer.write(
        portfolioId: portfolioId,
        rows: [_us(qty: 5, price: 100)],
        fileName: 'a.csv',
        usdKrwRate: 1400,
      );

      final txns = await db.select(db.transactions).get();
      expect(txns.single.exchangeRate, 1400);

      final investments = await db.select(db.investments).get();
      expect(investments.single.amount, 700000);
    });

    test('한국 종목의 환율은 1이다', () async {
      await writer.write(
        portfolioId: portfolioId,
        rows: [_kr(qty: 10, price: 71200)],
        fileName: 'a.csv',
        usdKrwRate: 1400,
      );

      final txns = await db.select(db.transactions).get();
      expect(txns.single.exchangeRate, 1);
    });

    test('평균단가가 없으면 종목만 등록하고 거래·투자원금은 안 만든다', () async {
      final count = await writer.write(
        portfolioId: portfolioId,
        rows: [_kr(qty: 10)],
        fileName: 'a.csv',
        usdKrwRate: 1400,
      );

      expect(count, 1);
      expect((await db.select(db.portfolioAssets).get()).length, 1);
      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await db.select(db.investments).get(), isEmpty);
    });

    test('가져올 줄이 없으면 아무것도 쓰지 않고 0을 돌려준다', () async {
      final count = await writer.write(
        portfolioId: portfolioId,
        rows: [],
        fileName: 'a.csv',
        usdKrwRate: 1400,
      );

      expect(count, 0);
      expect(await db.assetDao.getAll(), isEmpty);
      expect(await db.select(db.portfolioAssets).get(), isEmpty);
      expect(await db.select(db.investments).get(), isEmpty);
    });

    test('투자원금은 여러 줄이어도 한 건이고 가장 이른 날짜를 쓴다', () async {
      await writer.write(
        portfolioId: portfolioId,
        rows: [
          _kr(qty: 10, price: 71200, date: DateTime(2026, 5, 1)),
          _us(qty: 5, price: 100, date: DateTime(2025, 3, 4)),
        ],
        fileName: 'a.csv',
        usdKrwRate: 1400,
      );

      final investments = await db.select(db.investments).get();
      expect(investments.length, 1);
      expect(investments.single.amount, 1412000);
      expect(investments.single.investmentDate, DateTime(2025, 3, 4));
    });

    test('거래는 줄마다 하나씩 만든다', () async {
      await writer.write(
        portfolioId: portfolioId,
        rows: [
          _kr(qty: 10, price: 71200),
          _us(qty: 5, price: 100),
        ],
        fileName: 'a.csv',
        usdKrwRate: 1400,
      );

      expect((await db.select(db.transactions).get()).length, 2);
      expect((await db.select(db.portfolioAssets).get()).length, 2);
    });

    test('이미 그 포트폴리오에 연결된 종목이면 터지지 않고 건너뛴다', () async {
      // 화면이 alreadyHeld로 막지만, writer 혼자서도 전체를 실패시키면 안 된다.
      final assetId = await db.into(db.assets).insert(
            AssetsCompanion.insert(
              symbol: '005930',
              name: '삼성전자',
              assetType: 'krStock',
              currency: 'KRW',
            ),
          );
      await db.portfolioAssetDao.insert(PortfolioAssetsCompanion.insert(
        portfolioId: portfolioId,
        assetId: assetId,
        targetWeight: 0,
      ));

      final count = await writer.write(
        portfolioId: portfolioId,
        rows: [_kr(qty: 10, price: 71200)],
        fileName: 'a.csv',
        usdKrwRate: 1400,
      );

      expect(count, 0);
      expect((await db.select(db.portfolioAssets).get()).length, 1);
      expect(await db.select(db.transactions).get(), isEmpty);
    });
  });
}
