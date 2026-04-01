import 'package:dio/dio.dart';
import '../../../domain/entities/dynamic_allocation.dart';

/// Fetches monthly OHLCV data from Yahoo Finance for dynamic allocation strategies.
/// Returns a map of symbol → list of [MonthlyBar] sorted ascending by date.
class DynamicPriceDataSource {
  final Dio _dio;

  DynamicPriceDataSource(this._dio);

  /// Fetch [months] months of monthly price data for all [symbols],
  /// ending at [endDate].  Results are returned sorted ascending by date.
  ///
  /// Fetches with throttled concurrency (max 4 parallel) to avoid
  /// flooding network/memory and keep the UI responsive.
  Future<Map<String, List<MonthlyBar>>> fetchMonthlyPrices(
    List<String> symbols,
    DateTime endDate, {
    int months = 15,
  }) async {
    // Remove duplicates while preserving order
    final unique = symbols.toSet().toList();

    // Throttled parallel fetch — max 4 at a time
    final map = <String, List<MonthlyBar>>{};
    for (int i = 0; i < unique.length; i += 4) {
      final chunk = unique.skip(i).take(4).toList();
      final results = await Future.wait(
        chunk.map((s) => _fetchSymbol(s, endDate, months)),
      );
      for (int j = 0; j < chunk.length; j++) {
        if (results[j] != null && results[j]!.isNotEmpty) {
          map[chunk[j]] = results[j]!;
        }
      }
    }
    return map;
  }

  Future<List<MonthlyBar>?> _fetchSymbol(
    String symbol,
    DateTime endDate,
    int months,
  ) async {
    try {
      final period2 = endDate.millisecondsSinceEpoch ~/ 1000;
      final startDate = _subtractMonths(endDate, months);
      final period1 = startDate.millisecondsSinceEpoch ~/ 1000;

      final response = await _dio.get(
        'https://query2.finance.yahoo.com/v8/finance/chart/$symbol',
        queryParameters: {
          'interval': '1mo',
          'period1': period1,
          'period2': period2,
        },
      );

      return _parseBars(response.data);
    } on DioException {
      return null; // silently fail – strategy service handles nulls
    } catch (_) {
      return null;
    }
  }

  List<MonthlyBar>? _parseBars(dynamic data) {
    try {
      final result = data['chart']['result'] as List?;
      if (result == null || result.isEmpty) return null;

      final item = result[0];
      final timestamps = (item['timestamp'] as List?)
          ?.map((t) => DateTime.fromMillisecondsSinceEpoch((t as int) * 1000, isUtc: true))
          .toList();
      final closes = (item['indicators']?['quote']?[0]?['close'] as List?)
          ?.map((c) => c != null ? (c as num).toDouble() : null)
          .toList();

      if (timestamps == null || closes == null) return null;

      final bars = <MonthlyBar>[];
      for (int i = 0; i < timestamps.length; i++) {
        final price = i < closes.length ? closes[i] : null;
        if (price != null && price > 0) {
          bars.add(MonthlyBar(date: timestamps[i], price: price));
        }
      }
      // Ensure ascending order
      bars.sort((a, b) => a.date.compareTo(b.date));
      return bars.isEmpty ? null : bars;
    } catch (_) {
      return null;
    }
  }

  /// Subtract [months] from [date], handling month underflow correctly.
  DateTime _subtractMonths(DateTime date, int months) {
    int totalMonths = date.year * 12 + (date.month - 1) - months;
    final year = totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    return DateTime(year, month, 1);
  }
}
