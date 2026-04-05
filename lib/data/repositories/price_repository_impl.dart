import 'dart:async';

import '../../domain/entities/price_point.dart';
import '../../domain/enums/asset_type.dart';
import '../../domain/repositories/price_repository.dart';
import '../database/app_database.dart';
import '../datasources/remote/yahoo_finance_ds.dart';
import '../datasources/remote/naver_finance_ds.dart';
import '../datasources/remote/coingecko_ds.dart';
import '../datasources/remote/fss_ds.dart';
import '../datasources/local/settings_local_ds.dart';

/// 1 troy oz = 31.1035 grams
const double _troyOzPerGram = 31.1035;

/// Price change information for an asset
class PriceChangeInfo {
  final double currentPrice;
  final double? previousClose;
  final double? changePercent;

  const PriceChangeInfo({
    required this.currentPrice,
    this.previousClose,
    this.changePercent,
  });
}

class PriceRepositoryImpl implements PriceRepository {
  final AppDatabase _db;
  final YahooFinanceDataSource _yahoo;
  final NaverFinanceDataSource _naver;
  final CoinGeckoDataSource _coinGecko;
  final FssDataSource _fss;
  final SettingsLocalDataSource _settings;

  /// In-memory cache of price change data per assetId
  final Map<int, PriceChangeInfo> _priceChangeCache = {};

  PriceRepositoryImpl({
    required AppDatabase db,
    required YahooFinanceDataSource yahoo,
    required NaverFinanceDataSource naver,
    required CoinGeckoDataSource coinGecko,
    required FssDataSource fss,
    required SettingsLocalDataSource settings,
  })  : _db = db,
        _yahoo = yahoo,
        _naver = naver,
        _coinGecko = coinGecko,
        _fss = fss,
        _settings = settings;

  /// Returns cached price change info for an asset
  PriceChangeInfo? getPriceChange(int assetId) => _priceChangeCache[assetId];

  /// Loads cached prices and previousClose from DB into in-memory cache.
  /// Call once on app startup so daily change is available immediately.
  Future<void> initializePriceCache() async {
    final assets = await _db.assetDao.getAll();
    for (final asset in assets) {
      if (asset.lastPrice == null) continue;
      final price = asset.lastPrice!;
      final prevClose = asset.lastPreviousClose;
      double? changePercent;
      if (prevClose != null && prevClose > 0) {
        changePercent = (price - prevClose) / prevClose * 100;
      }
      _priceChangeCache[asset.id] = PriceChangeInfo(
        currentPrice: price,
        previousClose: prevClose,
        changePercent: changePercent,
      );
    }
  }

  @override
  Future<List<PricePoint>> getPriceHistory(int assetId, {int days = 365}) async {
    final rows = await _db.priceHistoryDao.getByAsset(assetId, days: days);
    return rows
        .map((r) => PricePoint(
              assetId: r.assetId,
              closePrice: r.closePrice,
              date: r.date,
              fetchedAt: r.fetchedAt,
            ))
        .toList();
  }

  @override
  Future<void> savePriceHistory(List<PricePoint> prices) async {
    final companions = prices
        .map((p) => PriceHistoryCompanion.insert(
              assetId: p.assetId,
              closePrice: p.closePrice,
              date: p.date,
            ))
        .toList();
    await _db.priceHistoryDao.insertManyOrReplace(companions);
  }

  @override
  Future<double?> fetchCurrentPrice(int assetId) async {
    final asset = await _db.assetDao.getById(assetId);
    if (asset == null) return null;

    final assetType = AssetType.fromValue(asset.assetType);

    // Cash is always 1.0 native currency — handle before network try block
    // so it is guaranteed even for brand-new assets with no lastPrice in DB.
    if (assetType == AssetType.cash) {
      _priceChangeCache[assetId] = const PriceChangeInfo(
        currentPrice: 1.0,
        previousClose: 1.0,
        changePercent: 0.0,
      );
      return 1.0;
    }

    double? price;
    double? previousClose;
    double? changePercent;

    try {
      switch (assetType) {
        case AssetType.usStock:
          final quote = await _yahoo.fetchCurrentPrice(asset.symbol);
          price = quote?.price;
          previousClose = quote?.previousClose;
        case AssetType.gold:
          final quote = await _yahoo.fetchCurrentPrice('XAUUSD=X');
          if (quote != null) {
            price = quote.price / _troyOzPerGram;
            if (quote.previousClose != null) {
              previousClose = quote.previousClose! / _troyOzPerGram;
            }
          }
        case AssetType.krStock:
          try {
            final quote = await _naver.fetchCurrentPrice(asset.symbol);
            price = quote?.price;
            previousClose = quote?.previousClose;
          } catch (_) {}
          if (price == null) {
            for (final suffix in ['.KS', '.KQ']) {
              try {
                final quote =
                    await _yahoo.fetchCurrentPrice('${asset.symbol}$suffix');
                price = quote?.price;
                previousClose = quote?.previousClose;
                if (price != null) break;
              } catch (_) {}
            }
          }
        case AssetType.crypto:
          final coin = await _coinGecko.fetchCurrentPrice(asset.symbol);
          price = coin?.priceKrw;
          if (coin?.changePercent24h != null) {
            changePercent = coin!.changePercent24h;
            if (price != null && changePercent != null) {
              previousClose = price / (1 + changePercent / 100);
            }
          }
        case AssetType.krFund:
          final apiKey = _settings.getFssApiKey() ?? '';
          final fundCode = asset.fundCode ?? asset.symbol;
          final nav = await _fss.fetchFundNav(fundCode, apiKey);
          price = nav?.nav;
        case AssetType.cash:
          // Cash is always worth 1 unit of its native currency
          price = 1.0;
          previousClose = 1.0;
          changePercent = 0.0;
      }

      // Persist price and previousClose to DB, update in-memory cache
      if (price != null) {
        if (previousClose != null && previousClose > 0) {
          changePercent ??= (price - previousClose) / previousClose * 100;
        }
        await _db.assetDao.updateLastPriceAndPreviousClose(
            assetId, price, previousClose);
        _priceChangeCache[assetId] = PriceChangeInfo(
          currentPrice: price,
          previousClose: previousClose,
          changePercent: changePercent,
        );
      }
      return price;
    } catch (_) {
      final lp = asset.lastPrice;
      if (lp != null) {
        _priceChangeCache.putIfAbsent(
          assetId,
          () => PriceChangeInfo(currentPrice: lp),
        );
      }
      return lp;
    }
  }

  @override
  Future<void> syncAllPrices() async {
    final assets = await _db.assetDao.getAll();

    final cryptoAssets = <AssetRecord>[];
    final otherAssets = <AssetRecord>[];
    for (final asset in assets) {
      final type = AssetType.fromValue(asset.assetType);
      if (type == AssetType.cash) continue; // Cash is always 1.0
      if (type == AssetType.crypto) {
        cryptoAssets.add(asset);
      } else {
        otherAssets.add(asset);
      }
    }

    // Throttled parallel fetch — max 3 concurrent HTTP requests
    // to avoid flooding network/memory while keeping UI responsive.
    await _throttledFetch(otherAssets, maxConcurrent: 3);

    // Crypto: sequential with rate-limit delays (CoinGecko)
    for (final asset in cryptoAssets) {
      await _fetchAndStore(asset);
    }

    await _settings.setLastSyncTime(DateTime.now());
  }

  /// Fetches prices for [assets] with at most [maxConcurrent] in-flight requests.
  Future<void> _throttledFetch(
    List<AssetRecord> assets, {
    required int maxConcurrent,
  }) async {
    if (assets.isEmpty) return;

    int running = 0;
    int nextIndex = 0;
    final completer = Completer<void>();

    void startNext() {
      while (running < maxConcurrent && nextIndex < assets.length) {
        final asset = assets[nextIndex++];
        running++;
        _fetchAndStore(asset).whenComplete(() {
          running--;
          if (nextIndex < assets.length) {
            startNext();
          } else if (running == 0) {
            completer.complete();
          }
        });
      }
    }

    startNext();
    // If the list was empty or instantly done
    if (assets.isEmpty || (running == 0 && nextIndex >= assets.length)) {
      return;
    }
    return completer.future;
  }

  Future<void> _fetchAndStore(AssetRecord asset) async {
    try {
      final price = await fetchCurrentPrice(asset.id);
      if (price != null) {
        await _db.priceHistoryDao.insertOrReplace(
          PriceHistoryCompanion.insert(
            assetId: asset.id,
            closePrice: price,
            date: DateTime.now(),
          ),
        );
      }
    } catch (_) {}
  }
}
