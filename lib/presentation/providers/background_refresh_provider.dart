import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/price_repository_impl.dart';
import '../../domain/enums/asset_type.dart';
import 'database_providers.dart';
import 'economic_indicator_providers.dart';
import 'price_providers.dart';

// ── Live price overrides ───────────────────────────────────────────────────────
// Populated as background refresh fetches live prices.
// portfolioPricesProvider watches this to rebuild UI when new prices arrive.

class LivePriceOverrideNotifier extends StateNotifier<Map<int, double>> {
  LivePriceOverrideNotifier() : super(const {});

  void setPrices(Map<int, double> prices) {
    if (prices.isEmpty) return;
    state = {...state, ...prices};
  }
}

final livePriceOverrideProvider =
    StateNotifierProvider<LivePriceOverrideNotifier, Map<int, double>>((ref) {
  return LivePriceOverrideNotifier();
});

// ── Background price refresh ───────────────────────────────────────────────────
// Fetches live prices asynchronously (non-blocking I/O on main isolate).
// Starts on app launch and repeats every 5 minutes.
// Also used by the manual sync button.

class BackgroundPriceRefreshNotifier extends StateNotifier<bool> {
  final Ref _ref;
  Timer? _timer;
  bool _isRefreshing = false;
  DateTime? _lastRefresh;

  BackgroundPriceRefreshNotifier(this._ref) : super(false);

  /// Start periodic background refresh (call once on app init).
  void start() {
    refreshNow();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => refreshNow());
  }

  /// Refresh when the app returns to the foreground, but only if the last
  /// refresh is older than [minInterval]. Android suspends the periodic timer
  /// while backgrounded, so without this a resumed app shows stale prices
  /// until the next tick.
  void refreshOnResume({
    Duration minInterval = const Duration(seconds: 30),
  }) {
    final last = _lastRefresh;
    if (last != null && DateTime.now().difference(last) < minInterval) return;
    refreshNow();
  }

  /// Trigger an immediate refresh (also used by manual sync button).
  Future<void> refreshNow() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (mounted) state = true;

    try {
      final repo = _ref.read(priceRepositoryProvider);
      final db = _ref.read(appDatabaseProvider);
      final liveNotifier = _ref.read(livePriceOverrideProvider.notifier);

      // Refresh USD/KRW rate in the background
      _ref.invalidate(usdKrwRateProvider);

      final assets = await db.assetDao.getAll();
      final cryptoAssets = <int>[];
      final otherAssets = <int>[];

      for (final asset in assets) {
        final type = AssetType.fromValue(asset.assetType);
        if (type == AssetType.cash) continue;
        if (type == AssetType.crypto) {
          cryptoAssets.add(asset.id);
        } else {
          otherAssets.add(asset.id);
        }
      }

      // Prices are fetched WITHOUT per-asset DB writes and flushed to the UI in
      // a single batched state update. The DB is persisted once at the end.
      // (Writing lastPrice per asset re-fires the assets-table Drift stream,
      // recomputing every portfolio's metrics N times — the source of the jank.)

      // Non-crypto: throttled at 3 concurrent requests.
      final results = <PriceFetchResult>[];
      await _throttledFetch(otherAssets, repo, results, maxConcurrent: 3);
      if (mounted && results.isNotEmpty) {
        liveNotifier
            .setPrices({for (final r in results) r.assetId: r.price});
      }

      // Crypto: sequential (CoinGecko rate limit), flushed as one batch.
      final cryptoResults = <PriceFetchResult>[];
      for (final assetId in cryptoAssets) {
        final r = await repo.fetchQuoteNoPersist(assetId);
        if (r != null) cryptoResults.add(r);
      }
      if (mounted && cryptoResults.isNotEmpty) {
        liveNotifier
            .setPrices({for (final r in cryptoResults) r.assetId: r.price});
      }

      // Persist everything in ONE batched DB write → a single stream emission
      // instead of one per asset.
      await repo.persistPrices([...results, ...cryptoResults]);

      await _ref.read(settingsLocalDsProvider).setLastSyncTime(DateTime.now());

      // Also refresh economic indicators in background
      _ref.read(economicIndicatorsProvider.notifier).refresh();
    } catch (_) {
      // Silent fail — cached prices remain visible
    } finally {
      _lastRefresh = DateTime.now();
      _isRefreshing = false;
      if (mounted) state = false;
    }
  }

  /// Fetches prices for [assetIds] with at most [maxConcurrent] in-flight
  /// requests, accumulating results into [results] (not persisted or applied to
  /// state here — the caller flushes to the UI and persists in single batches).
  Future<void> _throttledFetch(
    List<int> assetIds,
    PriceRepositoryImpl repo,
    List<PriceFetchResult> results, {
    required int maxConcurrent,
  }) async {
    if (assetIds.isEmpty) return;

    int running = 0;
    int nextIndex = 0;
    final completer = Completer<void>();

    void startNext() {
      while (running < maxConcurrent && nextIndex < assetIds.length) {
        final assetId = assetIds[nextIndex++];
        running++;
        repo.fetchQuoteNoPersist(assetId).then((r) {
          if (r != null) {
            results.add(r);
          }
        }).whenComplete(() {
          running--;
          if (nextIndex < assetIds.length) {
            startNext();
          } else if (running == 0) {
            if (!completer.isCompleted) completer.complete();
          }
        });
      }
    }

    startNext();
    if (running == 0) return;
    return completer.future;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final backgroundPriceRefreshProvider =
    StateNotifierProvider<BackgroundPriceRefreshNotifier, bool>((ref) {
  return BackgroundPriceRefreshNotifier(ref);
});
