import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/price_quote.dart';
import '../../../core/errors/app_exception.dart';

class NaverFinanceDataSource {
  final Dio _dio;

  NaverFinanceDataSource(this._dio);

  /// Fetches price history using fchart pipe-delimited endpoint
  Future<PriceQuote?> fetchHistory(
    String symbol, {
    int count = 365,
  }) async {
    try {
      final response = await _dio.get(
        'https://fchart.stock.naver.com/sise.nhn',
        queryParameters: {
          'symbol': symbol,
          'timeframe': 'day',
          'count': count,
          'requestType': '0',
        },
        options: Options(responseType: ResponseType.plain),
      );

      return _parseFchartResponse(symbol, response.data as String);
    } on DioException catch (e) {
      throw NetworkException('Naver Finance 요청 실패: ${e.message}');
    }
  }

  /// Searches Korean stocks/ETFs by name or code via Naver autocomplete API.
  /// Returns list of {symbol, name} maps using 6-digit KRX codes.
  Future<List<Map<String, String>>> searchByName(String query) async {
    try {
      // target 파라미터를 URL에 직접 포함 — Dio의 쉼표 인코딩(%2C) 우회
      final encodedQ = Uri.encodeQueryComponent(query);
      final response = await _dio.get(
        'https://ac.stock.naver.com/ac?target=stock,etf&q=$encodedQ',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': 'application/json, */*'},
        ),
      );

      // Dio가 plain text로 반환할 수 있으므로 직접 decode
      final raw = response.data;
      dynamic data;
      if (raw is String) {
        data = jsonDecode(raw);
      } else {
        data = raw;
      }

      if (data is! Map) return [];
      final items = data['items'] as List? ?? [];

      final results = <Map<String, String>>[];
      for (final item in items) {
        String name = '';
        String symbol = '';

        if (item is List && item.length >= 2) {
          // 형식: ["삼성전자", "005930", "KOSPI", "KS"]
          name = item[0]?.toString() ?? '';
          symbol = item[1]?.toString() ?? '';
        } else if (item is Map) {
          // 혹시 Map 형식으로 올 경우 대비
          name = (item['name'] ?? item['itemName'] ?? '').toString();
          symbol = (item['code'] ?? item['itemCode'] ?? '').toString();
        }

        if (symbol.isEmpty) continue;
        results.add({'symbol': symbol, 'name': name});
      }
      return results;
    } catch (e) {
      throw NetworkException('Naver 검색 실패: $e');
    }
  }

  /// Fetches a spot metal price from Naver's market-index API.
  /// Domestic gold `M04020000` is quoted in KRW/gram; international metals
  /// (e.g. `GCcv1`) in USD/oz. Returns null on failure.
  Future<PriceQuote?> fetchMetalPrice(String reutersCode) async {
    try {
      final response = await _dio.get(
        'https://api.stock.naver.com/marketindex/metals/$reutersCode',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36',
            'Referer': 'https://m.stock.naver.com/',
          },
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      final data = response.data;
      if (data == null || data is! Map) return null;

      final price = _parseKrNum(data['closePrice']);
      if (price == null || price == 0) return null;

      // previousClose: fluctuations is the absolute change; direction comes
      // from fluctuationsType (RISING / FALLING).
      double? previousClose;
      final change = _parseKrNum(data['fluctuations']);
      if (change != null) {
        final type = data['fluctuationsType'];
        final dir = (type is Map) ? (type['name']?.toString() ?? '') : '';
        final signed = dir == 'FALLING' ? -change : change;
        previousClose = price - signed;
      }

      // 국내 금은 '원/g'(KRW/gram), 국제 금속은 'USD/OZS' 등. '/g' 또는 '원'이면 원화.
      final unit = data['unit']?.toString() ?? '';
      final currency =
          (unit.contains('원') || unit.contains('/g')) ? 'KRW' : 'USD';

      return PriceQuote(
        symbol: reutersCode,
        price: price,
        previousClose: previousClose,
        currency: currency,
        timestamp: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  double? _parseKrNum(dynamic v) =>
      v == null ? null : double.tryParse(v.toString().replaceAll(',', ''));

  /// Fetches current price: tries real-time mobile API first, falls back to daily close.
  Future<PriceQuote?> fetchCurrentPrice(String symbol) async {
    // 1) 실시간 현재가 (장 중 반영)
    final realtime = await _fetchRealtimePrice(symbol);
    if (realtime != null) return realtime;

    // 2) fallback: 일봉 종가 (장 마감 후 또는 API 실패 시)
    final result = await fetchHistory(symbol, count: 5);
    if (result?.history == null || result!.history!.isEmpty) return null;

    final bars = result.history!;
    final lastBar = bars.last;
    final prevClose = bars.length >= 2 ? bars[bars.length - 2].close : null;
    return PriceQuote(
      symbol: symbol,
      price: lastBar.close,
      previousClose: prevClose,
      currency: 'KRW',
      timestamp: lastBar.date,
    );
  }

  /// Naver mobile API — returns intraday real-time price during trading hours.
  Future<PriceQuote?> _fetchRealtimePrice(String symbol) async {
    try {
      final response = await _dio.get(
        'https://m.stock.naver.com/api/stock/$symbol/basic',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36',
            'Referer': 'https://m.stock.naver.com/',
          },
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      final data = response.data;
      if (data == null || data is! Map) return null;

      // closePrice = 현재가 (장 중) 또는 당일 종가
      final closePriceRaw = data['closePrice']?.toString().replaceAll(',', '');
      final changeRaw = data['compareToPreviousClosePrice']
          ?.toString()
          .replaceAll(',', '');

      final price = double.tryParse(closePriceRaw ?? '');
      if (price == null || price == 0) return null;

      final change = double.tryParse(changeRaw ?? '');
      final previousClose = change != null ? price - change : null;

      return PriceQuote(
        symbol: symbol,
        price: price,
        previousClose: previousClose,
        currency: 'KRW',
        timestamp: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  PriceQuote? _parseFchartResponse(String symbol, String raw) {
    try {
      final lines = raw
          .split('\n')
          .where((l) => l.trim().isNotEmpty && !l.startsWith('<'))
          .toList();

      if (lines.isEmpty) return null;

      final history = <HistoricalBar>[];
      for (final line in lines) {
        final parts = line.split('|');
        if (parts.length < 5) continue;

        final dateStr = parts[0].trim();
        if (dateStr.length != 8) continue;

        final year = int.tryParse(dateStr.substring(0, 4));
        final month = int.tryParse(dateStr.substring(4, 6));
        final day = int.tryParse(dateStr.substring(6, 8));
        final close = double.tryParse(parts[4].trim());

        if (year == null ||
            month == null ||
            day == null ||
            close == null ||
            close == 0) {
          continue;
        }

        history.add(HistoricalBar(
          date: DateTime(year, month, day),
          close: close,
        ));
      }

      if (history.isEmpty) return null;

      return PriceQuote(
        symbol: symbol,
        price: history.last.close,
        currency: 'KRW',
        timestamp: history.last.date,
        history: history,
      );
    } catch (e) {
      throw ParseException('Naver Finance 데이터 파싱 실패: $e');
    }
  }
}
