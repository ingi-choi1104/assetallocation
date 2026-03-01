import 'package:drift/drift.dart';
import 'portfolios_table.dart';
import 'assets_table.dart';

@DataClassName('PortfolioAssetRecord')
class PortfolioAssets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get portfolioId =>
      integer().references(Portfolios, #id)();
  IntColumn get assetId => integer().references(Assets, #id)();
  RealColumn get targetWeight => real()();
  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {portfolioId, assetId},
      ];
}
