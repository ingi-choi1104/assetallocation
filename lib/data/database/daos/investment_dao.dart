import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/investments_table.dart';

part 'investment_dao.g.dart';

@DriftAccessor(tables: [Investments])
class InvestmentDao extends DatabaseAccessor<AppDatabase>
    with _$InvestmentDaoMixin {
  InvestmentDao(super.db);

  Stream<List<InvestmentRecord>> watchByPortfolio(int portfolioId) =>
      (select(investments)
            ..where((i) => i.portfolioId.equals(portfolioId))
            ..orderBy([(i) => OrderingTerm.desc(i.investmentDate)]))
          .watch();

  Future<List<InvestmentRecord>> getByPortfolio(int portfolioId) =>
      (select(investments)
            ..where((i) => i.portfolioId.equals(portfolioId))
            ..orderBy([(i) => OrderingTerm.asc(i.investmentDate)]))
          .get();

  Future<int> insert(InvestmentsCompanion companion) =>
      into(investments).insert(companion);

  Future<void> updateById(
    int id, {
    required double amount,
    required DateTime investmentDate,
    String? memo,
  }) =>
      (update(investments)..where((i) => i.id.equals(id))).write(
        InvestmentsCompanion(
          amount: Value(amount),
          investmentDate: Value(investmentDate),
          memo: Value(memo),
        ),
      );

  Future<int> deleteById(int id) =>
      (delete(investments)..where((i) => i.id.equals(id))).go();
}
