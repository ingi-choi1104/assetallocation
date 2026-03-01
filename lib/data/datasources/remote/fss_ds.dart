import 'package:dio/dio.dart';
import '../../models/fund_nav.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exception.dart';

class FssDataSource {
  final Dio _dio;

  FssDataSource(this._dio);

  Future<FundNav?> fetchFundNav(String fundCode, String apiKey) async {
    if (apiKey.isEmpty) {
      throw const ApiKeyMissingException('FSS');
    }

    try {
      final response = await _dio.get(
        ApiEndpoints.fssFundNav,
        queryParameters: {
          'serviceKey': apiKey,
          'fundCd': fundCode,
          'pageNo': '1',
          'numOfRows': '1',
          'returnType': 'json',
        },
      );

      return _parseResponse(fundCode, response.data);
    } on DioException catch (e) {
      throw NetworkException('FSS API 요청 실패: ${e.message}');
    }
  }

  FundNav? _parseResponse(String fundCode, dynamic data) {
    try {
      final body = data['response']?['body'];
      if (body == null) return null;

      final items = body['items']?['item'];
      if (items == null) return null;

      final item = items is List ? items.first : items;
      final navStr = item['nav']?.toString() ?? item['basePrice']?.toString();
      final nav = double.tryParse(navStr ?? '');
      if (nav == null) return null;

      final fundName = item['fundNm']?.toString() ?? fundCode;
      final dateStr = item['standardDt']?.toString() ?? '';

      DateTime date;
      try {
        date = dateStr.length == 8
            ? DateTime(
                int.parse(dateStr.substring(0, 4)),
                int.parse(dateStr.substring(4, 6)),
                int.parse(dateStr.substring(6, 8)),
              )
            : DateTime.now();
      } catch (_) {
        date = DateTime.now();
      }

      return FundNav(
        fundCode: fundCode,
        fundName: fundName,
        nav: nav,
        date: date,
      );
    } catch (e) {
      throw ParseException('FSS 데이터 파싱 실패: $e');
    }
  }
}
