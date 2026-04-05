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
  int get schemaVersion => 3;

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
        },
      );
}
