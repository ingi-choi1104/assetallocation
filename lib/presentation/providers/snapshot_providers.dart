import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/snapshot_local_ds.dart';
import '../../domain/entities/portfolio_snapshot.dart';
import 'database_providers.dart';

final snapshotLocalDsProvider = Provider<SnapshotLocalDataSource>((ref) {
  return SnapshotLocalDataSource(ref.watch(sharedPreferencesProvider));
});

class SnapshotNotifier extends StateNotifier<List<PortfolioSnapshot>> {
  final SnapshotLocalDataSource _ds;

  SnapshotNotifier(this._ds) : super(_load(_ds));

  static List<PortfolioSnapshot> _load(SnapshotLocalDataSource ds) {
    final list = ds.loadAll();
    list.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return list;
  }

  Future<void> addSnapshot(PortfolioSnapshot snapshot) async {
    final updated = [snapshot, ...state];
    state = updated;
    await _ds.saveAll(updated);
  }

  Future<void> deleteSnapshot(int id) async {
    final updated = state.where((s) => s.id != id).toList();
    state = updated;
    await _ds.saveAll(updated);
  }

  Future<void> updateMemo(int id, String memo) async {
    state = state.map((s) {
      if (s.id != id) return s;
      return PortfolioSnapshot(
        id: s.id,
        takenAt: s.takenAt,
        memo: memo.trim().isEmpty ? null : memo.trim(),
        totalValueKrw: s.totalValueKrw,
        totalInvested: s.totalInvested,
        returnRate: s.returnRate,
        annualizedReturnRate: s.annualizedReturnRate,
        portfolios: s.portfolios,
      );
    }).toList();
    await _ds.saveAll(state);
  }
}

final snapshotNotifierProvider =
    StateNotifierProvider<SnapshotNotifier, List<PortfolioSnapshot>>((ref) {
  return SnapshotNotifier(ref.watch(snapshotLocalDsProvider));
});
