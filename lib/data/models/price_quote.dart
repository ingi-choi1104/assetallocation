class PriceQuote {
  final String symbol;
  final double price;
  final double? previousClose;
  final String currency;
  final DateTime timestamp;
  final List<HistoricalBar>? history;

  const PriceQuote({
    required this.symbol,
    required this.price,
    this.previousClose,
    required this.currency,
    required this.timestamp,
    this.history,
  });
}

class HistoricalBar {
  final DateTime date;
  final double close;

  const HistoricalBar({required this.date, required this.close});
}
