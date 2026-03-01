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

  /// Fetches current price only
  Future<PriceQuote?> fetchCurrentPrice(String symbol) async {
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
