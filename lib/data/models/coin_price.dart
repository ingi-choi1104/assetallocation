class CoinPrice {
  final String coinId;
  final double priceKrw;
  final double? priceUsd;
  final double? changePercent24h;
  final DateTime timestamp;
  final List<CoinHistoryBar>? history;

  const CoinPrice({
    required this.coinId,
    required this.priceKrw,
    this.priceUsd,
    this.changePercent24h,
    required this.timestamp,
    this.history,
  });
}

class CoinHistoryBar {
  final DateTime date;
  final double priceKrw;

  const CoinHistoryBar({required this.date, required this.priceKrw});
}
