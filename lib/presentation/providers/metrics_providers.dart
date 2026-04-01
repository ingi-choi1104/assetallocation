import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/enums/asset_type.dart';
import '../../domain/services/financial_calculator.dart';
import 'asset_providers.dart';
import 'database_providers.dart';
import 'investment_providers.dart';
import 'portfolio_bundle_providers.dart';
import 'portfolio_providers.dart';
import 'price_providers.dart';
import 'transaction_providers.dart';

/// Fetches prices for all assets in a portfolio ONCE.
/// Shared by portfolioMetricsProvider and portfolioWeightsProvider so that
/// both providers use the same fetch results — eliminating duplicate API calls
/// and non-deterministic _priceChangeCache overwrites that caused intermittent
/// daily-change failures.
final portfolioPricesProvider =
    FutureProvider.family<Map<int, double>, int>((ref, portfolioId) async {
  final portfolioAssets =
      await ref.watch(portfolioAssetsStreamProvider(portfolioId).future);
  final priceRepo = ref.watch(priceRepositoryProvider);

  final priceFutures = portfolioAssets.map((pa) async {
    // Cash assets are always 1.0 — skip network call
    if (pa.asset?.assetType == AssetType.cash) {
      return MapEntry(pa.assetId, 1.0);
    }
    try {
      final p = await priceRepo.fetchCurrentPrice(pa.assetId);
      return MapEntry(pa.assetId, p ?? pa.asset?.lastPrice ?? 0.0);
    } catch (_) {
      return MapEntry(pa.assetId, pa.asset?.lastPrice ?? 0.0);
    }
  });
  final entries = await Future.wait(priceFutures);
  return Map.fromEntries(entries);
});

/// Computes metrics for a single portfolio.
/// totalValue is in KRW — USD assets are converted using live USD/KRW rate.
/// Return rates are computed from investment cash flows (투자금).
final portfolioMetricsProvider =
    FutureProvider.family<PortfolioMetrics, int>((ref, portfolioId) async {
  final portfolioAssets =
      await ref.watch(portfolioAssetsStreamProvider(portfolioId).future);
  final rate = await ref.watch(usdKrwRateProvider.future);

  double totalValue = 0;

  // Fetch all transactions and prices in parallel (prices shared via portfolioPricesProvider)
  final txFutures = portfolioAssets.map((pa) =>
      ref.watch(transactionsStreamProvider(pa.id).future));
  final allTransactions = await Future.wait(txFutures);

  final prices = await ref.watch(portfolioPricesProvider(portfolioId).future);
  final allPrices = portfolioAssets.map((pa) => prices[pa.assetId] ?? 0.0).toList();

  for (int i = 0; i < portfolioAssets.length; i++) {
    final pa = portfolioAssets[i];
    final transactions = allTransactions[i];
    final currentPrice = allPrices[i];

    final holdings = FinancialCalculator.calculateHoldings(
      transactions: transactions,
    );

    final isUsd = (pa.asset?.currency ?? 'KRW').toUpperCase() == 'USD';
    final nativeValue = holdings * currentPrice;
    totalValue += isUsd ? nativeValue * rate : nativeValue;
  }

  // Use investments (stream-based) for immediate recalculation on changes
  final investments =
      await ref.watch(investmentsStreamProvider(portfolioId).future);
  final totalInvested = investments.fold(0.0, (sum, i) => sum + i.amount);

  final returnRate = totalInvested == 0
      ? 0.0
      : (totalValue - totalInvested) / totalInvested;

  // Annualized return from investment dates
  double annualizedReturn = 0;
  if (investments.isNotEmpty && totalValue > 0) {
    annualizedReturn = FinancialCalculator.annualizedReturnFromInvestments(
      investmentAmounts: investments.map((i) => i.amount).toList(),
      investmentDates: investments.map((i) => i.investmentDate).toList(),
      currentValueKrw: totalValue,
    );
  }

  return PortfolioMetrics(
    totalValue: totalValue,
    totalInvested: totalInvested,
    returnRate: returnRate,
    annualizedReturnRate: annualizedReturn,
    annualizedStdDev: 0,
    maxDrawdown: 0,
  );
});

/// Computes current weights for rebalancing display.
/// currentValue in RebalancingGap is in KRW (USD assets converted using live rate).
final portfolioWeightsProvider =
    FutureProvider.family<List<RebalancingGap>, int>(
        (ref, portfolioId) async {
  final portfolioAssets =
      await ref.watch(portfolioAssetsStreamProvider(portfolioId).future);
  final rate = await ref.watch(usdKrwRateProvider.future);

  final currentValues = <int, double>{};
  final targetWeights = <int, double>{};
  final assetNames = <int, String>{};
  final assetSymbols = <int, String>{};
  final pricesPerUnit = <int, double>{};
  final holdingsMap = <int, double>{};
  final currencies = <int, String>{};
  final assetTypes = <int, String>{};

  // Fetch all transactions and prices in parallel (prices shared via portfolioPricesProvider)
  final txFutures = portfolioAssets.map((pa) =>
      ref.watch(transactionsStreamProvider(pa.id).future));
  final allTransactions = await Future.wait(txFutures);

  final prices = await ref.watch(portfolioPricesProvider(portfolioId).future);
  final allPrices = portfolioAssets.map((pa) => prices[pa.assetId] ?? 0.0).toList();

  for (int i = 0; i < portfolioAssets.length; i++) {
    final pa = portfolioAssets[i];
    final transactions = allTransactions[i];
    final currentPrice = allPrices[i];

    final holdings = FinancialCalculator.calculateHoldings(
      transactions: transactions,
    );

    final currency = (pa.asset?.currency ?? 'KRW').toUpperCase();
    final isUsd = currency == 'USD';
    final nativeValue = holdings * currentPrice;
    currentValues[pa.assetId] = isUsd ? nativeValue * rate : nativeValue;
    targetWeights[pa.assetId] = pa.targetWeight;
    assetNames[pa.assetId] = pa.asset?.name ?? pa.assetId.toString();
    assetSymbols[pa.assetId] = pa.asset?.symbol ?? '';
    pricesPerUnit[pa.assetId] = currentPrice;
    holdingsMap[pa.assetId] = holdings;
    currencies[pa.assetId] = currency;
    assetTypes[pa.assetId] = pa.asset?.assetType.value ?? '';
  }

  return FinancialCalculator.rebalancingGaps(
    assetNames: assetNames,
    currentValues: currentValues,
    targetWeights: targetWeights,
    pricesPerUnit: pricesPerUnit,
    holdingsMap: holdingsMap,
    currencies: currencies,
    assetTypes: assetTypes,
    symbols: assetSymbols,
  );
});

/// Combined metrics across ALL portfolios
final globalMetricsProvider =
    FutureProvider<PortfolioMetrics>((ref) async {
  final portfolios =
      await ref.watch(portfoliosStreamProvider.future);
  if (portfolios.isEmpty) {
    return const PortfolioMetrics(
      totalValue: 0,
      totalInvested: 0,
      returnRate: 0,
      annualizedStdDev: 0,
      maxDrawdown: 0,
    );
  }

  // Portfolios / bundles toggled off by the user on the home screen
  final excludedIds = ref.watch(excludedPortfoliosProvider);
  final excludedBundleIds = ref.watch(excludedBundlesProvider);

  // Build set of portfolio IDs that belong to excluded bundles
  final bundles = ref.watch(portfolioBundleNotifierProvider);
  final bundleExcludedPortfolioIds = <int>{};
  for (final b in bundles) {
    if (excludedBundleIds.contains(b.id)) {
      bundleExcludedPortfolioIds.addAll(b.portfolioIds);
    }
  }

  // Fetch metrics for all portfolios in parallel
  final metricsFutures = portfolios.map((p) =>
      ref.watch(portfolioMetricsProvider(p.id).future));
  final allMetrics = await Future.wait(metricsFutures);

  double totalValue = 0;
  double totalValueForReturn = 0; // only portfolios with investments
  double totalInvested = 0;
  final allAmounts = <double>[];
  final allDates = <DateTime>[];

  for (int i = 0; i < portfolios.length; i++) {
    final m = allMetrics[i];
    // Skip portfolios with no assets
    if (m.totalValue == 0) continue;
    // Skip portfolios excluded individually or via bundle
    if (excludedIds.contains(portfolios[i].id)) continue;
    if (bundleExcludedPortfolioIds.contains(portfolios[i].id)) continue;

    totalValue += m.totalValue;

    // Only include in return rate calculation if there are investment records
    if (m.totalInvested == 0) continue;

    totalValueForReturn += m.totalValue;
    totalInvested += m.totalInvested;

    // Gather investment cash flows (stream-based for instant updates)
    final investments =
        await ref.watch(investmentsStreamProvider(portfolios[i].id).future);
    for (final inv in investments) {
      allAmounts.add(inv.amount);
      allDates.add(inv.investmentDate);
    }
  }

  final returnRate = totalInvested == 0
      ? 0.0
      : (totalValueForReturn - totalInvested) / totalInvested;

  double annualizedReturn = 0;
  if (allAmounts.isNotEmpty && totalValueForReturn > 0) {
    annualizedReturn = FinancialCalculator.annualizedReturnFromInvestments(
      investmentAmounts: allAmounts,
      investmentDates: allDates,
      currentValueKrw: totalValueForReturn,
    );
  }

  return PortfolioMetrics(
    totalValue: totalValue,
    totalInvested: totalInvested,
    returnRate: returnRate,
    annualizedReturnRate: annualizedReturn,
    annualizedStdDev: 0,
    maxDrawdown: 0,
  );
});

/// Aggregated metrics for all portfolios in a bundle (not affected by exclusions).
final bundleMetricsProvider =
    FutureProvider.family<PortfolioMetrics, List<int>>((ref, portfolioIds) async {
  if (portfolioIds.isEmpty) {
    return const PortfolioMetrics(
      totalValue: 0, totalInvested: 0, returnRate: 0,
      annualizedStdDev: 0, maxDrawdown: 0,
    );
  }

  final metricsFutures =
      portfolioIds.map((id) => ref.watch(portfolioMetricsProvider(id).future));
  final allMetrics = await Future.wait(metricsFutures);

  double totalValue = 0;
  double totalValueForReturn = 0;
  double totalInvested = 0;
  final allAmounts = <double>[];
  final allDates = <DateTime>[];

  for (int i = 0; i < portfolioIds.length; i++) {
    final m = allMetrics[i];
    if (m.totalValue == 0) continue;
    totalValue += m.totalValue;
    if (m.totalInvested == 0) continue;
    totalValueForReturn += m.totalValue;
    totalInvested += m.totalInvested;
    final investments =
        await ref.watch(investmentsStreamProvider(portfolioIds[i]).future);
    for (final inv in investments) {
      allAmounts.add(inv.amount);
      allDates.add(inv.investmentDate);
    }
  }

  final returnRate = totalInvested == 0
      ? 0.0
      : (totalValueForReturn - totalInvested) / totalInvested;

  double annualizedReturn = 0;
  if (allAmounts.isNotEmpty && totalValueForReturn > 0) {
    annualizedReturn = FinancialCalculator.annualizedReturnFromInvestments(
      investmentAmounts: allAmounts,
      investmentDates: allDates,
      currentValueKrw: totalValueForReturn,
    );
  }

  return PortfolioMetrics(
    totalValue: totalValue,
    totalInvested: totalInvested,
    returnRate: returnRate,
    annualizedReturnRate: annualizedReturn,
    annualizedStdDev: 0,
    maxDrawdown: 0,
  );
});

// ── Daily Change ──────────────────────────────────────────────────────────────

/// Daily change info (KRW amount change and percentage)
class DailyChange {
  final double amountChange;
  final double percentChange;

  const DailyChange({required this.amountChange, required this.percentChange});
}

/// Computes 24h portfolio value change from cached PriceChangeInfo.
final portfolioDailyChangeProvider =
    Provider.family<DailyChange?, int>((ref, portfolioId) {
  final assetsAsync = ref.watch(portfolioAssetsStreamProvider(portfolioId));
  final weightsAsync = ref.watch(portfolioWeightsProvider(portfolioId));
  final repo = ref.watch(priceRepositoryProvider);
  final rate = ref.watch(usdKrwRateSyncProvider);

  final assets = assetsAsync.value;
  final gaps = weightsAsync.value;
  if (assets == null || gaps == null) return null;

  final holdingsMap = <int, double>{};
  for (final g in gaps) {
    holdingsMap[g.assetId] = g.holdings;
  }

  double totalCurrent = 0;
  double totalPrevious = 0;

  for (final pa in assets) {
    final info = repo.getPriceChange(pa.assetId);
    if (info == null) continue;
    final holdings = holdingsMap[pa.assetId] ?? 0;
    if (holdings == 0) continue;

    final isUsd = (pa.asset?.currency ?? 'KRW').toUpperCase() == 'USD';
    final multiplier = isUsd ? rate : 1.0;

    totalCurrent += holdings * info.currentPrice * multiplier;
    if (info.previousClose != null) {
      totalPrevious += holdings * info.previousClose! * multiplier;
    } else {
      totalPrevious += holdings * info.currentPrice * multiplier;
    }
  }

  if (totalPrevious == 0) return null;
  final change = totalCurrent - totalPrevious;
  final pct = change / totalPrevious * 100;
  return DailyChange(amountChange: change, percentChange: pct);
});

/// Global (all portfolios) daily change
final globalDailyChangeProvider = Provider<DailyChange?>((ref) {
  final portfoliosAsync = ref.watch(portfoliosStreamProvider);
  final portfolios = portfoliosAsync.value;
  if (portfolios == null || portfolios.isEmpty) return null;

  double totalChange = 0;
  double totalPrevious = 0;
  bool hasData = false;

  for (final p in portfolios) {
    final dc = ref.watch(portfolioDailyChangeProvider(p.id));
    if (dc == null) continue;
    hasData = true;

    final currentForPortfolio = ref.watch(portfolioMetricsProvider(p.id)).value;
    if (currentForPortfolio == null) continue;
    final prevValue = currentForPortfolio.totalValue - dc.amountChange;
    totalPrevious += prevValue;
    totalChange += dc.amountChange;
  }

  if (!hasData || totalPrevious == 0) return null;
  return DailyChange(
    amountChange: totalChange,
    percentChange: totalChange / totalPrevious * 100,
  );
});

// ── Risk Metrics (MDD & 표준편차) ─────────────────────────────────────────────

/// 투자금 투입 시점 + 목표 비율 + 리밸런싱 주기 기반으로 시뮬레이션한 위험 지표.
/// 조건: 투자금 기록 + 리밸런싱 주기 설정 모두 필요.
class RiskMetrics {
  final double mdd;    // ≤ 0 (e.g. -0.20 = -20%)
  final double stdDev; // ≥ 0 (e.g. 0.15 = 15% annualised)

  const RiskMetrics({required this.mdd, required this.stdDev});
}

/// 1 troy oz = 31.1035 grams
const double _gramPerTroyOz = 31.1035;

/// 날짜를 'yyyy-mm-dd' 키로 변환
String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 리밸런싱 주기 문자열 → 개월 수
int _parsePeriodMonths(String period) {
  switch (period) {
    case 'monthly':  return 1;
    case 'quarterly': return 3;
    case 'yearly':  return 12;
    default:        return 12;
  }
}

/// 투자금 투입 시점 기준으로 목표 비율에 따라 포트폴리오를 시뮬레이션하여
/// MDD와 연간 변동성을 계산합니다.
/// - 투자금 투입일에 목표 비율대로 자산 매수 가정
/// - 리밸런싱 주기마다 목표 비율로 재조정 가정
/// - 추가 투자금 투입 시 해당 날짜에 목표 비율대로 매수 가정
final portfolioRiskMetricsProvider =
    FutureProvider.family<RiskMetrics?, int>((ref, portfolioId) async {
  // ── 조건 확인 ────────────────────────────────────────────────────────────
  final portfolio = await ref.watch(portfolioProvider(portfolioId).future);
  final rebalancePeriod = portfolio?.rebalancePeriod;
  if (rebalancePeriod == null || rebalancePeriod.isEmpty) return null;

  final investments =
      await ref.watch(investmentsStreamProvider(portfolioId).future);
  if (investments.isEmpty) return null;

  // 투자금 날짜 기준 정렬 — 시작일 = 첫 번째 투자금 투입일
  final sortedInvestments = [...investments]
    ..sort((a, b) => a.investmentDate.compareTo(b.investmentDate));
  final startDate = sortedInvestments.first.investmentDate;
  final now = DateTime.now();
  if (now.difference(startDate).inDays < 30) return null;

  // ── 포트폴리오 자산 & 목표 비율 ──────────────────────────────────────────
  final portfolioAssets =
      await ref.watch(portfolioAssetsStreamProvider(portfolioId).future);
  if (portfolioAssets.isEmpty) return null;

  final totalWeight =
      portfolioAssets.fold(0.0, (s, pa) => s + pa.targetWeight);
  if (totalWeight <= 0) return null;

  final rate = await ref.watch(usdKrwRateProvider.future);
  final yahoo = ref.read(yahooFinanceDsProvider);
  final naver = ref.read(naverFinanceDsProvider);

  // ── 자산별 일별 KRW 가격 조회 ─────────────────────────────────────────────
  final assetPriceMaps = <int, Map<String, double>>{}; // assetId → dateKey → KRW

  for (final pa in portfolioAssets) {
    final asset = pa.asset;
    if (asset == null) continue;
    final assetType = asset.assetType;
    if (assetType == AssetType.cash) continue;

    List<({DateTime date, double price})> dailyPrices = [];

    switch (assetType) {
      case AssetType.usStock:
        final bars = await yahoo.fetchDailyHistory(asset.symbol, startDate, now);
        if (bars != null) {
          dailyPrices =
              bars.map((b) => (date: b.date, price: b.close * rate)).toList();
        }

      case AssetType.gold:
        // GC=F: USD/troy oz → KRW/gram
        final bars = await yahoo.fetchDailyHistory('GC=F', startDate, now);
        if (bars != null) {
          dailyPrices = bars
              .map((b) => (
                    date: b.date,
                    price: b.close / _gramPerTroyOz * rate,
                  ))
              .toList();
        }

      case AssetType.krStock:
        final dayCount = now.difference(startDate).inDays + 10;
        try {
          final quote = await naver.fetchHistory(asset.symbol, count: dayCount);
          final history = quote?.history;
          if (history != null && history.isNotEmpty) {
            dailyPrices =
                history.map((b) => (date: b.date, price: b.close)).toList();
          }
        } catch (_) {}

        if (dailyPrices.isEmpty) {
          for (final suffix in ['.KS', '.KQ']) {
            final bars = await yahoo.fetchDailyHistory(
                '${asset.symbol}$suffix', startDate, now);
            if (bars != null && bars.isNotEmpty) {
              // Yahoo .KS/.KQ 가격은 KRW
              dailyPrices =
                  bars.map((b) => (date: b.date, price: b.close)).toList();
              break;
            }
          }
        }

      default:
        continue; // crypto, fund: 히스토리 미지원
    }

    if (dailyPrices.isEmpty) continue;

    final priceMap = <String, double>{};
    for (final dp in dailyPrices) {
      priceMap[_dateKey(dp.date)] = dp.price;
    }
    assetPriceMaps[pa.assetId] = priceMap;
  }

  if (assetPriceMaps.isEmpty) return null;

  // ── 유효 자산 (가격 데이터 있거나 현금) ──────────────────────────────────
  final activeAssets = portfolioAssets.where((pa) {
    if (pa.asset == null) return false;
    return pa.asset!.assetType == AssetType.cash ||
        assetPriceMaps.containsKey(pa.assetId);
  }).toList();
  if (activeAssets.isEmpty) return null;

  // ── 전일 승계(Forward-fill): 주말/공휴일 등 거래 없는 날 처리 ─────────────
  final forwardFilled = <int, Map<String, double>>{};
  for (final pa in activeAssets) {
    if (pa.asset?.assetType == AssetType.cash) {
      forwardFilled[pa.assetId] = const {}; // 현금: getPrice에서 1.0 반환
      continue;
    }
    final raw = assetPriceMaps[pa.assetId]!;
    final filled = <String, double>{};
    double? last;
    var d = startDate;
    while (!d.isAfter(now)) {
      final key = _dateKey(d);
      if (raw.containsKey(key)) last = raw[key];
      if (last != null) filled[key] = last;
      d = d.add(const Duration(days: 1));
    }
    forwardFilled[pa.assetId] = filled;
  }

  // ── 리밸런싱 날짜 집합 생성 ───────────────────────────────────────────────
  final periodMonths = _parsePeriodMonths(rebalancePeriod);
  final rebalanceDateKeys = <String>{};
  var rebDate =
      DateTime(startDate.year, startDate.month + periodMonths, startDate.day);
  while (!rebDate.isAfter(now)) {
    rebalanceDateKeys.add(_dateKey(rebDate));
    rebDate =
        DateTime(rebDate.year, rebDate.month + periodMonths, rebDate.day);
  }

  // ── 투자금 날짜별 집계 ────────────────────────────────────────────────────
  final investmentMap = <String, double>{};
  for (final inv in sortedInvestments) {
    final key = _dateKey(inv.investmentDate);
    investmentMap[key] = (investmentMap[key] ?? 0) + inv.amount;
  }

  // ── 포트폴리오 시뮬레이션 ─────────────────────────────────────────────────
  double getPrice(int assetId, AssetType? type, String key) {
    if (type == AssetType.cash) return 1.0;
    return forwardFilled[assetId]?[key] ?? 0.0;
  }

  final holdings = <int, double>{}; // assetId → 보유 수량
  bool initialized = false;
  final portfolioValues = <double>[];

  var simDate = startDate;
  while (!simDate.isAfter(now)) {
    final key = _dateKey(simDate);

    // 투자금 투입 → 목표 비율대로 수량 추가
    if (investmentMap.containsKey(key)) {
      final amount = investmentMap[key]!;
      for (final pa in activeAssets) {
        final price = getPrice(pa.assetId, pa.asset?.assetType, key);
        if (price <= 0) continue;
        final allocation = amount * (pa.targetWeight / totalWeight);
        holdings[pa.assetId] = (holdings[pa.assetId] ?? 0) + allocation / price;
      }
      initialized = true;
    }

    if (!initialized) {
      simDate = simDate.add(const Duration(days: 1));
      continue;
    }

    // 포트폴리오 가치 계산
    double portfolioValue = 0;
    for (final pa in activeAssets) {
      final qty = holdings[pa.assetId] ?? 0;
      final price = getPrice(pa.assetId, pa.asset?.assetType, key);
      portfolioValue += qty * price;
    }

    if (portfolioValue > 0) {
      portfolioValues.add(portfolioValue);

      // 리밸런싱 날짜: 목표 비율로 재조정
      if (rebalanceDateKeys.contains(key)) {
        for (final pa in activeAssets) {
          final price = getPrice(pa.assetId, pa.asset?.assetType, key);
          if (price <= 0) {
            holdings[pa.assetId] = 0;
            continue;
          }
          holdings[pa.assetId] =
              portfolioValue * (pa.targetWeight / totalWeight) / price;
        }
      }
    }

    simDate = simDate.add(const Duration(days: 1));
  }

  if (portfolioValues.length < 10) return null;

  return RiskMetrics(
    mdd: FinancialCalculator.maxDrawdown(portfolioValues),
    stdDev: FinancialCalculator.annualizedStdDev(portfolioValues),
  );
});

// ── 위험성 분석 (사용자 입력 기반) ────────────────────────────────────────────

/// 위험성 분석 입력 파라미터.
/// 사용자가 직접 시작일과 리밸런싱 주기를 지정해 시뮬레이션.
class RiskAnalysisInput {
  final int portfolioId;
  final DateTime startDate; // 날짜(연월일)만 사용
  final String rebalancePeriod; // 'monthly' | 'quarterly' | 'yearly'

  const RiskAnalysisInput({
    required this.portfolioId,
    required this.startDate,
    required this.rebalancePeriod,
  });

  @override
  bool operator ==(Object other) =>
      other is RiskAnalysisInput &&
      other.portfolioId == portfolioId &&
      other.startDate.year == startDate.year &&
      other.startDate.month == startDate.month &&
      other.startDate.day == startDate.day &&
      other.rebalancePeriod == rebalancePeriod;

  @override
  int get hashCode => Object.hash(
        portfolioId,
        '${startDate.year}-${startDate.month}-${startDate.day}',
        rebalancePeriod,
      );
}

/// 사용자가 지정한 시작일 + 리밸런싱 주기로 포트폴리오를 시뮬레이션하여
/// MDD와 연간 변동성을 계산합니다.
/// 투자 금액은 비율 기반 지표이므로 임의 초기값(10,000 KRW)을 사용합니다.
final riskAnalysisProvider =
    FutureProvider.family<RiskMetrics?, RiskAnalysisInput>((ref, input) async {
  final startDate = input.startDate;
  final now = DateTime.now();
  if (now.difference(startDate).inDays < 30) return null;

  final portfolioAssets =
      await ref.watch(portfolioAssetsStreamProvider(input.portfolioId).future);
  if (portfolioAssets.isEmpty) return null;

  final totalWeight =
      portfolioAssets.fold(0.0, (s, pa) => s + pa.targetWeight);
  if (totalWeight <= 0) return null;

  final rate = await ref.watch(usdKrwRateProvider.future);
  final yahoo = ref.read(yahooFinanceDsProvider);
  final naver = ref.read(naverFinanceDsProvider);

  // ── 자산별 일별 KRW 가격 조회 ─────────────────────────────────────────────
  final assetPriceMaps = <int, Map<String, double>>{};

  for (final pa in portfolioAssets) {
    final asset = pa.asset;
    if (asset == null) continue;
    final assetType = asset.assetType;
    if (assetType == AssetType.cash) continue;

    List<({DateTime date, double price})> dailyPrices = [];

    switch (assetType) {
      case AssetType.usStock:
        final bars = await yahoo.fetchDailyHistory(asset.symbol, startDate, now);
        if (bars != null) {
          dailyPrices =
              bars.map((b) => (date: b.date, price: b.close * rate)).toList();
        }

      case AssetType.gold:
        final bars = await yahoo.fetchDailyHistory('GC=F', startDate, now);
        if (bars != null) {
          dailyPrices = bars
              .map((b) => (
                    date: b.date,
                    price: b.close / _gramPerTroyOz * rate,
                  ))
              .toList();
        }

      case AssetType.krStock:
        final dayCount = now.difference(startDate).inDays + 10;
        try {
          final quote = await naver.fetchHistory(asset.symbol, count: dayCount);
          final history = quote?.history;
          if (history != null && history.isNotEmpty) {
            dailyPrices =
                history.map((b) => (date: b.date, price: b.close)).toList();
          }
        } catch (_) {}

        if (dailyPrices.isEmpty) {
          for (final suffix in ['.KS', '.KQ']) {
            final bars = await yahoo.fetchDailyHistory(
                '${asset.symbol}$suffix', startDate, now);
            if (bars != null && bars.isNotEmpty) {
              dailyPrices =
                  bars.map((b) => (date: b.date, price: b.close)).toList();
              break;
            }
          }
        }

      default:
        continue;
    }

    if (dailyPrices.isEmpty) continue;

    final priceMap = <String, double>{};
    for (final dp in dailyPrices) {
      priceMap[_dateKey(dp.date)] = dp.price;
    }
    assetPriceMaps[pa.assetId] = priceMap;
  }

  if (assetPriceMaps.isEmpty) return null;

  // ── 유효 자산 목록 ────────────────────────────────────────────────────────
  final activeAssets = portfolioAssets.where((pa) {
    if (pa.asset == null) return false;
    return pa.asset!.assetType == AssetType.cash ||
        assetPriceMaps.containsKey(pa.assetId);
  }).toList();
  if (activeAssets.isEmpty) return null;

  // ── 전일 승계(Forward-fill) ──────────────────────────────────────────────
  final forwardFilled = <int, Map<String, double>>{};
  for (final pa in activeAssets) {
    if (pa.asset?.assetType == AssetType.cash) {
      forwardFilled[pa.assetId] = const {};
      continue;
    }
    final raw = assetPriceMaps[pa.assetId]!;
    final filled = <String, double>{};
    double? last;
    var d = startDate;
    while (!d.isAfter(now)) {
      final key = _dateKey(d);
      if (raw.containsKey(key)) last = raw[key];
      if (last != null) filled[key] = last;
      d = d.add(const Duration(days: 1));
    }
    forwardFilled[pa.assetId] = filled;
  }

  // ── 리밸런싱 날짜 ─────────────────────────────────────────────────────────
  final periodMonths = _parsePeriodMonths(input.rebalancePeriod);
  final rebalanceDateKeys = <String>{};
  var rebDate =
      DateTime(startDate.year, startDate.month + periodMonths, startDate.day);
  while (!rebDate.isAfter(now)) {
    rebalanceDateKeys.add(_dateKey(rebDate));
    rebDate =
        DateTime(rebDate.year, rebDate.month + periodMonths, rebDate.day);
  }

  // ── 시뮬레이션 (초기 투자금 10,000 KRW — 비율 지표이므로 절대값 무관) ──────
  double getPrice(int assetId, AssetType? type, String key) {
    if (type == AssetType.cash) return 1.0;
    return forwardFilled[assetId]?[key] ?? 0.0;
  }

  const initialAmount = 10000.0;
  final holdings = <int, double>{};
  bool initialized = false;
  final portfolioValues = <double>[];

  var simDate = startDate;
  while (!simDate.isAfter(now)) {
    final key = _dateKey(simDate);

    // 최초 시작일에 초기 투자금 투입
    if (!initialized) {
      bool anyPrice = false;
      for (final pa in activeAssets) {
        final price = getPrice(pa.assetId, pa.asset?.assetType, key);
        if (price <= 0) continue;
        anyPrice = true;
        final allocation = initialAmount * (pa.targetWeight / totalWeight);
        holdings[pa.assetId] = (holdings[pa.assetId] ?? 0) + allocation / price;
      }
      if (anyPrice) initialized = true;
    }

    if (!initialized) {
      simDate = simDate.add(const Duration(days: 1));
      continue;
    }

    double portfolioValue = 0;
    for (final pa in activeAssets) {
      final qty = holdings[pa.assetId] ?? 0;
      final price = getPrice(pa.assetId, pa.asset?.assetType, key);
      portfolioValue += qty * price;
    }

    if (portfolioValue > 0) {
      portfolioValues.add(portfolioValue);

      if (rebalanceDateKeys.contains(key)) {
        for (final pa in activeAssets) {
          final price = getPrice(pa.assetId, pa.asset?.assetType, key);
          if (price <= 0) {
            holdings[pa.assetId] = 0;
            continue;
          }
          holdings[pa.assetId] =
              portfolioValue * (pa.targetWeight / totalWeight) / price;
        }
      }
    }

    simDate = simDate.add(const Duration(days: 1));
  }

  if (portfolioValues.length < 10) return null;

  return RiskMetrics(
    mdd: FinancialCalculator.maxDrawdown(portfolioValues),
    stdDev: FinancialCalculator.annualizedStdDev(portfolioValues),
  );
});
