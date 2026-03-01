import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/portfolio_bundle.dart';

class PortfolioBundleLocalDataSource {
  static const _key = 'portfolio_bundles_v1';
  final SharedPreferences _prefs;

  PortfolioBundleLocalDataSource(this._prefs);

  List<PortfolioBundle> getBundles() {
    final jsonStr = _prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => PortfolioBundle.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBundles(List<PortfolioBundle> bundles) async {
    final jsonStr = jsonEncode(bundles.map((b) => b.toJson()).toList());
    await _prefs.setString(_key, jsonStr);
  }
}
