import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dividend_info.dart';
import '../../domain/entities/portfolio_account_type.dart';
import '../../domain/enums/asset_type.dart';
import '../../domain/services/financial_calculator.dart';
import 'account_type_providers.dart';
import 'asset_providers.dart';
import 'database_providers.dart';
import 'portfolio_providers.dart';
import 'price_providers.dart';
import 'transaction_providers.dart';

// ── 세금 적용 배당 모델 ──────────────────────────────────────────────────────

class TaxedDividendEntry {
  final int assetId;
  final String symbol;
  final String name;
  final double grossKrw;
  final double taxKrw;
  final double netKrw;
  final double taxRate;
  final bool isKrStock;

  const TaxedDividendEntry({
    required this.assetId,
    required this.symbol,
    required this.name,
    required this.grossKrw,
    required this.taxKrw,
    required this.netKrw,
    required this.taxRate,
    required this.isKrStock,
  });
}

class TaxedMonthlyDividend {
  final int year;
  final int month;
  final double grossKrw;
  final double taxKrw;
  final double netKrw;
  final List<TaxedDividendEntry> entries;

  const TaxedMonthlyDividend({
    required this.year,
    required this.month,
    required this.grossKrw,
    required this.taxKrw,
    required this.netKrw,
    required this.entries,
  });
}

// ── Helper (dividend_providers.dart와 동일한 로직 재사용) ───────────────────

DividendFrequency _detectFreq(List<DividendEvent> events) {
  if (events.length < 2) return DividendFrequency.annual;
  final sorted = [...events]..sort((a, b) => a.date.compareTo(b.date));
  final gaps = <int>[];
  for (int i = 1; i < sorted.length; i++) {
    gaps.add(sorted[i].date.difference(sorted[i - 1].date).inDays);
  }
  gaps.sort();
  final median = gaps[gaps.length ~/ 2];
  if (median < 45)  return DividendFrequency.monthly;
  if (median < 110) return DividendFrequency.quarterly;
  if (median < 250) return DividendFrequency.semiAnnual;
  return DividendFrequency.annual;
}

DateTime _addFreq(DateTime d, DividendFrequency freq) {
  switch (freq) {
    case DividendFrequency.monthly:    return DateTime(d.year, d.month + 1, d.day);
    case DividendFrequency.quarterly:  return DateTime(d.year, d.month + 3, d.day);
    case DividendFrequency.semiAnnual: return DateTime(d.year, d.month + 6, d.day);
    case DividendFrequency.annual:     return DateTime(d.year + 1, d.month, d.day);
  }
}

List<DateTime> _projectDates(
    DateTime lastDate, DividendFrequency freq, DateTime from, DateTime end) {
  final result = <DateTime>[];
  var next = _addFreq(lastDate, freq);
  while (next.isBefore(end)) {
    if (!next.isBefore(from)) result.add(next);
    next = _addFreq(next, freq);
  }
  return result;
}

double _avgRecent(List<DividendEvent> events, {int n = 4}) {
  if (events.isEmpty) return 0;
  final sorted = [...events]..sort((a, b) => b.date.compareTo(a.date));
  final recent = sorted.take(n).toList();
  return recent.map((e) => e.amountPerShare).reduce((a, b) => a + b) /
      recent.length;
}

// ── Provider ─────────────────────────────────────────────────────────────────

final taxDividendProjectionProvider =
    FutureProvider<List<TaxedMonthlyDividend>>((ref) async {
  final portfolios = await ref.watch(portfoliosStreamProvider.future);
  if (portfolios.isEmpty) return _emptyYear();

  final accountTypes = ref.watch(accountTypeNotifierProvider);
  final yahoo = ref.read(yahooFinanceDsProvider);
  final rate = ref.watch(usdKrwRateSyncProvider);

  // holdings per asset per portfolio: assetId → {portfolioId → holdings}
  final holdingsByPortfolio = <int, Map<int, double>>{};
  final assetInfoMap =
      <int, ({String symbol, String name, String currency, AssetType type})>{};

  for (final portfolio in portfolios) {
    final pas =
        await ref.watch(portfolioAssetsStreamProvider(portfolio.id).future);
    for (final pa in pas) {
      final asset = pa.asset;
      if (asset == null) continue;
      final assetType = asset.assetType;
      if (assetType != AssetType.usStock && assetType != AssetType.krStock) {
        continue;
      }
      final txs =
          await ref.watch(transactionsStreamProvider(pa.id).future);
      final holdings =
          FinancialCalculator.calculateHoldings(transactions: txs);
      if (holdings <= 0) continue;

      if (!holdingsByPortfolio.containsKey(pa.assetId)) {
        holdingsByPortfolio[pa.assetId] = {};
      }
      holdingsByPortfolio[pa.assetId]![portfolio.id] =
          (holdingsByPortfolio[pa.assetId]![portfolio.id] ?? 0) + holdings;
      assetInfoMap[pa.assetId] ??= (
        symbol: asset.symbol,
        name: asset.name,
        currency: (asset.currency).toUpperCase(),
        type: assetType,
      );
    }
  }

  if (holdingsByPortfolio.isEmpty) return _emptyYear();

  // Effective tax rate per asset (weighted by holdings across portfolios)
  final taxRateMap = <int, double>{};
  final totalHoldingsMap = <int, double>{};

  for (final entry in holdingsByPortfolio.entries) {
    final assetId = entry.key;
    double totalH = 0, weightedTax = 0;
    entry.value.forEach((pid, h) {
      final t = accountTypes[pid] ?? PortfolioAccountType.general;
      totalH += h;
      weightedTax += h * t.dividendTaxRate;
    });
    taxRateMap[assetId] = totalH > 0 ? weightedTax / totalH : 0.154;
    totalHoldingsMap[assetId] = totalH;
  }

  // Fetch dividend histories (throttled: max 3 concurrent)
  final assetIds = holdingsByPortfolio.keys.toList();
  final eventsByAsset = <int, List<DividendEvent>>{};

  int running = 0, nextIndex = 0;
  final completer = Completer<void>();

  void startNext() {
    while (running < 3 && nextIndex < assetIds.length) {
      final id = assetIds[nextIndex++];
      running++;
      final info = assetInfoMap[id]!;
      final symbols = info.type == AssetType.krStock
          ? ['${info.symbol}.KS', '${info.symbol}.KQ']
          : [info.symbol];

      Future<void> fetchForId() async {
        for (final sym in symbols) {
          try {
            final events = await yahoo.fetchDividendHistory(sym);
            if (events.isNotEmpty) {
              eventsByAsset[id] = events;
              break;
            }
          } catch (_) {}
        }
      }

      fetchForId().whenComplete(() {
        running--;
        if (nextIndex < assetIds.length) {
          startNext();
        } else if (running == 0) {
          completer.complete();
        }
      });
    }
  }

  startNext();
  if (assetIds.isNotEmpty) await completer.future;

  // 12-month grid
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final end  = DateTime(now.year, now.month + 12, 1);

  // monthKey → assetId → grossKrw
  final monthMap = <String, Map<int, double>>{};
  for (int i = 0; i < 12; i++) {
    final m = DateTime(now.year, now.month + i, 1);
    monthMap['${m.year}-${m.month}'] = {};
  }

  for (final id in assetIds) {
    final events = eventsByAsset[id];
    if (events == null || events.isEmpty) continue;

    final info = assetInfoMap[id]!;
    final holdings = totalHoldingsMap[id]!;
    final freq = _detectFreq(events);
    final amtPerShare = _avgRecent(events);
    if (amtPerShare <= 0) continue;

    for (final date in _projectDates(events.last.date, freq, from, end)) {
      final key = '${date.year}-${date.month}';
      if (!monthMap.containsKey(key)) continue;
      final nativeAmt = amtPerShare * holdings;
      final krwAmt = info.currency == 'USD' ? nativeAmt * rate : nativeAmt;
      monthMap[key]![id] = (monthMap[key]![id] ?? 0) + krwAmt;
    }
  }

  // Build result
  final result = <TaxedMonthlyDividend>[];
  for (int i = 0; i < 12; i++) {
    final m = DateTime(now.year, now.month + i, 1);
    final key = '${m.year}-${m.month}';
    final bucket = monthMap[key] ?? {};

    final entries = bucket.entries.map((e) {
      final info = assetInfoMap[e.key]!;
      final gross = e.value;
      final taxR = taxRateMap[e.key] ?? 0.154;
      final tax = gross * taxR;
      return TaxedDividendEntry(
        assetId: e.key,
        symbol: info.symbol,
        name: info.name,
        grossKrw: gross,
        taxKrw: tax,
        netKrw: gross - tax,
        taxRate: taxR,
        isKrStock: info.type == AssetType.krStock,
      );
    }).toList()
      ..sort((a, b) => b.grossKrw.compareTo(a.grossKrw));

    final gross = bucket.values.fold(0.0, (s, v) => s + v);
    final tax = entries.fold(0.0, (s, e) => s + e.taxKrw);

    result.add(TaxedMonthlyDividend(
      year: m.year,
      month: m.month,
      grossKrw: gross,
      taxKrw: tax,
      netKrw: gross - tax,
      entries: entries,
    ));
  }

  return result;
});

List<TaxedMonthlyDividend> _emptyYear() {
  final now = DateTime.now();
  return List.generate(12, (i) {
    final m = DateTime(now.year, now.month + i, 1);
    return TaxedMonthlyDividend(
        year: m.year, month: m.month,
        grossKrw: 0, taxKrw: 0, netKrw: 0, entries: []);
  });
}
