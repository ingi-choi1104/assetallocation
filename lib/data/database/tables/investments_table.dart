import 'package:drift/drift.dart';
import 'portfolios_table.dart';

@DataClassName('InvestmentRecord')
class Investments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get portfolioId =>
      integer().references(Portfolios, #id)();
  RealColumn get amount => real()(); // KRW
  DateTimeColumn get investmentDate => dateTime()();
  TextColumn get memo => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
