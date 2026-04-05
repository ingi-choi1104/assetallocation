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

  void setPrice(int assetId, double price) {
    state = {...state, assetId: price};
  }

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

  BackgroundPriceRefreshNotifier(this._ref) : super(false);

  /// Start periodic background refresh (call once on app init).
  void start() {
    refreshNow();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => refreshNow());
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

      // Non-crypto: throttled at 3 concurrent requests
      await _throttledFetch(otherAssets, repo, liveNotifier, maxConcurrent: 3);

      // Crypto: sequential (CoinGecko rate limit)
      for (final assetId in cryptoAssets) {
        final price = await repo.fetchCurrentPrice(assetId);
        if (price != null && mounted) {
          liveNotifier.setPrice(assetId, price);
        }
      }

      await _ref.read(settingsLocalDsProvider).setLastSyncTime(DateTime.now());

      // Also refresh economic indicators in background
      _ref.read(economicIndicatorsProvider.notifier).refresh();
    } catch (_) {
      // Silent fail — cached prices remain visible
    } finally {
      _isRefreshing = false;
      if (mounted) state = false;
    }
  }

  Future<void> _throttledFetch(
    List<int> assetIds,
    PriceRepositoryImpl repo,
    LivePriceOverrideNotifier liveNotifier, {
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
        repo.fetchCurrentPrice(assetId).then((price) {
          if (price != null && mounted) {
            liveNotifier.setPrice(assetId, price);
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
