import 'package:drift/drift.dart';

@DataClassName('PortfolioRecord')
class Portfolios extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  TextColumn get baseCurrency =>
      text().withDefault(const Constant('KRW'))();
  TextColumn get rebalancePeriod => text().nullable()();
  DateTimeColumn get nextRebalanceDate => dateTime().nullable()();
  RealColumn get deviationThreshold =>
      real().withDefault(const Constant(5.0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
