import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/app_database.dart';
import '../../services/backup_service.dart';
import '../../data/datasources/local/settings_local_ds.dart';
import '../../data/datasources/remote/coingecko_ds.dart';
import '../../data/datasources/remote/fss_ds.dart';
import '../../data/datasources/remote/naver_finance_ds.dart';
import '../../data/datasources/remote/yahoo_finance_ds.dart';
import '../../data/repositories/asset_repository_impl.dart';
import '../../data/repositories/portfolio_repository_impl.dart';
import '../../data/repositories/price_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/asset_repository.dart';
import '../../domain/repositories/portfolio_repository.dart';
import '../../domain/repositories/settings_repository.dart';

// ── Database ──────────────────────────────────────────────────────────────────
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ── HTTP Client ───────────────────────────────────────────────────────────────
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    },
  ));
  return dio;
});

// ── Settings ──────────────────────────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized');
});

final settingsLocalDsProvider =
    Provider<SettingsLocalDataSource>((ref) {
  return SettingsLocalDataSource(ref.watch(sharedPreferencesProvider));
});

// ── Remote DataSources ────────────────────────────────────────────────────────
final yahooFinanceDsProvider = Provider<YahooFinanceDataSource>((ref) {
  return YahooFinanceDataSource(ref.watch(dioProvider));
});

final naverFinanceDsProvider = Provider<NaverFinanceDataSource>((ref) {
  return NaverFinanceDataSource(ref.watch(dioProvider));
});

final coinGeckoDsProvider = Provider<CoinGeckoDataSource>((ref) {
  return CoinGeckoDataSource(ref.watch(dioProvider));
});

final fssDsProvider = Provider<FssDataSource>((ref) {
  return FssDataSource(ref.watch(dioProvider));
});

// ── Repositories ──────────────────────────────────────────────────────────────
final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  return PortfolioRepositoryImpl(ref.watch(appDatabaseProvider));
});

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepositoryImpl(ref.watch(appDatabaseProvider));
});

final priceRepositoryProvider = Provider<PriceRepositoryImpl>((ref) {
  return PriceRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    yahoo: ref.watch(yahooFinanceDsProvider),
    naver: ref.watch(naverFinanceDsProvider),
    coinGecko: ref.watch(coinGeckoDsProvider),
    fss: ref.watch(fssDsProvider),
    settings: ref.watch(settingsLocalDsProvider),
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(ref.watch(settingsLocalDsProvider));
});

// ── Backup ────────────────────────────────────────────────────────────────────
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(sharedPreferencesProvider),
  );
});
