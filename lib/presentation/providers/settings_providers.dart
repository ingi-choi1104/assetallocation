import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_providers.dart';

final fssApiKeyProvider = FutureProvider<String?>((ref) async {
  return ref.watch(settingsRepositoryProvider).getFssApiKey();
});

final baseCurrencyProvider = FutureProvider<String>((ref) async {
  return ref.watch(settingsRepositoryProvider).getBaseCurrency();
});

final notificationsEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(settingsRepositoryProvider).getNotificationsEnabled();
});

final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  return ref.watch(settingsRepositoryProvider).getLastSyncTime();
});

// ── Settings actions ──────────────────────────────────────────────────────────
class SettingsActions {
  final Ref _ref;
  SettingsActions(this._ref);

  Future<void> setFssApiKey(String key) async {
    await _ref.read(settingsRepositoryProvider).setFssApiKey(key);
    _ref.invalidate(fssApiKeyProvider);
  }

  Future<void> setBaseCurrency(String currency) async {
    await _ref.read(settingsRepositoryProvider).setBaseCurrency(currency);
    _ref.invalidate(baseCurrencyProvider);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _ref
        .read(settingsRepositoryProvider)
        .setNotificationsEnabled(enabled);
    _ref.invalidate(notificationsEnabledProvider);
  }
}

final settingsActionsProvider = Provider<SettingsActions>((ref) {
  return SettingsActions(ref);
});
