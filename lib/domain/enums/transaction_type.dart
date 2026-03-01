enum TransactionType {
  buy('buy', '매수'),
  sell('sell', '매도');

  final String value;
  final String label;

  const TransactionType(this.value, this.label);

  static TransactionType fromValue(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TransactionType.buy,
    );
  }
}
