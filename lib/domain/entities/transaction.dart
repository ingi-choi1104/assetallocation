import 'package:freezed_annotation/freezed_annotation.dart';
import '../enums/transaction_type.dart';

part 'transaction.freezed.dart';

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required int id,
    required int portfolioAssetId,
    required TransactionType type,
    required double quantity,
    required double price,
    required double exchangeRate,
    required double fee,
    required DateTime transactionDate,
    String? memo,
    required DateTime createdAt,
  }) = _Transaction;

  const Transaction._();

  /// Total cost in asset's native currency
  double get totalCost => price * quantity + fee;

  /// Total cost in KRW
  double get totalCostKrw => totalCost * exchangeRate;
}
