import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dividend_info.dart';
import '../../domain/enums/asset_type.dart';
import '../../domain/services/financial_calculator.dart';
import 'asset_providers.dart';
import 'database_providers.dart';
import 'portfolio_providers.dart';
import 'price_providers.dart';
import 'transaction_providers.dart';

// ── Dividend frequency detection ──────────────────────────────────────────────

DividendFrequency _detectFrequency(List<DividendEvent> events) {
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

/// Projects future payment dates starting from [lastDate] with [freq] until
/// [end] (exclusive), returning only dates on or after [from].
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

DateTime _addFreq(DateTime d, DividendFrequency freq) {
  switch (freq) {
    case DividendFrequency.monthly:    return DateTime(d.year, d.month + 1, d.day);
    case DividendFrequency.quarterly:  return DateTime(d.year, d.month + 3, d.day);
    case DividendFrequency.semiAnnual: return DateTime(d.year, d.month + 6, d.day);
    case DividendFrequency.annual:     return DateTime(d.year + 1, d.month, d.day);
  }
}

double _avgRecentAmount(List<DividendEvent> events, {int n = 4}) {
  if (events.isEmpty) return 0;
  final sorted = [...events]..sort((a, b) => b.date.compareTo(a.date));
  final recent = sorted.take(n).toList();
  return recent.map((e) => e.amountPerShare).reduce((a, b) => a + b) /
      recent.length;
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Returns expected monthly dividends for the next 12 months (current month
/// through 11 months later). Each entry covers one calendar month.
final dividendProjectionProvider =
    FutureProvider<List<MonthlyDividend>>((ref) async {
  final portfolios = await ref.watch(portfoliosStreamProvider.future);
  if (portfolios.isEmpty) return _emptyYear();

  final yahoo = ref.read(yahooFinanceDsProvider);
  final rate = ref.watch(usdKrwRateSyncProvider);

  // Aggregate holdings by assetId across all portfolios
  final holdingsMap = <int, double>{};
  final assetInfoMap = <int, ({String symbol, String name, String currency, AssetType type})>{};

  for (final portfolio in portfolios) {
    final pas = await ref.watch(portfolioAssetsStreamProvider(portfolio.id).future);
    for (final pa in pas) {
      final asset = pa.asset;
      if (asset == null) continue;
      final assetType = asset.assetType;
      // Only US stocks and KR stocks pay dividends (skip crypto, cash, gold, fund)
      if (assetType != AssetType.usStock && assetType != AssetType.krStock) continue;

      final txs = await ref.watch(transactionsStreamProvider(pa.id).future);
      final holdings = FinancialCalculator.calculateHoldings(transactions: txs);
      if (holdings <= 0) continue;

      holdingsMap[pa.assetId] = (holdingsMap[pa.assetId] ?? 0) + holdings;
      assetInfoMap[pa.assetId] ??= (
        symbol: asset.symbol,
        name: asset.name,
        currency: (asset.currency).toUpperCase(),
        type: assetType,
      );
    }
  }

  if (holdingsMap.isEmpty) return _emptyYear();

  // Fetch dividend histories (throttled: max 3 concurrent)
  final assetIds = holdingsMap.keys.toList();
  final eventsByAsset = <int, List<DividendEvent>>{};

  int running = 0;
  int nextIndex = 0;
  final completer = Completer<void>();

  void startNext() {
    while (running < 3 && nextIndex < assetIds.length) {
      final id = assetIds[nextIndex++];
      running++;
      final info = assetInfoMap[id]!;
      // KR stocks: try .KS then .KQ suffix on Yahoo
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

  // Build 12-month grid (current month … +11 months)
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final end  = DateTime(now.year, now.month + 12, 1);

  // Initialize monthly buckets
  final monthMap = <String, Map<int, double>>{};
  for (int i = 0; i < 12; i++) {
    final m = DateTime(now.year, now.month + i, 1);
    monthMap['${m.year}-${m.month}'] = {};
  }

  for (final id in assetIds) {
    final events = eventsByAsset[id];
    if (events == null || events.isEmpty) continue;

    final info = assetInfoMap[id]!;
    final holdings = holdingsMap[id]!;
    final freq = _detectFrequency(events);
    final amtPerShare = _avgRecentAmount(events);
    if (amtPerShare <= 0) continue;

    final paymentDates = _projectDates(events.last.date, freq, from, end);

    for (final date in paymentDates) {
      final key = '${date.year}-${date.month}';
      if (!monthMap.containsKey(key)) continue;

      // Convert to KRW
      final nativeAmt = amtPerShare * holdings;
      final krwAmt = info.currency == 'USD' ? nativeAmt * rate : nativeAmt;

      monthMap[key]![id] = (monthMap[key]![id] ?? 0) + krwAmt;
    }
  }

  // Convert to MonthlyDividend list
  final result = <MonthlyDividend>[];
  for (int i = 0; i < 12; i++) {
    final m = DateTime(now.year, now.month + i, 1);
    final key = '${m.year}-${m.month}';
    final bucket = monthMap[key] ?? {};

    final entries = bucket.entries.map((e) {
      final info = assetInfoMap[e.key]!;
      return DividendEntry(
        assetId: e.key,
        symbol: info.symbol,
        name: info.name,
        amountKrw: e.value,
        isKrStock: info.type == AssetType.krStock,
      );
    }).toList();
    entries.sort((a, b) => b.amountKrw.compareTo(a.amountKrw));

    result.add(MonthlyDividend(
      year: m.year,
      month: m.month,
      totalKrw: bucket.values.fold(0, (s, v) => s + v),
      entries: entries,
    ));
  }

  return result;
});

List<MonthlyDividend> _emptyYear() {
  final now = DateTime.now();
  return List.generate(
    12,
    (i) {
      final m = DateTime(now.year, now.month + i, 1);
      return MonthlyDividend(year: m.year, month: m.month, totalKrw: 0, entries: []);
    },
  );
}
