import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/transaction.dart';
import 'database_providers.dart';

// ── Transaction stream per portfolio asset ────────────────────────────────────
final transactionsStreamProvider =
    StreamProvider.family<List<Transaction>, int>((ref, portfolioAssetId) {
  return ref
      .watch(assetRepositoryProvider)
      .watchTransactions(portfolioAssetId);
});

// ── Transaction actions ────────────────────────────────────────────────────────
class TransactionActions {
  final Ref _ref;
  TransactionActions(this._ref);

  Future<int> addTransaction(Transaction transaction) {
    return _ref.read(assetRepositoryProvider).addTransaction(transaction);
  }

  Future<void> deleteTransaction(int transactionId) {
    return _ref
        .read(assetRepositoryProvider)
        .deleteTransaction(transactionId);
  }
}

final transactionActionsProvider =
    Provider<TransactionActions>((ref) {
  return TransactionActions(ref);
});
