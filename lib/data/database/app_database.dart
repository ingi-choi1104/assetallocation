import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/portfolios_table.dart';
import 'tables/assets_table.dart';
import 'tables/portfolio_assets_table.dart';
import 'tables/transactions_table.dart';
import 'tables/price_history_table.dart';
import 'tables/investments_table.dart';
import 'daos/portfolio_dao.dart';
import 'daos/asset_dao.dart';
import 'daos/portfolio_asset_dao.dart';
import 'daos/transaction_dao.dart';
import 'daos/price_history_dao.dart';
import 'daos/investment_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Portfolios,
    Assets,
    PortfolioAssets,
    Transactions,
    PriceHistory,
    Investments,
  ],
  daos: [
    PortfolioDao,
    AssetDao,
    PortfolioAssetDao,
    TransactionDao,
    PriceHistoryDao,
    InvestmentDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'asset_allocation'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(investments);
          }
          if (from < 3) {
            await m.addColumn(assets, assets.lastPreviousClose);
          }
          if (from < 4) {
            // 계좌 가져오기가 저장해 온 'stock_kr'을 AssetType의 실제 값
            // 'krStock'으로 통일하고, 그 과정에서 생기는 중복 자산을 병합한다.
            //
            // 과거 데이터 청소이므로 **절대 앱 시작을 막아선 안 된다.**
            // from < 3의 ALTER TABLE에는 IF NOT EXISTS가 없고
            // setSchemaVersion은 전략이 전부 성공한 뒤에야 돌기 때문에,
            // 여기서 던지면 버전이 그대로 남아 다음 실행에서
            // "duplicate column name"으로 영구히 부팅 불가가 된다.
            // 실패하면 중복 자산이 남을 뿐이고, 그건 사용자가 고칠 수 있다.
            try {
              await assetDao.migrateKrStockAssetType();
            } catch (_) {
              // 의도적으로 삼킨다 — 위 주석 참조.
            }
          }
        },
      );
}
