import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _krwFormat = NumberFormat('#,##0', 'ko_KR');
  static final NumberFormat _usdFormat =
      NumberFormat('#,##0.00', 'en_US');
  static String formatKrw(double amount) {
    return '₩${_krwFormat.format(amount)}';
  }

  static String formatUsd(double amount) {
    return '\$${_usdFormat.format(amount)}';
  }

  static String format(double amount, String currency) {
    switch (currency.toUpperCase()) {
      case 'KRW':
        return formatKrw(amount);
      case 'USD':
        return formatUsd(amount);
      default:
        return '${_usdFormat.format(amount)} $currency';
    }
  }

  static String formatCompact(double amount, String currency) {
    return format(amount, currency);
  }

  static String formatPercent(double value, {int decimals = 2}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  static String formatSignedPercent(double value, {int decimals = 2}) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(decimals)}%';
  }
}
