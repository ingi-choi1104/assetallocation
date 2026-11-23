import 'package:dio/dio.dart';

import '../../../domain/entities/asset_trend.dart';
import '../../../domain/enums/asset_type.dart';

/// 추이 메뉴 전용 과거 시세 조회기.
///
/// 기존 시세 데이터소스와 분리해 두었다 — 추이 화면만 쓰고, 다른 메뉴의
/// 가격 조회 경로에는 전혀 관여하지 않는다.
class TrendPriceDataSource {
  final Dio _dio;

  TrendPriceDataSource(this._dio);

  static const _browserUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
  static const _mobileUa =
      'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36';

  /// 국내 금 현물 (KRX, 원/g) — 자산의 symbol과 무관하게 이 코드를 쓴다.
  static const _goldReutersCode = 'M04020000';

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 자산의 원래 통화 기준 일별 종가, 날짜 오름차순.
  /// 과거 시세 제공처가 없으면 빈 목록을 돌려준다.
  Future<List<TrendBar>> fetchDailyHistory({
    required String symbol,
    required AssetType type,
    required DateTime start,
  }) async {
    final from = _dayKey(start);
    final now = DateTime.now();
    final days = now.difference(from).inDays + 1;

    try {
      switch (type) {
        case AssetType.usStock:
          return await _yahooDaily(symbol, from, now);

        case AssetType.krStock:
          final bars = await _naverDaily(symbol, days);
          if (bars.isNotEmpty) return bars;
          for (final suffix in ['.KS', '.KQ']) {
            final fallback = await _yahooDaily('$symbol$suffix', from, now);
            if (fallback.isNotEmpty) return fallback;
          }
          return const [];

        case AssetType.crypto:
          return await _cryptoDaily(symbol, from, now, days);

        case AssetType.gold:
          return await _naverMetalDaily(_goldReutersCode, from);

        case AssetType.krFund:
        case AssetType.cash:
          // 과거 시세 API 없음 — 호출측에서 현재가로 근사한다.
          return const [];
      }
    } catch (_) {
      return const [];
    }
  }

  /// {통화}/KRW 일별 종가. 실패하면 빈 목록 (호출측이 현재 환율로 대체).
  Future<List<TrendBar>> fetchFxHistory(String currency, DateTime start) async {
    final code = currency.toUpperCase();
    if (code == 'KRW') return const [];
    try {
      return await _yahooDaily('${code}KRW=X', _dayKey(start), DateTime.now());
    } catch (_) {
      return const [];
    }
  }

  // ── Yahoo Finance ───────────────────────────────────────────────────────────

  Future<List<TrendBar>> _yahooDaily(
      String symbol, DateTime from, DateTime to) async {
    final response = await _dio.get(
      'https://query2.finance.yahoo.com/v8/finance/chart/$symbol',
      queryParameters: {
        'interval': '1d',
        'period1': from.millisecondsSinceEpoch ~/ 1000,
        'period2': to.millisecondsSinceEpoch ~/ 1000,
      },
      options: Options(headers: {'User-Agent': _browserUa}),
    );

    final result = response.data?['chart']?['result'] as List?;
    if (result == null || result.isEmpty) return const [];
    final item = result.first;
    final timestamps = item['timestamp'] as List?;
    final closes = item['indicators']?['quote']?[0]?['close'] as List?;
    if (timestamps == null || closes == null) return const [];

    final bars = <TrendBar>[];
    for (int i = 0; i < timestamps.length && i < closes.length; i++) {
      final close = closes[i];
      if (close == null) continue;
      final value = (close as num).toDouble();
      if (value <= 0) continue;
      bars.add(TrendBar(
        date: _dayKey(
            DateTime.fromMillisecondsSinceEpoch((timestamps[i] as int) * 1000)),
        close: value,
      ));
    }
    bars.sort((a, b) => a.date.compareTo(b.date));
    return bars;
  }

  // ── 네이버 fchart (국내 주식/ETF) ───────────────────────────────────────────

  Future<List<TrendBar>> _naverDaily(String symbol, int days) async {
    final response = await _dio.get(
      'https://fchart.stock.naver.com/sise.nhn',
      queryParameters: {
        'symbol': symbol,
        'timeframe': 'day',
        // count는 영업일 기준 — 달력일로 넉넉히 요청한다.
        'count': days.clamp(30, 3000),
        'requestType': '0',
      },
      options: Options(
        responseType: ResponseType.plain,
        headers: {'User-Agent': _browserUa},
      ),
    );

    final bars = <TrendBar>[];
    for (final line in (response.data as String).split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('<')) continue;
      final parts = trimmed.split('|');
      if (parts.length < 5) continue;

      final dateStr = parts[0].trim();
      if (dateStr.length != 8) continue;
      final year = int.tryParse(dateStr.substring(0, 4));
      final month = int.tryParse(dateStr.substring(4, 6));
      final day = int.tryParse(dateStr.substring(6, 8));
      final close = double.tryParse(parts[4].trim());
      if (year == null || month == null || day == null) continue;
      if (close == null || close <= 0) continue;

      bars.add(TrendBar(date: DateTime(year, month, day), close: close));
    }
    bars.sort((a, b) => a.date.compareTo(b.date));
    return bars;
  }

  // ── 암호화폐 ────────────────────────────────────────────────────────────────

  /// CoinGecko 공개 API는 최근 365일까지만 준다. 그보다 긴 구간은 Yahoo의
  /// {티커}-USD 시세를 받아 일별 환율로 원화 환산한다.
  Future<List<TrendBar>> _cryptoDaily(
      String coinId, DateTime from, DateTime to, int days) async {
    if (days > 365) {
      final ticker = await _coinTicker(coinId);
      if (ticker != null) {
        final usdBars = await _yahooDaily('$ticker-USD', from, to);
        if (usdBars.length > 365) {
          return _toKrw(usdBars, await fetchFxHistory('USD', from));
        }
      }
    }

    final response = await _dio.get(
      'https://api.coingecko.com/api/v3/coins/$coinId/market_chart',
      queryParameters: {
        'vs_currency': 'krw',
        'days': days.clamp(1, 365),
        'interval': 'daily',
      },
    );

    final prices = response.data?['prices'] as List?;
    if (prices == null) return const [];
    final bars = <TrendBar>[];
    for (final entry in prices) {
      if (entry is! List || entry.length < 2) continue;
      final value = (entry[1] as num).toDouble();
      if (value <= 0) continue;
      bars.add(TrendBar(
        date: _dayKey(
            DateTime.fromMillisecondsSinceEpoch((entry[0] as num).toInt())),
        close: value,
      ));
    }
    bars.sort((a, b) => a.date.compareTo(b.date));
    return bars;
  }

  /// 자산에는 CoinGecko id('bitcoin')가 저장돼 있는데, Yahoo는 티커('BTC')를
  /// 요구한다.
  Future<String?> _coinTicker(String coinId) async {
    try {
      final response = await _dio.get(
        'https://api.coingecko.com/api/v3/coins/$coinId',
        queryParameters: {
          'localization': 'false',
          'tickers': 'false',
          'market_data': 'false',
          'community_data': 'false',
          'developer_data': 'false',
          'sparkline': 'false',
        },
      );
      final symbol = response.data?['symbol']?.toString();
      return (symbol == null || symbol.isEmpty) ? null : symbol.toUpperCase();
    } catch (_) {
      return null;
    }
  }

  List<TrendBar> _toKrw(List<TrendBar> usdBars, List<TrendBar> fxBars) {
    if (fxBars.isEmpty) return const [];
    final out = <TrendBar>[];
    int cursor = 0;
    var rate = fxBars.first.close;
    for (final bar in usdBars) {
      while (cursor < fxBars.length && !fxBars[cursor].date.isAfter(bar.date)) {
        rate = fxBars[cursor].close;
        cursor++;
      }
      out.add(TrendBar(date: bar.date, close: bar.close * rate));
    }
    return out;
  }

  // ── 네이버 금속 시세 (국내 금 현물) ─────────────────────────────────────────

  /// pageSize 상한이 60이라 [start]에 닿을 때까지 페이지를 뒤로 넘긴다.
  Future<List<TrendBar>> _naverMetalDaily(
    String reutersCode,
    DateTime start, {
    int maxPages = 40,
  }) async {
    final out = <TrendBar>[];

    for (int page = 1; page <= maxPages; page++) {
      List<dynamic>? list;
      try {
        final response = await _dio.get(
          'https://api.stock.naver.com/marketindex/metals/$reutersCode/prices',
          queryParameters: {'page': page, 'pageSize': 60},
          options: Options(
            headers: {
              'User-Agent': _mobileUa,
              'Referer': 'https://m.stock.naver.com/',
            },
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
        final data = response.data;
        list = data is List ? data : null;
      } catch (_) {
        break;
      }
      if (list == null || list.isEmpty) break;

      DateTime? oldest;
      for (final entry in list) {
        if (entry is! Map) continue;
        final raw = entry['localTradedAt']?.toString();
        final closeRaw = entry['closePrice']?.toString().replaceAll(',', '');
        final close = double.tryParse(closeRaw ?? '');
        if (raw == null || close == null || close <= 0) continue;
        final parsed = DateTime.tryParse(raw);
        if (parsed == null) continue;
        final day = _dayKey(parsed);
        out.add(TrendBar(date: day, close: close));
        if (oldest == null || day.isBefore(oldest)) oldest = day;
      }

      // 짧은 페이지 = 자료 끝, start에 닿았으면 충분.
      if (list.length < 60) break;
      if (oldest != null && !oldest.isAfter(start)) break;
    }

    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }
}
