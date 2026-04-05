import 'package:drift/drift.dart';

@DataClassName('AssetRecord')
class Assets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get symbol => text()();
  TextColumn get name => text()();
  TextColumn get assetType => text()();
  TextColumn get currency => text()();
  TextColumn get fundCode => text().nullable()();
  RealColumn get lastPrice => real().nullable()();
  RealColumn get lastPreviousClose => real().nullable()();
  DateTimeColumn get lastPriceUpdatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {symbol, assetType},
      ];
}
