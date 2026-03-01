import 'package:drift/drift.dart';
import 'portfolio_assets_table.dart';

@DataClassName('TransactionRecord')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get portfolioAssetId =>
      integer().references(PortfolioAssets, #id)();
  TextColumn get type => text()();
  RealColumn get quantity => real()();
  RealColumn get price => real()();
  RealColumn get exchangeRate =>
      real().withDefault(const Constant(1.0))();
  RealColumn get fee => real().withDefault(const Constant(0.0))();
  DateTimeColumn get transactionDate => dateTime()();
  TextColumn get memo => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
