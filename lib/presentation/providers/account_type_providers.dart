import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/portfolio_account_type.dart';
import 'database_providers.dart';

class AccountTypeNotifier
    extends StateNotifier<Map<int, PortfolioAccountType>> {
  final SharedPreferences _prefs;
  static const _key = 'portfolio_account_types_v1';

  AccountTypeNotifier(this._prefs) : super(_load(_prefs));

  static Map<int, PortfolioAccountType> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
            int.parse(k),
            PortfolioAccountType.values.firstWhere(
              (e) => e.name == v,
              orElse: () => PortfolioAccountType.general,
            ),
          ));
    } catch (_) {
      return {};
    }
  }

  PortfolioAccountType getType(int portfolioId) =>
      state[portfolioId] ?? PortfolioAccountType.general;

  Future<void> setType(int portfolioId, PortfolioAccountType type) async {
    state = {...state, portfolioId: type};
    await _prefs.setString(
      _key,
      jsonEncode(state.map((k, v) => MapEntry(k.toString(), v.name))),
    );
  }
}

final accountTypeNotifierProvider = StateNotifierProvider<AccountTypeNotifier,
    Map<int, PortfolioAccountType>>((ref) {
  return AccountTypeNotifier(ref.read(sharedPreferencesProvider));
});
