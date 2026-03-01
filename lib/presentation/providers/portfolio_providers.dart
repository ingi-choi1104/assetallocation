import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/portfolio.dart';
import 'database_providers.dart';

// ── Portfolio sort order (persisted to SharedPreferences) ────────────────────
class PortfolioOrderNotifier extends StateNotifier<List<int>> {
  final dynamic _settings;

  PortfolioOrderNotifier(this._settings)
      : super((_settings.getPortfolioOrder() as List<int>));

  Future<void> updateOrder(List<int> ids) async {
    state = ids;
    await _settings.setPortfolioOrder(ids);
  }
}

final portfolioOrderProvider =
    StateNotifierProvider<PortfolioOrderNotifier, List<int>>((ref) {
  return PortfolioOrderNotifier(ref.watch(settingsLocalDsProvider));
});

/// Portfolios sorted by user-defined order (falls back to DB order for
/// portfolios not yet in the saved list).
final sortedPortfoliosProvider = Provider<AsyncValue<List<Portfolio>>>((ref) {
  final portfoliosAsync = ref.watch(portfoliosStreamProvider);
  final order = ref.watch(portfolioOrderProvider);
  return portfoliosAsync.whenData((portfolios) {
    if (order.isEmpty) return portfolios;
    final orderMap = {for (int i = 0; i < order.length; i++) order[i]: i};
    final sorted = List.of(portfolios);
    sorted.sort((a, b) {
      final ia = orderMap[a.id] ?? order.length + a.id;
      final ib = orderMap[b.id] ?? order.length + b.id;
      return ia.compareTo(ib);
    });
    return sorted;
  });
});

// ── Watch all portfolios ───────────────────────────────────────────────────────
final portfoliosStreamProvider = StreamProvider<List<Portfolio>>((ref) {
  return ref.watch(portfolioRepositoryProvider).watchAllPortfolios();
});

// ── Single portfolio ──────────────────────────────────────────────────────────
final portfolioProvider =
    FutureProvider.family<Portfolio?, int>((ref, id) async {
  return ref.watch(portfolioRepositoryProvider).getPortfolioById(id);
});

// ── Portfolio CRUD actions ────────────────────────────────────────────────────
class PortfolioActions {
  final Ref _ref;
  PortfolioActions(this._ref);

  Future<int> create(Portfolio portfolio) {
    return _ref.read(portfolioRepositoryProvider).createPortfolio(portfolio);
  }

  Future<void> update(Portfolio portfolio) {
    return _ref.read(portfolioRepositoryProvider).updatePortfolio(portfolio);
  }

  Future<void> delete(int id) {
    return _ref.read(portfolioRepositoryProvider).deletePortfolio(id);
  }
}

final portfolioActionsProvider = Provider<PortfolioActions>((ref) {
  return PortfolioActions(ref);
});
