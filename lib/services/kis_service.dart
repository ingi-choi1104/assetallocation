import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KisHolding {
  final String stockName;
  final String stockCode;
  final double quantity;
  final double avgPurchasePrice;
  final double currentPrice;
  final double evaluationAmount;

  KisHolding({
    required this.stockName,
    required this.stockCode,
    required this.quantity,
    required this.avgPurchasePrice,
    required this.currentPrice,
    required this.evaluationAmount,
  });
}

class KisService {
  static const _baseUrl = 'https://openapi.koreainvestment.com:9443';
  static const _keyAppKey = 'kis_app_key';
  static const _keyAppSecret = 'kis_app_secret';

  final String appKey;
  final String appSecret;

  KisService({required this.appKey, required this.appSecret});

  final Dio _dio = Dio();
  String? _accessToken;
  DateTime? _tokenExpiry;

  static Future<({String appKey, String appSecret})> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      appKey: prefs.getString(_keyAppKey) ?? '',
      appSecret: prefs.getString(_keyAppSecret) ?? '',
    );
  }

  static Future<void> saveCredentials(
      {required String appKey, required String appSecret}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppKey, appKey);
    await prefs.setString(_keyAppSecret, appSecret);
  }

  Future<String> _getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }
    final resp = await _dio.post(
      '$_baseUrl/oauth2/tokenP',
      data: {
        'grant_type': 'client_credentials',
        'appkey': appKey,
        'appsecret': appSecret,
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['access_token'] == null) {
      throw Exception('토큰 발급 실패: ${data['error_description'] ?? data}');
    }
    _accessToken = data['access_token'] as String;
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 86400;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
    return _accessToken!;
  }

  /// [cano] : 계좌번호 앞 8자리
  /// [acntPrdtCd] : 계좌상품코드 뒤 2자리 (기본 "01")
  Future<List<KisHolding>> getHoldings({
    required String cano,
    String acntPrdtCd = '01',
  }) async {
    final cleanCano = cano.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanCano.length != 8) {
      throw Exception('계좌번호 앞자리는 8자리여야 합니다 (입력: ${cleanCano.length}자리)');
    }

    print('[KIS] CANO=$cleanCano, ACNT_PRDT_CD=$acntPrdtCd');

    final token = await _getAccessToken();
    final List<KisHolding> result = [];
    String ctxFk = '';

    do {
      final resp = await _dio.get(
        '$_baseUrl/uapi/domestic-stock/v1/trading/inquire-balance',
        queryParameters: {
          'CANO': cleanCano,
          'ACNT_PRDT_CD': acntPrdtCd,
          'AFHR_FLPR_YN': 'N',
          'OFL_YN': '',
          'INQR_DVSN': '02',
          'UNPR_DVSN': '01',
          'FUND_STTL_ICLD_YN': 'N',
          'FNCG_AMT_AUTO_RDPT_YN': 'N',
          'PRCS_DVSN': '01',
          'CTX_AREA_FK100': ctxFk,
          'CTX_AREA_NK100': '',
        },
        options: Options(headers: {
          'authorization': 'Bearer $token',
          'appkey': appKey,
          'appsecret': appSecret,
          'tr_id': 'TTTC8434R',
          'custtype': 'P',
          'Content-Type': 'application/json',
        }),
      );

      final data = resp.data as Map<String, dynamic>;
      if ((data['rt_cd'] as String? ?? '') != '0') {
        throw Exception('잔고 조회 실패: ${data['msg1']} (${data['msg_cd']})');
      }

      for (final item in (data['output1'] as List<dynamic>? ?? [])) {
        final m = item as Map<String, dynamic>;
        final qty = double.tryParse(m['hldg_qty'] ?? '0') ?? 0;
        if (qty <= 0) continue;
        result.add(KisHolding(
          stockName: m['prdt_name'] as String? ?? '',
          stockCode: m['pdno'] as String? ?? '',
          quantity: qty,
          avgPurchasePrice:
              double.tryParse(m['pchs_avg_pric'] ?? '0') ?? 0,
          currentPrice: double.tryParse(m['prpr'] ?? '0') ?? 0,
          evaluationAmount: double.tryParse(m['evlu_amt'] ?? '0') ?? 0,
        ));
      }

      final trCont = resp.headers.value('tr_cont') ?? '';
      ctxFk = (trCont == 'M' || trCont == 'F')
          ? (data['ctx_area_fk100'] as String? ?? '')
          : '';
    } while (ctxFk.trim().isNotEmpty);

    return result;
  }
}

// kisServiceProvider는 화면에서 직접 생성하므로 제거
