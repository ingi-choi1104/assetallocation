import '../../domain/repositories/settings_repository.dart';
import '../datasources/local/settings_local_ds.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource _local;

  SettingsRepositoryImpl(this._local);

  @override
  Future<String?> getFssApiKey() async => _local.getFssApiKey();

  @override
  Future<void> setFssApiKey(String key) => _local.setFssApiKey(key);

  @override
  Future<String> getBaseCurrency() async => _local.getBaseCurrency();

  @override
  Future<void> setBaseCurrency(String currency) =>
      _local.setBaseCurrency(currency);

  @override
  Future<bool> getNotificationsEnabled() async =>
      _local.getNotificationsEnabled();

  @override
  Future<void> setNotificationsEnabled(bool enabled) =>
      _local.setNotificationsEnabled(enabled);

  @override
  Future<DateTime?> getLastSyncTime() async => _local.getLastSyncTime();

  @override
  Future<void> setLastSyncTime(DateTime time) =>
      _local.setLastSyncTime(time);
}
