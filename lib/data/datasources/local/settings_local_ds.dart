import 'package:shared_preferences/shared_preferences.dart';

class SettingsLocalDataSource {
  static const _fssApiKey = 'fss_api_key';
  static const _baseCurrency = 'base_currency';
  static const _notificationsEnabled = 'notifications_enabled';
  static const _lastSyncTime = 'last_sync_time';
  static const _hidePurchasePrice = 'hide_purchase_price';

  final SharedPreferences _prefs;

  SettingsLocalDataSource(this._prefs);

  String? getFssApiKey() => _prefs.getString(_fssApiKey);
  Future<void> setFssApiKey(String key) => _prefs.setString(_fssApiKey, key);

  String getBaseCurrency() => _prefs.getString(_baseCurrency) ?? 'KRW';
  Future<void> setBaseCurrency(String currency) =>
      _prefs.setString(_baseCurrency, currency);

  bool getNotificationsEnabled() =>
      _prefs.getBool(_notificationsEnabled) ?? true;
  Future<void> setNotificationsEnabled(bool enabled) =>
      _prefs.setBool(_notificationsEnabled, enabled);

  DateTime? getLastSyncTime() {
    final ms = _prefs.getInt(_lastSyncTime);
    return ms != null
        ? DateTime.fromMillisecondsSinceEpoch(ms)
        : null;
  }

  Future<void> setLastSyncTime(DateTime time) =>
      _prefs.setInt(_lastSyncTime, time.millisecondsSinceEpoch);

  bool getHidePurchasePrice() =>
      _prefs.getBool(_hidePurchasePrice) ?? false;
  Future<void> setHidePurchasePrice(bool hide) =>
      _prefs.setBool(_hidePurchasePrice, hide);

  // Currency display toggle
  static const _showKrw = 'show_krw';
  bool getShowKrw() => _prefs.getBool(_showKrw) ?? false;
  Future<void> setShowKrw(bool show) => _prefs.setBool(_showKrw, show);

  // Cached USD/KRW rate
  static const _cachedUsdKrwRate = 'cached_usd_krw_rate';
  double? getCachedUsdKrwRate() => _prefs.getDouble(_cachedUsdKrwRate);
  Future<void> setCachedUsdKrwRate(double rate) =>
      _prefs.setDouble(_cachedUsdKrwRate, rate);

  // Portfolio sort order (comma-separated IDs)
  static const _portfolioOrder = 'portfolio_order';
  List<int> getPortfolioOrder() {
    final str = _prefs.getString(_portfolioOrder);
    if (str == null || str.isEmpty) return [];
    return str
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toList();
  }
  Future<void> setPortfolioOrder(List<int> ids) =>
      _prefs.setString(_portfolioOrder, ids.join(','));

  // Unified home item order: "p:1,b:2,p:3" (p=portfolio, b=bundle)
  static const _homeOrder = 'home_item_order_v1';
  List<String> getHomeOrder() {
    final str = _prefs.getString(_homeOrder);
    if (str == null || str.isEmpty) return [];
    return str.split(',').where((s) => s.isNotEmpty).toList();
  }
  Future<void> setHomeOrder(List<String> keys) =>
      _prefs.setString(_homeOrder, keys.join(','));

  // Portfolios excluded from global total calculation
  static const _excludedPortfolios = 'excluded_portfolios_v1';
  List<int> getExcludedPortfolios() {
    final str = _prefs.getString(_excludedPortfolios);
    if (str == null || str.isEmpty) return [];
    return str.split(',').map(int.tryParse).whereType<int>().toList();
  }
  Future<void> setExcludedPortfolios(List<int> ids) =>
      _prefs.setString(_excludedPortfolios, ids.join(','));

  // Bundles excluded from global total calculation
  static const _excludedBundles = 'excluded_bundles_v1';
  List<int> getExcludedBundles() {
    final str = _prefs.getString(_excludedBundles);
    if (str == null || str.isEmpty) return [];
    return str.split(',').map(int.tryParse).whereType<int>().toList();
  }
  Future<void> setExcludedBundles(List<int> ids) =>
      _prefs.setString(_excludedBundles, ids.join(','));

  // Economic indicators collapsed state
  static const _indicatorsCollapsed = 'indicators_collapsed';
  bool getIndicatorsCollapsed() =>
      _prefs.getBool(_indicatorsCollapsed) ?? false;
  Future<void> setIndicatorsCollapsed(bool v) =>
      _prefs.setBool(_indicatorsCollapsed, v);
}
