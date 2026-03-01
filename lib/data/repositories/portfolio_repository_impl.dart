import 'package:drift/drift.dart';
import '../../domain/entities/portfolio.dart';
import '../../domain/repositories/portfolio_repository.dart';
import '../database/app_database.dart';

class PortfolioRepositoryImpl implements PortfolioRepository {
  final AppDatabase _db;

  PortfolioRepositoryImpl(this._db);

  @override
  Stream<List<Portfolio>> watchAllPortfolios() =>
      _db.portfolioDao.watchAll().map(
            (rows) => rows.map(_toEntity).toList(),
          );

  @override
  Future<List<Portfolio>> getAllPortfolios() async {
    final rows = await _db.portfolioDao.getAll();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<Portfolio?> getPortfolioById(int id) async {
    final row = await _db.portfolioDao.getById(id);
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<int> createPortfolio(Portfolio portfolio) {
    return _db.portfolioDao.insert(
      PortfoliosCompanion.insert(
        name: portfolio.name,
        description: Value(portfolio.description),
        baseCurrency: Value(portfolio.baseCurrency),
        rebalancePeriod: Value(portfolio.rebalancePeriod),
        nextRebalanceDate: Value(portfolio.nextRebalanceDate),
        deviationThreshold: Value(portfolio.deviationThreshold),
      ),
    );
  }

  @override
  Future<void> updatePortfolio(Portfolio portfolio) async {
    await _db.portfolioDao.update_(
      PortfoliosCompanion(
        id: Value(portfolio.id),
        name: Value(portfolio.name),
        description: Value(portfolio.description),
        baseCurrency: Value(portfolio.baseCurrency),
        rebalancePeriod: Value(portfolio.rebalancePeriod),
        nextRebalanceDate: Value(portfolio.nextRebalanceDate),
        deviationThreshold: Value(portfolio.deviationThreshold),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deletePortfolio(int id) async {
    await _db.portfolioDao.deleteById(id);
  }

  Portfolio _toEntity(PortfolioRecord r) => Portfolio(
        id: r.id,
        name: r.name,
        description: r.description,
        baseCurrency: r.baseCurrency,
        rebalancePeriod: r.rebalancePeriod,
        nextRebalanceDate: r.nextRebalanceDate,
        deviationThreshold: r.deviationThreshold,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );
}
