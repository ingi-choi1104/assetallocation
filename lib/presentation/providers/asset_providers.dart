import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/coingecko_ds.dart';
import '../../data/datasources/remote/naver_finance_ds.dart';
import '../../data/datasources/remote/yahoo_finance_ds.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/portfolio_asset.dart';
import '../../domain/enums/asset_type.dart';
import 'database_providers.dart';

// ── Portfolio assets stream ────────────────────────────────────────────────────
final portfolioAssetsStreamProvider =
    StreamProvider.family<List<PortfolioAsset>, int>((ref, portfolioId) {
  return ref
      .watch(assetRepositoryProvider)
      .watchPortfolioAssets(portfolioId);
});

// ── Asset search ──────────────────────────────────────────────────────────────
class AssetSearchState {
  final bool isLoading;
  final List<Asset> results;
  final String? error;

  const AssetSearchState({
    this.isLoading = false,
    this.results = const [],
    this.error,
  });

  AssetSearchState copyWith({
    bool? isLoading,
    List<Asset>? results,
    String? error,
  }) =>
      AssetSearchState(
        isLoading: isLoading ?? this.isLoading,
        results: results ?? this.results,
        error: error,
      );
}

class AssetSearchNotifier extends StateNotifier<AssetSearchState> {
  final YahooFinanceDataSource _yahoo;
  final NaverFinanceDataSource _naver;
  final CoinGeckoDataSource _coinGecko;

  AssetSearchNotifier({
    required YahooFinanceDataSource yahoo,
    required NaverFinanceDataSource naver,
    required CoinGeckoDataSource coinGecko,
  })  : _yahoo = yahoo,
        _naver = naver,
        _coinGecko = coinGecko,
        super(const AssetSearchState());

  // Only physical spot gold qualifies as AssetType.gold (현물).
  // Gold ETFs (GLD, IAU, SGOL, PHYS) are classified as usStock.
  static const _goldSymbols = {'GC=F'};

  Future<void> search(String query, {AssetType? type}) async {
    // Cash filter works even with an empty query
    if (query.isEmpty && type != AssetType.cash) {
      state = const AssetSearchState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final results = await _buildSearchResults(query, type);
      state = AssetSearchState(results: results);
    } catch (e) {
      state = AssetSearchState(error: e.toString());
    }
  }

  Future<List<Asset>> _buildSearchResults(
      String query, AssetType? type) async {
    final results = <Asset>[];

    // 중복 제거용 심볼 추적 Set
    final seenSymbols = <String>{};

    // ── 금 키워드 직접 처리 ("금", "gold", "골드", "GLD" 등) ──────────────────
    final q = query.trim();
    final qLower = q.toLowerCase();
    // '현물', 'xau' 등 현물 금 관련 키워드를 모두 GC=F로 연결
    final isGoldQuery = q == '금' || q == '골드' || q == '현물' ||
        q == '금 현물' || q == '금현물' ||
        qLower == 'gold' || qLower == 'xau' || qLower == 'xauusd' ||
        qLower == 'gc=f' || q.toUpperCase() == 'GC=F';

    if (isGoldQuery && (type == null || type == AssetType.gold)) {
      const goldList = {
        'GC=F': '금 (Gold, USD/oz)',
      };
      for (final e in goldList.entries) {
        if (seenSymbols.contains(e.key)) continue;
        seenSymbols.add(e.key);
        results.add(Asset(
          id: 0,
          symbol: e.key,
          name: e.value,
          assetType: AssetType.gold,
          currency: 'USD',
          createdAt: DateTime.now(),
        ));
      }
    }

    // ── 현금 ─────────────────────────────────────────────────────────────────
    final isCashFilter = type == AssetType.cash;
    final isCashKeyword = !isCashFilter &&
        (q == '현금' ||
            q == '원화' || q == '원' ||
            q == '달러' || q == '달러화' ||
            q == '유로' ||
            q == '엔화' || q == '엔' ||
            q == '위안화' || q == '위안' ||
            qLower == 'cash' ||
            qLower == 'krw' || qLower == 'usd' ||
            qLower == 'eur' || qLower == 'jpy' || qLower == 'cny');
    if (isCashFilter || isCashKeyword) {
      results.add(Asset(
        id: 0,
        symbol: 'KRW_CASH',
        name: '원화 현금 (KRW)',
        assetType: AssetType.cash,
        currency: 'KRW',
        createdAt: DateTime.now(),
      ));
      results.add(Asset(
        id: 0,
        symbol: 'USD_CASH',
        name: '달러 현금 (USD)',
        assetType: AssetType.cash,
        currency: 'USD',
        createdAt: DateTime.now(),
      ));
      results.add(Asset(
        id: 0,
        symbol: 'EUR_CASH',
        name: '유로 현금 (EUR)',
        assetType: AssetType.cash,
        currency: 'EUR',
        createdAt: DateTime.now(),
      ));
      results.add(Asset(
        id: 0,
        symbol: 'JPY_CASH',
        name: '엔화 현금 (JPY)',
        assetType: AssetType.cash,
        currency: 'JPY',
        createdAt: DateTime.now(),
      ));
      results.add(Asset(
        id: 0,
        symbol: 'CNY_CASH',
        name: '위안화 현금 (CNY)',
        assetType: AssetType.cash,
        currency: 'CNY',
        createdAt: DateTime.now(),
      ));
      if (isCashFilter) return results;
    }

    // ── 미국 주식/ETF: Yahoo Finance 검색 ─────────────────────────────────────
    final needsUsSearch = type == null ||
        type == AssetType.usStock ||
        type == AssetType.gold;

    if (needsUsSearch) {
      try {
        final quotes = await _yahoo.searchSymbols(query);
        for (final q in quotes) {
          final symbol = q['symbol'] as String? ?? '';
          if (symbol.isEmpty) continue;

          final quoteType = (q['quoteType'] as String? ?? '').toUpperCase();

          // 미국 주식/ETF만 처리 (한국 종목은 아래 Naver 검색에서 별도 처리)
          if (symbol.endsWith('.KS') || symbol.endsWith('.KQ')) continue;

          if (quoteType == 'EQUITY' ||
              quoteType == 'ETF' ||
              quoteType == 'MUTUALFUND') {
            if (seenSymbols.contains(symbol)) continue;
            seenSymbols.add(symbol);

            final name = q['longname'] as String? ??
                q['shortname'] as String? ??
                symbol;
            final isGold = _goldSymbols.contains(symbol);
            results.add(Asset(
              id: 0,
              symbol: symbol,
              name: name,
              assetType: isGold ? AssetType.gold : AssetType.usStock,
              currency: 'USD',
              createdAt: DateTime.now(),
            ));
          }
        }
      } catch (_) {
        // API 실패 시 하드코딩 목록으로 폴백
        results.addAll(_usStockFallback(query.toUpperCase()));
      }
    }

    // ── 한국 주식/ETF: 하드코딩 목록(기본) + Naver API(보완) ────────────────
    final needsKrSearch = type == null || type == AssetType.krStock;

    if (needsKrSearch) {
      // 1) 하드코딩 목록으로 즉시 검색 (항상 동작)
      final localKr = _krStockSearch(query);
      for (final a in localKr) {
        if (seenSymbols.contains(a.symbol)) continue;
        seenSymbols.add(a.symbol);
        results.add(a);
      }

      // 2) Naver 자동완성 API로 추가 결과 보완 (이름 검색)
      try {
        final naverItems = await _naver.searchByName(query);
        for (final item in naverItems) {
          final krSymbol = item['symbol'] ?? '';
          final name = item['name'] ?? krSymbol;
          if (krSymbol.isEmpty || seenSymbols.contains(krSymbol)) continue;
          seenSymbols.add(krSymbol);
          results.add(Asset(
            id: 0,
            symbol: krSymbol,
            name: name,
            assetType: AssetType.krStock,
            currency: 'KRW',
            createdAt: DateTime.now(),
          ));
        }
      } catch (_) {
        // Naver API 실패해도 하드코딩 목록 결과로 충분
      }

      // 3) Yahoo Finance에서 .KS/.KQ 종목 추가 (코드 검색 보완)
      try {
        final yahooQuotes = await _yahoo.searchSymbols(query);
        for (final q in yahooQuotes) {
          final symbol = q['symbol'] as String? ?? '';
          if (!symbol.endsWith('.KS') && !symbol.endsWith('.KQ')) continue;
          final krSymbol =
              symbol.replaceAll('.KS', '').replaceAll('.KQ', '');
          if (seenSymbols.contains(krSymbol)) continue;
          seenSymbols.add(krSymbol);
          final name = q['longname'] as String? ??
              q['shortname'] as String? ??
              krSymbol;
          results.add(Asset(
            id: 0,
            symbol: krSymbol,
            name: name,
            assetType: AssetType.krStock,
            currency: 'KRW',
            createdAt: DateTime.now(),
          ));
        }
      } catch (_) {}
    }

    // CoinGecko 검색: 암호화폐
    if (type == null || type == AssetType.crypto) {
      try {
        final coins = await _coinGecko.searchCoins(query);
        for (final c in coins) {
          final id = c['id'] as String? ?? '';
          final name = c['name'] as String? ?? id;
          if (id.isNotEmpty) {
            results.add(Asset(
              id: 0,
              symbol: id,
              name: name,
              assetType: AssetType.crypto,
              currency: 'KRW',
              createdAt: DateTime.now(),
            ));
          }
        }
      } catch (_) {
        results.addAll(_cryptoFallback(query.toLowerCase()));
      }
    }

    return results;
  }

  // ── 한국 주식/ETF 하드코딩 목록 ──────────────────────────────────────────────
  // 코드로도, 한글 이름으로도 검색 가능
  static const _krStocks = <String, String>{
    // KOSPI 대형주
    '005930': '삼성전자',
    '000660': 'SK하이닉스',
    '373220': 'LG에너지솔루션',
    '005490': 'POSCO홀딩스',
    '005380': '현대차',
    '035420': 'NAVER',
    '000270': '기아',
    '051910': 'LG화학',
    '006400': '삼성SDI',
    '035720': '카카오',
    '055550': '신한지주',
    '105560': 'KB금융',
    '003550': 'LG',
    '012330': '현대모비스',
    '066570': 'LG전자',
    '096770': 'SK이노베이션',
    '034730': 'SK',
    '086790': '하나금융지주',
    '003670': 'POSCO퓨처엠',
    '028260': '삼성물산',
    '017670': 'SK텔레콤',
    '030200': 'KT',
    '015760': '한국전력',
    '032830': '삼성생명',
    '000810': '삼성화재',
    '018260': '삼성SDS',
    '024110': '기업은행',
    '010950': 'S-Oil',
    '011170': '롯데케미칼',
    '004020': '현대제철',
    '009150': '삼성전기',
    '010130': '고려아연',
    '000100': '유한양행',
    '068270': '셀트리온',
    '207940': '삼성바이오로직스',
    '326030': 'SK바이오팜',
    '402340': 'SK스퀘어',
    '003490': '대한항공',
    '011200': 'HMM',
    '033780': 'KT&G',
    // KOSDAQ
    '247540': '에코프로비엠',
    '086520': '에코프로',
    '091990': '셀트리온제약',
    '196170': '알테오젠',
    '035900': 'JYP Ent.',
    '041510': 'SM엔터테인먼트',
    '035760': 'CJ ENM',
    '263750': '펄어비스',
    '112040': '위메이드',
    '293490': '카카오게임즈',
    // 주요 KOSPI ETF
    '069500': 'KODEX 200',
    '102110': 'TIGER 200',
    '229200': 'KODEX 코스닥150',
    '252670': 'KODEX 200선물인버스2X',
    '122630': 'KODEX 레버리지',
    '233740': 'KODEX 코스닥150레버리지',
    '091160': 'KODEX 반도체',
    '091170': 'KODEX 은행',
    '139220': 'TIGER 200 금융',
    '305720': 'KODEX 2차전지산업',
    '364980': 'TIGER 2차전지테마',
    '148070': 'KOSEF 국고채10년',
    '143850': 'TIGER 미국나스닥100',
    '195930': 'TIGER 미국달러단기채권액티브',
    '411060': 'ACE KRX금현물',
    '133690': 'TIGER 미국채10년선물',
    '304660': 'KODEX 미국채울트라30년선물(H)',
    '176950': 'TIGER 골드선물(H)',
    '132030': 'KODEX 골드선물(H)',
  };

  List<Asset> _krStockSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return [];

    return _krStocks.entries
        .where((e) =>
            e.key.contains(q) || // 종목코드 검색
            e.value.contains(q)) // 한글 이름 검색
        .map((e) => Asset(
              id: 0,
              symbol: e.key,
              name: e.value,
              assetType: AssetType.krStock,
              currency: 'KRW',
              createdAt: DateTime.now(),
            ))
        .toList();
  }

  // Yahoo Finance API 실패 시 폴백용 하드코딩 목록
  List<Asset> _usStockFallback(String query) {
    const common = {
      'SPY': 'SPDR S&P 500 ETF',
      'QQQ': 'Invesco QQQ Trust',
      'VTI': 'Vanguard Total Stock Market ETF',
      'VOO': 'Vanguard S&P 500 ETF',
      'IVV': 'iShares Core S&P 500 ETF',
      'TLT': 'iShares 20+ Year Treasury Bond ETF',
      'IEF': 'iShares 7-10 Year Treasury Bond ETF',
      'SHY': 'iShares 1-3 Year Treasury Bond ETF',
      'AGG': 'iShares Core U.S. Aggregate Bond ETF',
      'BND': 'Vanguard Total Bond Market ETF',
      'LQD': 'iShares iBoxx Investment Grade Corporate Bond ETF',
      'HYG': 'iShares iBoxx High Yield Corporate Bond ETF',
      'GLD': 'SPDR Gold Shares ETF',
      'IAU': 'iShares Gold Trust ETF',
      'SLV': 'iShares Silver Trust',
      'AAPL': 'Apple Inc.',
      'MSFT': 'Microsoft Corporation',
      'GOOGL': 'Alphabet Inc.',
      'AMZN': 'Amazon.com Inc.',
      'NVDA': 'NVIDIA Corporation',
      'TSLA': 'Tesla Inc.',
      'META': 'Meta Platforms Inc.',
      'SCHD': 'Schwab US Dividend Equity ETF',
      'VNQ': 'Vanguard Real Estate ETF',
      'EFA': 'iShares MSCI EAFE ETF',
      'EEM': 'iShares MSCI Emerging Markets ETF',
      'TIP': 'iShares TIPS Bond ETF',
      'BIL': 'SPDR Bloomberg 1-3 Month T-Bill ETF',
    };

    return common.entries
        .where((e) =>
            e.key.contains(query) || e.value.toUpperCase().contains(query))
        .map((e) => Asset(
              id: 0,
              symbol: e.key,
              name: e.value,
              assetType:
                  _goldSymbols.contains(e.key) ? AssetType.gold : AssetType.usStock,
              currency: 'USD',
              createdAt: DateTime.now(),
            ))
        .toList();
  }

  List<Asset> _cryptoFallback(String query) {
    const common = {
      'bitcoin': 'Bitcoin',
      'ethereum': 'Ethereum',
      'binancecoin': 'BNB',
      'ripple': 'XRP',
      'solana': 'Solana',
      'cardano': 'Cardano',
      'dogecoin': 'Dogecoin',
    };

    return common.entries
        .where((e) =>
            e.key.contains(query) || e.value.toLowerCase().contains(query))
        .map((e) => Asset(
              id: 0,
              symbol: e.key,
              name: e.value,
              assetType: AssetType.crypto,
              currency: 'KRW',
              createdAt: DateTime.now(),
            ))
        .toList();
  }

  void clear() => state = const AssetSearchState();
}

final assetSearchProvider =
    StateNotifierProvider<AssetSearchNotifier, AssetSearchState>((ref) {
  return AssetSearchNotifier(
    yahoo: ref.watch(yahooFinanceDsProvider),
    naver: ref.watch(naverFinanceDsProvider),
    coinGecko: ref.watch(coinGeckoDsProvider),
  );
});

// ── Asset CRUD ────────────────────────────────────────────────────────────────
class AssetActions {
  final Ref _ref;
  AssetActions(this._ref);

  Future<int> upsertAsset(Asset asset) {
    return _ref.read(assetRepositoryProvider).upsertAsset(asset);
  }

  Future<int> addToPortfolio({
    required int portfolioId,
    required int assetId,
    required double targetWeight,
    required int sortOrder,
  }) {
    return _ref.read(assetRepositoryProvider).addAssetToPortfolio(
          portfolioId: portfolioId,
          assetId: assetId,
          targetWeight: targetWeight,
          sortOrder: sortOrder,
        );
  }

  Future<void> updateWeight(int portfolioAssetId, double weight) {
    return _ref
        .read(assetRepositoryProvider)
        .updateTargetWeight(portfolioAssetId, weight);
  }

  Future<void> updateSortOrders(Map<int, int> idToSortOrder) {
    return _ref.read(assetRepositoryProvider).updateSortOrders(idToSortOrder);
  }

  Future<void> removeFromPortfolio(int portfolioAssetId) {
    return _ref
        .read(assetRepositoryProvider)
        .removeAssetFromPortfolio(portfolioAssetId);
  }
}

final assetActionsProvider = Provider<AssetActions>((ref) {
  return AssetActions(ref);
});
