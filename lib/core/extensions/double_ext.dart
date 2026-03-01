extension DoubleExt on double {
  /// Returns sign-aware string with + prefix for positives
  String toSignedString({int decimals = 2}) {
    final formatted = toStringAsFixed(decimals);
    return this >= 0 ? '+$formatted' : formatted;
  }

  /// Percentage string
  String toPercentString({int decimals = 2}) =>
      '${toStringAsFixed(decimals)}%';

  /// Signed percentage string
  String toSignedPercentString({int decimals = 2}) =>
      '${toSignedString(decimals: decimals)}%';

  bool get isPositive => this > 0;
  bool get isNegative => this < 0;
}
