class ApiEndpoints {
  ApiEndpoints._();

  // Yahoo Finance
  static const String yahooFinanceBase =
      'https://query2.finance.yahoo.com/v8/finance/chart';
  // Pass symbol as-is — Yahoo Finance requires literal '=' in symbols like GC=F
  static String yahooChart(String symbol) => '$yahooFinanceBase/$symbol';
  static const String yahooFinanceSearch =
      'https://query1.finance.yahoo.com/v1/finance/search';

  // Naver Finance
  static const String naverFchartBase =
      'https://fchart.stock.naver.com/sise.nhn';
  static const String naverFinanceBase = 'https://finance.naver.com';

  // CoinGecko
  static const String coinGeckoBase = 'https://api.coingecko.com/api/v3';
  static const String coinGeckoSimplePrice = '$coinGeckoBase/simple/price';
  static String coinGeckoMarketChart(String coinId) =>
      '$coinGeckoBase/coins/$coinId/market_chart';

  // FSS (금융감독원)
  static const String fssBase = 'https://openapi.fss.or.kr/openapi/service';
  static const String fssFundNav =
      '$fssBase/MutualFundInfoService/getMutualFundPrvsList';

  // Exchange rate (Yahoo Finance)
  static const String usdKrwSymbol = 'USDKRW=X';
}
