abstract interface class SettingsRepository {
  Future<String?> getFssApiKey();
  Future<void> setFssApiKey(String key);

  Future<String> getBaseCurrency();
  Future<void> setBaseCurrency(String currency);

  Future<bool> getNotificationsEnabled();
  Future<void> setNotificationsEnabled(bool enabled);

  Future<DateTime?> getLastSyncTime();
  Future<void> setLastSyncTime(DateTime time);
}
