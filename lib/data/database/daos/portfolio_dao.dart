import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/portfolios_table.dart';

part 'portfolio_dao.g.dart';

@DriftAccessor(tables: [Portfolios])
class PortfolioDao extends DatabaseAccessor<AppDatabase>
    with _$PortfolioDaoMixin {
  PortfolioDao(super.db);

  Stream<List<PortfolioRecord>> watchAll() => select(portfolios).watch();

  Future<List<PortfolioRecord>> getAll() => select(portfolios).get();

  Future<PortfolioRecord?> getById(int id) =>
      (select(portfolios)..where((p) => p.id.equals(id)))
          .getSingleOrNull();

  Future<int> insert(PortfoliosCompanion companion) =>
      into(portfolios).insert(companion);

  Future<bool> update_(PortfoliosCompanion companion) =>
      update(portfolios).replace(companion);

  Future<int> deleteById(int id) =>
      (delete(portfolios)..where((p) => p.id.equals(id))).go();
}
