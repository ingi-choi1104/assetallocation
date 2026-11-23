import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/local/trend_cache_local_ds.dart';
import '../../data/datasources/remote/trend_price_ds.dart';
import '../../domain/entities/asset_trend.dart';
import '../../domain/entities/investment.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/enums/asset_type.dart';
import '../../domain/services/asset_trend_service.dart';
import 'asset_providers.dart';
import 'background_refresh_provider.dart';
import 'database_providers.dart';
import 'investment_providers.dart';
import 'portfolio_bundle_providers.dart';
import 'portfolio_providers.dart';
import 'price_providers.dart';
import 'transaction_providers.dart';

/// 추이 메뉴 전용 프로바이더. 기존 프로바이더는 읽기만 하고 바꾸지 않는다.

final trendPriceDsProvider = Provider<TrendPriceDataSource>((ref) {
  return TrendPriceDataSource(ref.watch(dioProvider));
});

final trendCacheDsProvider = Provider<TrendCacheLocalDataSource>((ref) {
  return TrendCacheLocalDataSource();
});

/// 시세를 강제로 다시 받게 하는 스위치 — 값을 올리면 추이가 재계산된다.
final trendReloadProvider = StateProvider<int>((ref) => 0);

/// 전체 자산(홈에서 합산 제외한 포트폴리오는 빼고)의 일별 추이.
///
/// 최대 5년치를 받아오며, 받아온 시세는 앱 문서 폴더의 JSON 파일에 캐시된다.
final assetTrendProvider = FutureProvider<TrendSeries>((ref) async {
  ref.watch(trendReloadProvider);

  final portfolios = await ref.watch(portfoliosStreamProvider.future);
  if (portfolios.isEmpty) return TrendSeries.empty;

  // 홈 화면과 같은 현재가를 쓴다 — 백그라운드 갱신으로 들어온 실시간 값이
  // 있으면 그것을, 없으면 DB에 저장된 마지막 가격을.
  final liveOverrides = ref.watch(livePriceOverrideProvider);

  // 홈의 '전체 자산'과 같은 기준으로 제외 항목을 반영한다.
  final excludedIds = ref.watch(excludedPortfoliosProvider);
  final excludedBundleIds = ref.watch(excludedBundlesProvider);
  final bundles = ref.watch(portfolioBundleNotifierProvider);
  final bundleExcludedIds = <int>{};
  for (final b in bundles) {
    if (excludedBundleIds.contains(b.id)) {
      bundleExcludedIds.addAll(b.portfolioIds);
    }
  }

  final included = portfolios
      .where((p) =>
          !excludedIds.contains(p.id) && !bundleExcludedIds.contains(p.id))
      .toList();
  if (included.isEmpty) return TrendSeries.empty;

  // ── 거래내역 · 투입금액 · 자산 목록 모으기 ────────────────────────────────
  final drafts = <_AssetDraft>[];
  final investments = <Investment>[];

  for (final portfolio in included) {
    investments
        .addAll(await ref.watch(investmentsStreamProvider(portfolio.id).future));

    final portfolioAssets =
        await ref.watch(portfolioAssetsStreamProvider(portfolio.id).future);
    for (final pa in portfolioAssets) {
      final asset = pa.asset;
      if (asset == null) continue;
      final transactions =
          await ref.watch(transactionsStreamProvider(pa.id).future);
      if (transactions.isEmpty) continue;

      drafts.add(_AssetDraft(
        assetId: pa.assetId,
        symbol: asset.symbol,
        name: asset.name.isNotEmpty ? asset.name : asset.symbol,
        type: asset.assetType,
        currency: asset.currency,
        currentPrice: asset.assetType == AssetType.cash
            ? 1.0
            : (liveOverrides[pa.assetId] ?? asset.lastPrice ?? 0),
        transactions: transactions,
      ));
    }
  }
  if (drafts.isEmpty && investments.isEmpty) return TrendSeries.empty;

  final start = AssetTrendService.startDate(
    assets: [for (final d in drafts) d.toInput(const [])],
    investments: investments,
  );
  if (start == null) return TrendSeries.empty;

  // ── 과거 시세 (캐시 우선, 없으면 조회) ────────────────────────────────────
  final priceDs = ref.watch(trendPriceDsProvider);
  final cache = ref.watch(trendCacheDsProvider);

  // 같은 자산이 여러 포트폴리오에 있어도 한 번만 받는다.
  final barsByAsset = <int, List<TrendBar>>{};
  for (final draft in drafts) {
    if (barsByAsset.containsKey(draft.assetId)) continue;
    if (draft.type == AssetType.cash) {
      barsByAsset[draft.assetId] = const [];
      continue;
    }

    final key = 'asset_${draft.assetId}';
    var bars = await cache.read(key, start);
    if (bars == null) {
      bars = await priceDs.fetchDailyHistory(
        symbol: draft.symbol,
        type: draft.type,
        start: start,
      );
      if (bars.isNotEmpty) await cache.write(key, start, bars);
    }
    barsByAsset[draft.assetId] = bars;
  }

  // ── 환율 ──────────────────────────────────────────────────────────────────
  final fxRates = await ref.watch(fxRatesProvider.future);
  final fxHistory = <String, List<TrendBar>>{};
  for (final currency
      in drafts.map((d) => d.currency.toUpperCase()).toSet()) {
    if (currency == 'KRW') continue;
    final key = 'fx_$currency';
    var bars = await cache.read(key, start);
    if (bars == null) {
      bars = await priceDs.fetchFxHistory(currency, start);
      if (bars.isNotEmpty) await cache.write(key, start, bars);
    }
    fxHistory[currency] = bars;
  }

  return AssetTrendService.build(
    assets: [
      for (final d in drafts) d.toInput(barsByAsset[d.assetId] ?? const [])
    ],
    fxHistory: fxHistory,
    currentFxRates: fxRates,
    investments: investments,
    startOverride: start,
  );
});

class _AssetDraft {
  final int assetId;
  final String symbol;
  final String name;
  final AssetType type;
  final String currency;
  final double currentPrice;
  final List<Transaction> transactions;

  const _AssetDraft({
    required this.assetId,
    required this.symbol,
    required this.name,
    required this.type,
    required this.currency,
    required this.currentPrice,
    required this.transactions,
  });

  TrendAssetInput toInput(List<TrendBar> bars) => TrendAssetInput(
        name: name,
        currency: currency,
        transactions: transactions,
        bars: bars,
        currentPrice: currentPrice,
      );
}

// ── MDD 계산 기간 (설정에서 변경) ────────────────────────────────────────────

class MddPeriodNotifier extends StateNotifier<MddPeriod> {
  static const _key = 'mdd_period_years_v1';

  final SharedPreferences _prefs;

  MddPeriodNotifier(this._prefs)
      : super(MddPeriod.fromYears(_prefs.getInt(_key)));

  Future<void> set(MddPeriod period) async {
    if (period == state) return;
    state = period;
    await _prefs.setInt(_key, period.years);
  }
}

final mddPeriodProvider =
    StateNotifierProvider<MddPeriodNotifier, MddPeriod>((ref) {
  return MddPeriodNotifier(ref.watch(sharedPreferencesProvider));
});

/// 전체 자산의 최대 낙폭(MDD). 추이 곡선에서 파생되므로 추가 조회가 없다.
/// 그릴 곡선 자체가 없으면 null — '최고점' 같은 표시가 잘못 뜨지 않게 한다.
final assetDrawdownProvider = Provider<AsyncValue<DrawdownResult?>>((ref) {
  final period = ref.watch(mddPeriodProvider);
  return ref.watch(assetTrendProvider).whenData((series) {
    if (!series.isUsable) return null;
    return AssetTrendService.drawdown(
      AssetTrendService.sliceYears(series.points, period.years),
    );
  });
});
