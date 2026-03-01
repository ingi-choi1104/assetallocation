import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/transactions_table.dart';

part 'transaction_dao.g.dart';

@DriftAccessor(tables: [Transactions])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Stream<List<TransactionRecord>> watchByPortfolioAsset(
          int portfolioAssetId) =>
      (select(transactions)
            ..where((t) => t.portfolioAssetId.equals(portfolioAssetId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.transactionDate),
            ]))
          .watch();

  Future<List<TransactionRecord>> getByPortfolioAsset(
          int portfolioAssetId) =>
      (select(transactions)
            ..where((t) => t.portfolioAssetId.equals(portfolioAssetId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.transactionDate),
            ]))
          .get();

  Future<int> insert(TransactionsCompanion companion) =>
      into(transactions).insert(companion);

  Future<int> deleteById(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();
}
