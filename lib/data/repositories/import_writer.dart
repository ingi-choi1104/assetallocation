import 'package:drift/drift.dart';

import '../../domain/entities/import_table.dart';
import '../database/app_database.dart';

/// 확정된 [ImportRow] 목록을 DB에 쓴다. 파일 형식도 화면도 모른다 —
/// 거래 내역 가져오기(다음 확장)에서 그대로 재사용한다.
class ImportWriter {
  final AppDatabase _db;

  ImportWriter(this._db);

  /// 전체를 **하나의 트랜잭션**으로 쓴다. 중간에 실패하면 반쯤 들어간 상태가
  /// 남지 않아야 하고, 종목마다 쓰기를 날리면 조인된 drift `.watch()` 스트림이
  /// 매번 다시 발화해 화면이 버벅인다(백업 복원에서 겪은 문제).
  ///
  /// 돌려주는 값은 **실제로 등록된 종목 수**다. 이미 그 포트폴리오에 있던
  /// 종목은 건너뛰므로 [rows]의 길이와 다를 수 있다.
  Future<int> write({
    required int portfolioId,
    required List<ImportRow> rows,
    required String fileName,
    required double usdKrwRate,
  }) async {
    if (rows.isEmpty) return 0;

    final memo = '파일 가져오기: $fileName';
    final written = <ImportRow>[];

    await _db.transaction(() async {
      for (final row in rows) {
        final type = row.assetType;

        // {symbol, assetType}로 먼저 조회한다. insertOnConflictUpdate의
        // ON CONFLICT 타깃은 PK라 이 UNIQUE 충돌을 막아주지 못하고, 단일
        // 트랜잭션이므로 한 줄이 가져오기 전체를 실패시킨다.
        final existing =
            await _db.assetDao.getBySymbolAndType(row.symbol, type.value);

        final assetId = existing?.id ??
            await _db.assetDao.upsert(
              AssetsCompanion.insert(
                symbol: row.symbol,
                name: row.name,
                assetType: type.value,
                currency: type.currency,
                // 파일의 가격은 과거 시점 값인데 lastPriceUpdatedAt에 넣을
                // 날짜가 없다. 쓰면 낡은 값이 실시간 시세처럼 보인다.
              ),
            );

        // 화면이 alreadyHeld로 막지만, writer 혼자서도 전체를 실패시키면
        // 안 된다 — {portfolioId, assetId}에 UNIQUE가 걸려 있다.
        final alreadyLinked = await (_db.select(_db.portfolioAssets)
              ..where((pa) =>
                  pa.portfolioId.equals(portfolioId) &
                  pa.assetId.equals(assetId)))
            .getSingleOrNull();
        if (alreadyLinked != null) continue;

        final portfolioAssetId = await _db.portfolioAssetDao.insert(
          PortfolioAssetsCompanion.insert(
            portfolioId: portfolioId,
            assetId: assetId,
            targetWeight: 0,
          ),
        );

        final avgPrice = row.avgPrice;
        if (avgPrice != null) {
          await _db.transactionDao.insert(
            TransactionsCompanion.insert(
              portfolioAssetId: portfolioAssetId,
              type: 'buy',
              quantity: row.quantity,
              price: avgPrice,
              exchangeRate:
                  Value(type.currency == 'USD' ? usdKrwRate : 1.0),
              transactionDate: row.buyDate,
              memo: Value(memo),
            ),
          );
        }

        written.add(row);
      }

      // 연평균 수익률은 투자원금 목록이 비면 0을 반환한다. 기록하지 않으면
      // 12종목을 가져온 직후에도 연평균이 0%로 보여 고장 난 것처럼 보인다.
      final total = totalInvestmentKrw(written, usdKrwRate);
      if (total > 0) {
        await _db.investmentDao.insert(
          InvestmentsCompanion.insert(
            portfolioId: portfolioId,
            amount: total,
            investmentDate: earliestDate(written),
            memo: Value(memo),
          ),
        );
      }
    });

    return written.length;
  }

  /// 가져온 줄들의 `수량 × 평균단가` 합계, **원화**. 미국 종목은 환산한다.
  /// 평균단가가 없는 줄은 제외한다.
  static double totalInvestmentKrw(
    List<ImportRow> rows,
    double usdKrwRate,
  ) {
    var total = 0.0;
    for (final row in rows) {
      final price = row.avgPrice;
      if (price == null) continue;
      final amount = row.quantity * price;
      total += row.assetType.currency == 'USD' ? amount * usdKrwRate : amount;
    }
    return total;
  }

  /// 줄마다 매수일이 다르면 **가장 이른 날짜**를 쓴다 — 연평균의 보유기간이
  /// 과소평가되지 않게.
  static DateTime earliestDate(List<ImportRow> rows) {
    if (rows.isEmpty) {
      throw ArgumentError('빈 목록에는 취득일이 없습니다');
    }
    var earliest = rows.first.buyDate;
    for (final row in rows) {
      if (row.buyDate.isBefore(earliest)) earliest = row.buyDate;
    }
    return earliest;
  }
}
