class Investment {
  final int id;
  final int portfolioId;
  final double amount; // KRW
  final DateTime investmentDate;
  final String? memo;
  final DateTime createdAt;

  const Investment({
    required this.id,
    required this.portfolioId,
    required this.amount,
    required this.investmentDate,
    this.memo,
    required this.createdAt,
  });
}
