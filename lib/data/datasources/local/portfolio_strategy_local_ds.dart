import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Associates a portfolio with a dynamic strategy configuration.
class PortfolioStrategyEntry {
  final int portfolioId;
  final String strategyType; // e.g. 'vaa'
  final DateTime calculationDate;

  const PortfolioStrategyEntry({
    required this.portfolioId,
    required this.strategyType,
    required this.calculationDate,
  });

  Map<String, dynamic> toJson() => {
        'portfolioId': portfolioId,
        'strategyType': strategyType,
        'calculationDate': calculationDate.toIso8601String(),
      };

  factory PortfolioStrategyEntry.fromJson(Map<String, dynamic> j) =>
      PortfolioStrategyEntry(
        portfolioId: j['portfolioId'] as int,
        strategyType: j['strategyType'] as String,
        calculationDate: DateTime.parse(j['calculationDate'] as String),
      );
}

class PortfolioStrategyLocalDataSource {
  static const _key = 'portfolio_strategies_v1';
  final SharedPreferences _prefs;

  PortfolioStrategyLocalDataSource(this._prefs);

  List<PortfolioStrategyEntry> getAll() {
    final jsonStr = _prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) =>
              PortfolioStrategyEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  PortfolioStrategyEntry? getForPortfolio(int portfolioId) {
    for (final e in getAll()) {
      if (e.portfolioId == portfolioId) return e;
    }
    return null;
  }

  Future<void> save(PortfolioStrategyEntry entry) async {
    final all = getAll().where((e) => e.portfolioId != entry.portfolioId).toList();
    all.add(entry);
    await _prefs.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  Future<void> remove(int portfolioId) async {
    final all = getAll().where((e) => e.portfolioId != portfolioId).toList();
    await _prefs.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }
}
