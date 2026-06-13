import 'package:dio/dio.dart';
import '../../models/price_quote.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/dividend_info.dart';

class YahooFinanceDataSource {
  final Dio _dio;

  YahooFinanceDataSource(this._dio);

  Future<PriceQuote?> fetchCurrentPrice(String symbol) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.yahooChart(symbol),
        queryParameters: {
          'interval': '1d',
          'range': '1d',
        },
      );
      return _parseQuote(symbol, response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw const RateLimitException('Yahoo Finance');
      }
      throw NetworkException('Yahoo Finance 요청 실패: ${e.message}');
    }
  }

  /// Fetch daily price history between [startDate] and [endDate] using
  /// precise Unix timestamps (period1/period2). Returns null on failure.
  Future<List<HistoricalBar>?> fetchDailyHistory(
    String symbol,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final period1 = startDate.millisecondsSinceEpoch ~/ 1000;
      final period2 = endDate.millisecondsSinceEpoch ~/ 1000;

      final response = await _dio.get(
        'https://query2.finance.yahoo.com/v8/finance/chart/$symbol',
        queryParameters: {
          'interval': '1d',
          'period1': period1,
          'period2': period2,
        },
      );
      return _parseBarsFromResult(response.data);
    } catch (_) {
      return null;
    }
  }

  List<HistoricalBar>? _parseBarsFromResult(dynamic data) {
    try {
      final result = data['chart']['result'] as List?;
      if (result == null || result.isEmpty) return null;
      final item = result[0];
      final timestamps = (item['timestamp'] as List?)
          ?.map((t) => DateTime.fromMillisecondsSinceEpoch((t as int) * 1000))
          .toList();
      final closes = (item['indicators']?['quote']?[0]?['close'] as List?)
          ?.map((c) => c != null ? (c as num).toDouble() : null)
          .toList();
      if (timestamps == null || closes == null) return null;
      final bars = <HistoricalBar>[];
      for (int i = 0; i < timestamps.length; i++) {
        final close = i < closes.length ? closes[i] : null;
        if (close != null && close > 0) {
          bars.add(HistoricalBar(date: timestamps[i], close: close));
        }
      }
      bars.sort((a, b) => a.date.compareTo(b.date));
      return bars.isEmpty ? null : bars;
    } catch (_) {
      return null;
    }
  }

  Future<PriceQuote?> fetchHistory(
    String symbol, {
    int days = 365,
  }) async {
    try {
      final range = days <= 30
          ? '1mo'
          : days <= 90
              ? '3mo'
              : days <= 180
                  ? '6mo'
                  : days <= 365
                      ? '1y'
                      : '2y';

      final response = await _dio.get(
        ApiEndpoints.yahooChart(symbol),
        queryParameters: {
          'interval': '1d',
          'range': range,
        },
      );
      return _parseQuoteWithHistory(symbol, response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw const RateLimitException('Yahoo Finance');
      }
      throw NetworkException('Yahoo Finance 요청 실패: ${e.message}');
    }
  }

  PriceQuote? _parseQuote(String symbol, dynamic data) {
    try {
      final result = data['chart']['result'] as List?;
      if (result == null || result.isEmpty) return null;

      final item = result[0];
      final meta = item['meta'] as Map<String, dynamic>;
      final price = (meta['regularMarketPrice'] as num).toDouble();
      final currency = meta['currency'] as String? ?? 'USD';
      final prevClose = (meta['chartPreviousClose'] as num?)?.toDouble() ??
          (meta['previousClose'] as num?)?.toDouble();

      return PriceQuote(
        symbol: symbol,
        price: price,
        previousClose: prevClose,
        currency: currency,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw ParseException('Yahoo Finance 데이터 파싱 실패: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchSymbols(String query) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.yahooFinanceSearch,
        queryParameters: {
          'q': query,
          'quotesCount': 15,
          'newsCount': 0,
          'listsCount': 0,
          'enableFuzzyQuery': false,
        },
      );
      final quotes = response.data['quotes'] as List? ?? [];
      return quotes.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw const RateLimitException('Yahoo Finance');
      }
      throw NetworkException('Yahoo Finance 검색 실패: ${e.message}');
    }
  }

  /// Fetches up to 3 years of dividend events for [symbol].
  /// Returns empty list if no dividends or on error.
  Future<List<DividendEvent>> fetchDividendHistory(String symbol) async {
    try {
      final response = await _dio.get(
        'https://query2.finance.yahoo.com/v8/finance/chart/$symbol',
        queryParameters: {
          'interval': '1mo',
          'range': '3y',
          'events': 'dividends',
        },
      );
      return _parseDividendEvents(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw const RateLimitException('Yahoo Finance');
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  List<DividendEvent> _parseDividendEvents(dynamic data) {
    try {
      final result = data['chart']['result'] as List?;
      if (result == null || result.isEmpty) return [];
      final dividends =
          result[0]['events']?['dividends'] as Map<String, dynamic>?;
      if (dividends == null) return [];
      final events = dividends.values.map((e) {
        final ts = (e['date'] as num).toInt();
        final amt = (e['amount'] as num).toDouble();
        return DividendEvent(
          date: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
          amountPerShare: amt,
        );
      }).toList();
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    } catch (_) {
      return [];
    }
  }

  PriceQuote? _parseQuoteWithHistory(String symbol, dynamic data) {
    try {
      final result = data['chart']['result'] as List?;
      if (result == null || result.isEmpty) return null;

      final item = result[0];
      final meta = item['meta'] as Map<String, dynamic>;
      final price = (meta['regularMarketPrice'] as num).toDouble();
      final currency = meta['currency'] as String? ?? 'USD';

      final timestamps = (item['timestamp'] as List?)
          ?.map((t) => DateTime.fromMillisecondsSinceEpoch((t as int) * 1000))
          .toList();
      final closes = (item['indicators']?['quote']?[0]?['close'] as List?)
          ?.map((c) => c != null ? (c as num).toDouble() : null)
          .toList();

      final history = <HistoricalBar>[];
      if (timestamps != null && closes != null) {
        for (int i = 0; i < timestamps.length; i++) {
          final close = i < closes.length ? closes[i] : null;
          if (close != null) {
            history.add(HistoricalBar(date: timestamps[i], close: close));
          }
        }
      }

      return PriceQuote(
        symbol: symbol,
        price: price,
        currency: currency,
        timestamp: DateTime.now(),
        history: history.isEmpty ? null : history,
      );
    } catch (e) {
      throw ParseException('Yahoo Finance 히스토리 파싱 실패: $e');
    }
  }
}
