import 'dart:async';
import 'package:dio/dio.dart';
import '../../models/coin_price.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exception.dart';

class CoinGeckoDataSource {
  final Dio _dio;
  static const Duration _requestDelay = Duration(milliseconds: 1200);

  CoinGeckoDataSource(this._dio);

  Future<CoinPrice?> fetchCurrentPrice(String coinId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.coinGeckoSimplePrice,
        queryParameters: {
          'ids': coinId,
          'vs_currencies': 'krw,usd',
          'include_24hr_change': 'true',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final coinData = data[coinId] as Map<String, dynamic>?;
      if (coinData == null) return null;

      return CoinPrice(
        coinId: coinId,
        priceKrw: (coinData['krw'] as num).toDouble(),
        priceUsd: coinData['usd'] != null
            ? (coinData['usd'] as num).toDouble()
            : null,
        changePercent24h: (coinData['krw_24h_change'] as num?)?.toDouble(),
        timestamp: DateTime.now(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw const RateLimitException('CoinGecko');
      }
      throw NetworkException('CoinGecko 요청 실패: ${e.message}');
    }
  }

  Future<CoinPrice?> fetchHistory(
    String coinId, {
    int days = 365,
  }) async {
    try {
      await Future.delayed(_requestDelay);

      final response = await _dio.get(
        ApiEndpoints.coinGeckoMarketChart(coinId),
        queryParameters: {
          'vs_currency': 'krw',
          'days': days,
          'interval': 'daily',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final prices = data['prices'] as List?;
      if (prices == null) return null;

      final history = prices
          .map((p) {
            final entry = p as List;
            return CoinHistoryBar(
              date: DateTime.fromMillisecondsSinceEpoch(
                  (entry[0] as num).toInt()),
              priceKrw: (entry[1] as num).toDouble(),
            );
          })
          .toList();

      final currentPrice = history.isNotEmpty ? history.last.priceKrw : 0.0;

      return CoinPrice(
        coinId: coinId,
        priceKrw: currentPrice,
        timestamp: DateTime.now(),
        history: history,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        await _exponentialBackoff();
        throw const RateLimitException('CoinGecko');
      }
      throw NetworkException('CoinGecko 히스토리 요청 실패: ${e.message}');
    }
  }

  Future<void> _exponentialBackoff() async {
    await Future.delayed(const Duration(seconds: 10));
  }

  Future<List<Map<String, dynamic>>> searchCoins(String query) async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.coinGeckoBase}/search',
        queryParameters: {'query': query},
      );

      final results = response.data['coins'] as List? ?? [];
      return results.cast<Map<String, dynamic>>().take(10).toList();
    } on DioException catch (e) {
      throw NetworkException('CoinGecko 검색 실패: ${e.message}');
    }
  }
}
