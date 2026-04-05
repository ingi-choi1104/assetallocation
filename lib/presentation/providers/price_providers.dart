import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/price_repository_impl.dart';
import '../../domain/entities/price_point.dart';
import '../../domain/enums/asset_type.dart';
import 'background_refresh_provider.dart';
import 'database_providers.dart';

// ── Currency display toggle (false = native currency, true = KRW) ─────────────
// Persisted to SharedPreferences — loads saved value on startup.
final showKrwProvider = StateNotifierProvider<ShowKrwNotifier, bool>((ref) {
  final settings = ref.watch(settingsLocalDsProvider);
  return ShowKrwNotifier(settings);
});

class ShowKrwNotifier extends StateNotifier<bool> {
  final dynamic _settings;
  ShowKrwNotifier(this._settings) : super(_settings.getShowKrw() as bool);

  void toggle(bool value) {
    state = value;
    _settings.setShowKrw(value);
  }
}

// ── Live current price from API (one-shot) ────────────────────────────────────
final livePriceProvider =
    FutureProvider.family<double?, int>((ref, assetId) async {
  // Cash assets are always 1.0 — skip network call
  final asset = await ref.watch(appDatabaseProvider).assetDao.getById(assetId);
  if (asset != null && AssetType.fromValue(asset.assetType) == AssetType.cash) {
    return 1.0;
  }
  try {
    return await ref.watch(priceRepositoryProvider).fetchCurrentPrice(assetId);
  } catch (_) {
    return null;
  }
});

// ── Live USD/KRW exchange rate ─────────────────────────────────────────────────
// Uses SharedPreferences to cache the last known rate.
// Fallback to cached rate on API failure, then to 1400.0 as last resort.
final usdKrwRateProvider = FutureProvider<double>((ref) async {
  final settings = ref.watch(settingsLocalDsProvider);
  final cachedRate = settings.getCachedUsdKrwRate();
  final fallback = cachedRate ?? 1400.0;

  try {
    final quote = await ref
        .watch(yahooFinanceDsProvider)
        .fetchCurrentPrice('USDKRW=X');
    final rate = quote?.price;

    // Validate: USD/KRW should be between 900 and 2000
    if (rate != null && rate > 900 && rate < 2000) {
      await settings.setCachedUsdKrwRate(rate);
      return rate;
    }
    return fallback;
  } catch (_) {
    return fallback;
  }
});

// ── Price history for a single asset ─────────────────────────────────────────
final priceHistoryProvider =
    FutureProvider.family<List<PricePoint>, int>((ref, assetId) async {
  return ref.watch(priceRepositoryProvider).getPriceHistory(assetId);
});

// ── Sync status ───────────────────────────────────────────────────────────────
class SyncState {
  final bool isSyncing;
  final DateTime? lastSync;
  final String? error;

  const SyncState({
    this.isSyncing = false,
    this.lastSync,
    this.error,
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSync,
    String? error,
  }) =>
      SyncState(
        isSyncing: isSyncing ?? this.isSyncing,
        lastSync: lastSync ?? this.lastSync,
        error: error,
      );
}

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;

  SyncNotifier(this._ref) : super(const SyncState());

  Future<void> syncAll() async {
    state = state.copyWith(isSyncing: true, error: null);
    try {
      // Use background refresh so live price overrides are updated
      await _ref.read(backgroundPriceRefreshProvider.notifier).refreshNow();
      state = state.copyWith(
        isSyncing: false,
        lastSync: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }
}

final syncNotifierProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});

/// Synchronous USD/KRW rate — uses loaded value, or cached from SharedPreferences.
/// Safe to use in synchronous providers and widgets without awaiting.
final usdKrwRateSyncProvider = Provider<double>((ref) {
  final asyncRate = ref.watch(usdKrwRateProvider);
  if (asyncRate.hasValue) return asyncRate.value!;
  // Not yet loaded — use cached rate from SharedPreferences
  final settings = ref.watch(settingsLocalDsProvider);
  return settings.getCachedUsdKrwRate() ?? 1400.0;
});

/// Returns cached price change info after prices have been fetched.
/// Call after portfolioMetricsProvider or livePriceProvider to ensure data is populated.
final priceChangeProvider =
    Provider.family<PriceChangeInfo?, int>((ref, assetId) {
  final repo = ref.watch(priceRepositoryProvider);
  return repo.getPriceChange(assetId);
});
