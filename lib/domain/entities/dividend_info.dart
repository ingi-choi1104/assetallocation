/// Single historical dividend payment record from Yahoo Finance.
class DividendEvent {
  final DateTime date;
  final double amountPerShare;

  const DividendEvent({required this.date, required this.amountPerShare});
}

enum DividendFrequency { monthly, quarterly, semiAnnual, annual }

extension DividendFrequencyExt on DividendFrequency {
  int get paymentsPerYear {
    switch (this) {
      case DividendFrequency.monthly:    return 12;
      case DividendFrequency.quarterly:  return 4;
      case DividendFrequency.semiAnnual: return 2;
      case DividendFrequency.annual:     return 1;
    }
  }

  String get label {
    switch (this) {
      case DividendFrequency.monthly:    return '월배당';
      case DividendFrequency.quarterly:  return '분기배당';
      case DividendFrequency.semiAnnual: return '반기배당';
      case DividendFrequency.annual:     return '연배당';
    }
  }
}

/// Per-asset contribution to a single month's dividend.
class DividendEntry {
  final int assetId;
  final String symbol;
  final String name;
  final double amountKrw;
  final bool isKrStock;

  const DividendEntry({
    required this.assetId,
    required this.symbol,
    required this.name,
    required this.amountKrw,
    this.isKrStock = false,
  });
}

/// Expected dividend total for one calendar month.
class MonthlyDividend {
  final int year;
  final int month;
  final double totalKrw;
  final List<DividendEntry> entries;

  const MonthlyDividend({
    required this.year,
    required this.month,
    required this.totalKrw,
    required this.entries,
  });
}
