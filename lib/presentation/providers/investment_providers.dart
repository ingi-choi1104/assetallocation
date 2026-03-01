import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../domain/entities/investment.dart';
import 'database_providers.dart';

// ── Watch investments for a portfolio ─────────────────────────────────────────
final investmentsStreamProvider =
    StreamProvider.family<List<Investment>, int>((ref, portfolioId) {
  final db = ref.watch(appDatabaseProvider);
  return db.investmentDao.watchByPortfolio(portfolioId).map(
        (rows) => rows
            .map((r) => Investment(
                  id: r.id,
                  portfolioId: r.portfolioId,
                  amount: r.amount,
                  investmentDate: r.investmentDate,
                  memo: r.memo,
                  createdAt: r.createdAt,
                ))
            .toList(),
      );
});

// ── Get investments (future, sorted ascending by date) ───────────────────────
final investmentsFutureProvider =
    FutureProvider.family<List<Investment>, int>((ref, portfolioId) async {
  final db = ref.watch(appDatabaseProvider);
  final rows = await db.investmentDao.getByPortfolio(portfolioId);
  return rows
      .map((r) => Investment(
            id: r.id,
            portfolioId: r.portfolioId,
            amount: r.amount,
            investmentDate: r.investmentDate,
            memo: r.memo,
            createdAt: r.createdAt,
          ))
      .toList();
});

// ── Investment actions ────────────────────────────────────────────────────────
class InvestmentActions {
  final Ref _ref;
  InvestmentActions(this._ref);

  Future<int> add({
    required int portfolioId,
    required double amount,
    required DateTime date,
    String? memo,
  }) {
    final db = _ref.read(appDatabaseProvider);
    return db.investmentDao.insert(InvestmentsCompanion.insert(
      portfolioId: portfolioId,
      amount: amount,
      investmentDate: date,
      memo: Value(memo),
    ));
  }

  Future<void> update({
    required int id,
    required double amount,
    required DateTime date,
    String? memo,
  }) {
    final db = _ref.read(appDatabaseProvider);
    return db.investmentDao.updateById(
      id,
      amount: amount,
      investmentDate: date,
      memo: memo,
    );
  }

  Future<int> delete(int id) {
    final db = _ref.read(appDatabaseProvider);
    return db.investmentDao.deleteById(id);
  }
}

final investmentActionsProvider = Provider<InvestmentActions>((ref) {
  return InvestmentActions(ref);
});
