import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/portfolio_bundle_local_ds.dart';
import '../../data/datasources/local/settings_local_ds.dart';
import '../../domain/entities/portfolio.dart';
import '../../domain/entities/portfolio_bundle.dart';
import 'database_providers.dart';
import 'portfolio_providers.dart';

// ─── DataSource Provider ───────────────────────────────────────────────────────

final portfolioBundleLocalDsProvider = Provider<PortfolioBundleLocalDataSource>((ref) {
  return PortfolioBundleLocalDataSource(ref.read(sharedPreferencesProvider));
});

// ─── Bundle State Notifier ─────────────────────────────────────────────────────

class PortfolioBundleNotifier extends StateNotifier<List<PortfolioBundle>> {
  final PortfolioBundleLocalDataSource _ds;

  PortfolioBundleNotifier(this._ds) : super(_ds.getBundles());

  /// Create a new bundle from the given portfolio IDs.
  Future<void> createBundle(List<int> portfolioIds, String name) async {
    final newId = state.isEmpty ? 1 : state.map((b) => b.id).reduce(max) + 1;
    final bundle = PortfolioBundle(
      id: newId,
      name: name,
      portfolioIds: portfolioIds,
      sortOrder: state.length,
    );
    state = [...state, bundle];
    await _ds.saveBundles(state);
  }

  /// Add a portfolio to an existing bundle (no-op if already member).
  Future<void> addToBundle(int bundleId, int portfolioId) async {
    state = state.map((b) {
      if (b.id == bundleId && !b.portfolioIds.contains(portfolioId)) {
        return b.copyWith(portfolioIds: [...b.portfolioIds, portfolioId]);
      }
      return b;
    }).toList();
    await _ds.saveBundles(state);
  }

  /// Remove a portfolio from its bundle.
  /// Bundles with fewer than 2 portfolios are automatically dissolved.
  Future<void> removeFromBundle(int bundleId, int portfolioId) async {
    state = state
        .map((b) {
          if (b.id != bundleId) return b;
          return b.copyWith(
            portfolioIds: b.portfolioIds.where((id) => id != portfolioId).toList(),
          );
        })
        .where((b) => b.portfolioIds.length >= 2)
        .toList();
    await _ds.saveBundles(state);
  }

  /// Dissolve (delete) a bundle. All portfolios become ungrouped.
  Future<void> dissolveBundle(int bundleId) async {
    state = state.where((b) => b.id != bundleId).toList();
    await _ds.saveBundles(state);
  }

  /// Rename a bundle.
  Future<void> renameBundle(int bundleId, String name) async {
    state = state.map((b) {
      if (b.id == bundleId) return b.copyWith(name: name);
      return b;
    }).toList();
    await _ds.saveBundles(state);
  }

  /// Returns the bundle that contains [portfolioId], or null.
  PortfolioBundle? bundleForPortfolio(int portfolioId) {
    for (final b in state) {
      if (b.portfolioIds.contains(portfolioId)) return b;
    }
    return null;
  }
}

final portfolioBundleNotifierProvider =
    StateNotifierProvider<PortfolioBundleNotifier, List<PortfolioBundle>>((ref) {
  return PortfolioBundleNotifier(ref.read(portfolioBundleLocalDsProvider));
});

// ─── Excluded Portfolios ───────────────────────────────────────────────────────
// Portfolios toggled off from global total calculation on the home screen.

class ExcludedPortfoliosNotifier extends StateNotifier<Set<int>> {
  final SettingsLocalDataSource _ds;

  ExcludedPortfoliosNotifier(this._ds)
      : super(_ds.getExcludedPortfolios().toSet());

  Future<void> toggle(int portfolioId) async {
    final next = Set<int>.from(state);
    if (next.contains(portfolioId)) {
      next.remove(portfolioId);
    } else {
      next.add(portfolioId);
    }
    state = next;
    await _ds.setExcludedPortfolios(next.toList());
  }
}

final excludedPortfoliosProvider =
    StateNotifierProvider<ExcludedPortfoliosNotifier, Set<int>>((ref) {
  return ExcludedPortfoliosNotifier(ref.read(settingsLocalDsProvider));
});

// ─── Excluded Bundles ──────────────────────────────────────────────────────────
// Bundles toggled off from global total calculation on the home screen.

class ExcludedBundlesNotifier extends StateNotifier<Set<int>> {
  final SettingsLocalDataSource _ds;

  ExcludedBundlesNotifier(this._ds)
      : super(_ds.getExcludedBundles().toSet());

  Future<void> toggle(int bundleId) async {
    final next = Set<int>.from(state);
    if (next.contains(bundleId)) {
      next.remove(bundleId);
    } else {
      next.add(bundleId);
    }
    state = next;
    await _ds.setExcludedBundles(next.toList());
  }
}

final excludedBundlesProvider =
    StateNotifierProvider<ExcludedBundlesNotifier, Set<int>>((ref) {
  return ExcludedBundlesNotifier(ref.read(settingsLocalDsProvider));
});

// ─── Home Item Order ───────────────────────────────────────────────────────────
// Persists unified order of all home items (portfolios + bundles).
// Keys: "p:{id}" for portfolios, "b:{id}" for bundles.

class HomeOrderNotifier extends StateNotifier<List<String>> {
  final SettingsLocalDataSource _ds;

  HomeOrderNotifier(this._ds) : super(_ds.getHomeOrder());

  Future<void> updateOrder(List<String> keys) async {
    state = keys;
    await _ds.setHomeOrder(keys);
  }
}

final homeOrderProvider =
    StateNotifierProvider<HomeOrderNotifier, List<String>>((ref) {
  return HomeOrderNotifier(ref.read(settingsLocalDsProvider));
});

// ─── Home Items Provider ───────────────────────────────────────────────────────
// Combines portfolios + bundles into a single unified ordered list.

final homeItemsProvider = Provider<AsyncValue<List<HomeItem>>>((ref) {
  final portfoliosAsync = ref.watch(sortedPortfoliosProvider);
  final bundles = ref.watch(portfolioBundleNotifierProvider);
  final homeOrder = ref.watch(homeOrderProvider);

  return portfoliosAsync.when(
    data: (portfolios) {
      final portfolioMap = {for (final p in portfolios) p.id: p};
      final bundledIds = bundles.expand((b) => b.portfolioIds).toSet();

      // Build available item maps
      final bundleItemMap = <int, HomeBundleItem>{};
      for (final bundle in bundles) {
        final members = bundle.portfolioIds
            .map((id) => portfolioMap[id])
            .whereType<Portfolio>()
            .toList();
        if (members.isNotEmpty) {
          bundleItemMap[bundle.id] =
              HomeBundleItem(bundle: bundle, portfolios: members);
        }
      }
      final ungroupedMap = <int, HomePortfolioItem>{};
      for (final p in portfolios) {
        if (!bundledIds.contains(p.id)) {
          ungroupedMap[p.id] = HomePortfolioItem(p);
        }
      }

      final items = <HomeItem>[];
      final usedBundleIds = <int>{};
      final usedPortfolioIds = <int>{};

      // Apply saved order
      for (final key in homeOrder) {
        if (key.startsWith('b:')) {
          final id = int.tryParse(key.substring(2));
          if (id != null && bundleItemMap.containsKey(id)) {
            items.add(bundleItemMap[id]!);
            usedBundleIds.add(id);
          }
        } else if (key.startsWith('p:')) {
          final id = int.tryParse(key.substring(2));
          if (id != null && ungroupedMap.containsKey(id)) {
            items.add(ungroupedMap[id]!);
            usedPortfolioIds.add(id);
          }
        }
      }

      // Append newly added items not yet in saved order
      for (final entry in bundleItemMap.entries) {
        if (!usedBundleIds.contains(entry.key)) items.add(entry.value);
      }
      for (final p in portfolios) {
        if (!bundledIds.contains(p.id) && !usedPortfolioIds.contains(p.id)) {
          items.add(ungroupedMap[p.id]!);
        }
      }

      return AsyncValue.data(items);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
