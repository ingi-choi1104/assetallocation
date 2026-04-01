import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/portfolio_snapshot.dart';

class SnapshotLocalDataSource {
  static const _key = 'portfolio_snapshots_v1';
  final SharedPreferences _prefs;

  SnapshotLocalDataSource(this._prefs);

  List<PortfolioSnapshot> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => PortfolioSnapshot.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<PortfolioSnapshot> snapshots) async {
    await _prefs.setString(
      _key,
      jsonEncode(snapshots.map((s) => s.toJson()).toList()),
    );
  }
}
