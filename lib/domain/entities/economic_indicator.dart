enum IndicatorCategory { exchangeRate, commodity, stockIndex }

/// Market timezone identifier — used to determine if a session has opened today.
enum IndicatorMarket {
  /// 한국/일본 (KST/JST = UTC+9), 평일 09:00-15:30
  krx,
  /// 미국 동부 (ET = UTC-5 / UTC-4 DST), 평일 09:30-16:00
  us,
  /// 24시간 거래 (외환, 선물 등) — 항상 실제 변화율 표시
  global,
}

/// Returns true if [market] has already had a trading session open today
/// (in the market's local timezone). If false, today's change = 0%.
bool marketHasOpenedToday(IndicatorMarket market) {
  if (market == IndicatorMarket.global) return true;

  final now = DateTime.now().toUtc();

  if (market == IndicatorMarket.krx) {
    // KST = UTC+9, 장 시작 09:00
    final kst = now.add(const Duration(hours: 9));
    if (kst.weekday == DateTime.saturday || kst.weekday == DateTime.sunday) {
      return false;
    }
    return kst.hour >= 9;
  }

  if (market == IndicatorMarket.us) {
    // ET: 3월 둘째 일요일 ~ 11월 첫째 일요일 DST(UTC-4), 나머지 UTC-5
    final isDst = _isUsDst(now);
    final et = now.add(Duration(hours: isDst ? -4 : -5));
    if (et.weekday == DateTime.saturday || et.weekday == DateTime.sunday) {
      return false;
    }
    // 장 시작 09:30
    return et.hour > 9 || (et.hour == 9 && et.minute >= 30);
  }

  return true;
}

/// Rough US DST check: DST is active from 2nd Sunday of March to
/// 1st Sunday of November (clocks spring forward, UTC offset = -4).
bool _isUsDst(DateTime utc) {
  final year = utc.year;

  // 2nd Sunday of March
  DateTime march = DateTime.utc(year, 3, 1);
  int sunCount = 0;
  while (sunCount < 2) {
    if (march.weekday == DateTime.sunday) sunCount++;
    if (sunCount < 2) march = march.add(const Duration(days: 1));
  }
  final dstStart = march.add(const Duration(hours: 7)); // 02:00 ET = 07:00 UTC

  // 1st Sunday of November
  DateTime nov = DateTime.utc(year, 11, 1);
  while (nov.weekday != DateTime.sunday) {
    nov = nov.add(const Duration(days: 1));
  }
  final dstEnd = nov.add(const Duration(hours: 6)); // 02:00 ET = 06:00 UTC

  return utc.isAfter(dstStart) && utc.isBefore(dstEnd);
}

/// Static definition of a single economic indicator.
class IndicatorDef {
  final String symbol;      // Yahoo Finance symbol
  final String label;       // Display name (한국어)
  final IndicatorCategory category;
  final String unit;        // e.g., '원', 'USD', 'pt'
  /// Multiply fetched price by this before display (e.g., 100 for JPY/KRW).
  final double multiplier;
  final IndicatorMarket market;

  const IndicatorDef({
    required this.symbol,
    required this.label,
    required this.category,
    required this.unit,
    this.multiplier = 1.0,
    this.market = IndicatorMarket.global,
  });
}

/// Live data merged with a definition.
class EconomicIndicator {
  final IndicatorDef def;
  final double? price;
  final double? previousClose;

  const EconomicIndicator({
    required this.def,
    this.price,
    this.previousClose,
  });

  double? get displayPrice =>
      price != null ? price! * def.multiplier : null;

  double? get displayPreviousClose =>
      previousClose != null ? previousClose! * def.multiplier : null;

  double? get changePercent {
    final p = displayPrice;
    final pc = displayPreviousClose;
    if (p == null || pc == null || pc == 0) return null;
    // 오늘 장이 아직 열리지 않았으면 0% (당일 변화 없음)
    if (!marketHasOpenedToday(def.market)) return 0;
    return (p - pc) / pc * 100;
  }

  double? get changeAmount {
    final p = displayPrice;
    final pc = displayPreviousClose;
    if (p == null || pc == null) return null;
    if (!marketHasOpenedToday(def.market)) return 0;
    return p - pc;
  }

  bool get isPositive => (changePercent ?? 0) >= 0;

  EconomicIndicator copyWithPrices(double? price, double? previousClose) =>
      EconomicIndicator(def: def, price: price, previousClose: previousClose);
}

// ── Indicator definitions ─────────────────────────────────────────────────────

const _exchangeRates = <IndicatorDef>[
  IndicatorDef(symbol: 'USDKRW=X', label: '달러/원',   category: IndicatorCategory.exchangeRate, unit: '원'),
  IndicatorDef(symbol: 'EURKRW=X', label: '유로/원',   category: IndicatorCategory.exchangeRate, unit: '원'),
  IndicatorDef(symbol: 'JPYKRW=X', label: '엔/원(100)', category: IndicatorCategory.exchangeRate, unit: '원', multiplier: 100),
  IndicatorDef(symbol: 'CNYKRW=X', label: '위안/원',   category: IndicatorCategory.exchangeRate, unit: '원'),
  IndicatorDef(symbol: 'GBPKRW=X', label: '파운드/원', category: IndicatorCategory.exchangeRate, unit: '원'),
];

const _commodities = <IndicatorDef>[
  IndicatorDef(symbol: 'M04020000', label: '금',      category: IndicatorCategory.commodity, unit: '원/g'),
  IndicatorDef(symbol: 'SI=F',     label: '은',       category: IndicatorCategory.commodity, unit: '원/oz'),
  IndicatorDef(symbol: 'CL=F',     label: 'WTI유가',  category: IndicatorCategory.commodity, unit: 'USD/bbl'),
  IndicatorDef(symbol: 'BZ=F',     label: '두바이유', category: IndicatorCategory.commodity, unit: 'USD/bbl'),
  IndicatorDef(symbol: 'HG=F',     label: '구리',     category: IndicatorCategory.commodity, unit: 'USD/lb'),
];

const _stockIndices = <IndicatorDef>[
  IndicatorDef(symbol: '^KS11',  label: '코스피',   category: IndicatorCategory.stockIndex, unit: 'pt', market: IndicatorMarket.krx),
  IndicatorDef(symbol: '^KQ11',  label: '코스닥',   category: IndicatorCategory.stockIndex, unit: 'pt', market: IndicatorMarket.krx),
  IndicatorDef(symbol: '^GSPC',  label: 'S&P500',   category: IndicatorCategory.stockIndex, unit: 'pt', market: IndicatorMarket.us),
  IndicatorDef(symbol: '^IXIC',  label: '나스닥',   category: IndicatorCategory.stockIndex, unit: 'pt', market: IndicatorMarket.us),
  IndicatorDef(symbol: '^DJI',   label: '다우존스', category: IndicatorCategory.stockIndex, unit: 'pt', market: IndicatorMarket.us),
  IndicatorDef(symbol: '^N225',  label: '닛케이',   category: IndicatorCategory.stockIndex, unit: 'pt', market: IndicatorMarket.krx),
];

const allIndicatorDefs = <IndicatorDef>[
  ..._exchangeRates,
  ..._commodities,
  ..._stockIndices,
];
