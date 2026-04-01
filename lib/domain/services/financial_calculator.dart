import 'dart:math' as math;
import '../entities/transaction.dart';
import '../enums/transaction_type.dart';

class CashFlow {
  final double amount;
  final int daysElapsed;

  const CashFlow({required this.amount, required this.daysElapsed});
}

class PortfolioMetrics {
  final double totalValue;
  final double totalInvested;
  final double returnRate;
  final double annualizedReturnRate;
  final double annualizedStdDev;
  final double maxDrawdown;

  const PortfolioMetrics({
    required this.totalValue,
    required this.totalInvested,
    required this.returnRate,
    this.annualizedReturnRate = 0,
    required this.annualizedStdDev,
    required this.maxDrawdown,
  });

  double get absoluteReturn => totalValue - totalInvested;
}

class RebalancingGap {
  final int assetId;
  final String assetName;
  final String symbol; // ticker/code (e.g. '005930' for Samsung)
  final double currentWeight;
  final double targetWeight;
  final double gap;
  final double currentValue;
  final double pricePerUnit; // native currency price
  final double holdings; // current quantity held
  final String currency; // 'USD' or 'KRW'
  final String assetType; // e.g. 'gold', 'usStock', etc.
  final double totalPortfolioValue; // total portfolio value in KRW

  const RebalancingGap({
    required this.assetId,
    required this.assetName,
    this.symbol = '',
    required this.currentWeight,
    required this.targetWeight,
    required this.gap,
    required this.currentValue,
    this.pricePerUnit = 0,
    this.holdings = 0,
    this.currency = 'KRW',
    this.assetType = '',
    this.totalPortfolioValue = 0,
  });

  bool get needsRebalancing => gap.abs() >= 0;
}

class FinancialCalculator {
  FinancialCalculator._();

  /// Modified Dietz Method for return calculation
  static double modifiedDietz({
    required double emv,
    required double bmv,
    required List<CashFlow> cashFlows,
    required int totalDays,
  }) {
    final cf = cashFlows.fold(0.0, (sum, c) => sum + c.amount);
    final wcf = totalDays == 0
        ? 0.0
        : cashFlows.fold(
            0.0,
            (sum, c) =>
                sum + c.amount * (totalDays - c.daysElapsed) / totalDays,
          );

    final denominator = bmv + wcf;
    if (denominator == 0) return 0;
    return (emv - bmv - cf) / denominator;
  }

  /// Calculate Modified Dietz return from transactions and current value
  static double calculateReturn({
    required List<Transaction> transactions,
    required double currentValue,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    if (transactions.isEmpty) return 0;

    final totalDays = endDate.difference(startDate).inDays;
    if (totalDays <= 0) return 0;

    final cashFlows = <CashFlow>[];

    for (final tx in transactions) {
      final daysElapsed = tx.transactionDate.difference(startDate).inDays;
      if (daysElapsed < 0) continue;

      final amount = tx.type == TransactionType.buy
          ? tx.totalCostKrw
          : -tx.totalCostKrw;

      cashFlows.add(CashFlow(amount: amount, daysElapsed: daysElapsed));
    }

    return modifiedDietz(
      emv: currentValue,
      bmv: 0,
      cashFlows: cashFlows,
      totalDays: totalDays,
    );
  }

  /// Annualized standard deviation from daily log returns
  static double annualizedStdDev(List<double> prices) {
    if (prices.length < 2) return 0;

    final returns = <double>[];
    for (int i = 1; i < prices.length; i++) {
      if (prices[i - 1] > 0 && prices[i] > 0) {
        returns.add(math.log(prices[i] / prices[i - 1]));
      }
    }

    if (returns.length < 2) return 0;

    final mean = returns.reduce((a, b) => a + b) / returns.length;
    final variance = returns.fold(
          0.0,
          (sum, r) => sum + math.pow(r - mean, 2),
        ) /
        (returns.length - 1);

    return math.sqrt(variance) * math.sqrt(252);
  }

  /// Maximum drawdown using single-pass O(n) algorithm
  static double maxDrawdown(List<double> prices) {
    if (prices.length < 2) return 0;

    double peak = prices.first;
    double maxDd = 0;

    for (final price in prices) {
      if (price > peak) {
        peak = price;
      } else if (peak > 0) {
        final dd = (price - peak) / peak;
        if (dd < maxDd) maxDd = dd;
      }
    }

    return maxDd;
  }

  /// Calculate current weights and gaps for rebalancing
  static List<RebalancingGap> rebalancingGaps({
    required Map<int, String> assetNames,
    required Map<int, double> currentValues,
    required Map<int, double> targetWeights,
    Map<int, double> pricesPerUnit = const {},
    Map<int, double> holdingsMap = const {},
    Map<int, String> currencies = const {},
    Map<int, String> assetTypes = const {},
    Map<int, String> symbols = const {},
  }) {
    final totalValue =
        currentValues.values.fold(0.0, (sum, v) => sum + v);
    if (totalValue == 0) return [];

    final gaps = <RebalancingGap>[];
    for (final entry in targetWeights.entries) {
      final assetId = entry.key;
      final target = entry.value;
      final current = currentValues[assetId] ?? 0;
      final currentWeight = (current / totalValue) * 100;

      gaps.add(RebalancingGap(
        assetId: assetId,
        assetName: assetNames[assetId] ?? 'Unknown',
        symbol: symbols[assetId] ?? '',
        currentWeight: currentWeight,
        targetWeight: target,
        gap: currentWeight - target,
        currentValue: current,
        pricePerUnit: pricesPerUnit[assetId] ?? 0,
        holdings: holdingsMap[assetId] ?? 0,
        currency: currencies[assetId] ?? 'KRW',
        assetType: assetTypes[assetId] ?? '',
        totalPortfolioValue: totalValue,
      ));
    }

    return gaps;
  }

  /// Calculate portfolio value from transactions and current price
  static double calculateHoldings({
    required List<Transaction> transactions,
  }) {
    double quantity = 0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.buy) {
        quantity += tx.quantity;
      } else {
        quantity -= tx.quantity;
      }
    }
    return quantity;
  }

  /// Average purchase price (weighted average)
  static double averagePurchasePrice(List<Transaction> transactions) {
    double totalCost = 0;
    double totalQty = 0;

    for (final tx in transactions) {
      if (tx.type == TransactionType.buy) {
        totalCost += tx.price * tx.quantity;
        totalQty += tx.quantity;
      }
    }

    return totalQty == 0 ? 0 : totalCost / totalQty;
  }

  /// Annualized return rate from investment cash flows.
  /// Uses Modified Dietz method then annualizes.
  /// [investmentAmounts] and [investmentDates] are parallel lists (KRW amounts).
  /// [currentValueKrw] is the current portfolio total value in KRW.
  static double annualizedReturnFromInvestments({
    required List<double> investmentAmounts,
    required List<DateTime> investmentDates,
    required double currentValueKrw,
  }) {
    if (investmentAmounts.isEmpty || currentValueKrw <= 0) return 0;

    final totalInvested =
        investmentAmounts.fold(0.0, (sum, a) => sum + a);
    if (totalInvested <= 0) return 0;

    // Use earliest investment as start date
    final startDate = investmentDates.reduce(
        (a, b) => a.isBefore(b) ? a : b);
    final now = DateTime.now();
    final totalDays = now.difference(startDate).inDays;
    if (totalDays <= 0) return 0;

    // Build cash flows for Modified Dietz
    // First investment is BMV, subsequent ones are cash flows
    final bmv = investmentAmounts[0];
    final cashFlows = <CashFlow>[];
    for (int i = 1; i < investmentAmounts.length; i++) {
      final daysElapsed =
          investmentDates[i].difference(startDate).inDays;
      cashFlows.add(CashFlow(
        amount: investmentAmounts[i],
        daysElapsed: daysElapsed,
      ));
    }

    final mDietz = modifiedDietz(
      emv: currentValueKrw,
      bmv: bmv,
      cashFlows: cashFlows,
      totalDays: totalDays,
    );

    // Annualize: (1 + r)^(365.25/days) - 1
    if (totalDays < 30) return mDietz; // Too short to annualize
    final years = totalDays / 365.25;
    return math.pow(1 + mDietz, 1 / years).toDouble() - 1;
  }
}
