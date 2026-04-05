import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches economic indicator prices in SharedPreferences.
/// Format: Map of symbol to price/previousClose/updatedAt entries.
class EconomicIndicatorLocalDs {
  static const _key = 'economic_indicators_v1';

  final SharedPreferences _prefs;
  EconomicIndicatorLocalDs(this._prefs);

  /// Returns cached data as Map of symbol to price/previousClose map.
  Map<String, Map<String, double>> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((symbol, data) {
        final d = data as Map<String, dynamic>;
        return MapEntry(symbol, {
          if (d['price'] != null) 'price': (d['price'] as num).toDouble(),
          if (d['previousClose'] != null)
            'previousClose': (d['previousClose'] as num).toDouble(),
        });
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAll(Map<String, Map<String, double?>> data) async {
    final encoded = json.encode(
      data.map((symbol, values) => MapEntry(
            symbol,
            {
              'price': values['price'],
              'previousClose': values['previousClose'],
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            },
          )),
    );
    await _prefs.setString(_key, encoded);
  }
}
