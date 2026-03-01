import 'package:drift/drift.dart';
import 'assets_table.dart';

@DataClassName('PriceHistoryData')
class PriceHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assetId => integer().references(Assets, #id)();
  RealColumn get closePrice => real()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get fetchedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {assetId, date},
      ];
}
