enum IndicatorCategory { exchangeRate, commodity, stockIndex }

/// Static definition of a single economic indicator.
class IndicatorDef {
  final String symbol;      // Yahoo Finance symbol
  final String label;       // Display name (한국어)
  final IndicatorCategory category;
  final String unit;        // e.g., '원', 'USD', 'pt'
  /// Multiply fetched price by this before display (e.g., 100 for JPY/KRW).
  final double multiplier;

  const IndicatorDef({
    required this.symbol,
    required this.label,
    required this.category,
    required this.unit,
    this.multiplier = 1.0,
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
    return (p - pc) / pc * 100;
  }

  double? get changeAmount {
    final p = displayPrice;
    final pc = displayPreviousClose;
    if (p == null || pc == null) return null;
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
  IndicatorDef(symbol: 'GC=F',     label: '금',       category: IndicatorCategory.commodity, unit: 'USD/oz'),
  IndicatorDef(symbol: 'SI=F',     label: '은',       category: IndicatorCategory.commodity, unit: 'USD/oz'),
  IndicatorDef(symbol: 'CL=F',     label: 'WTI유가',  category: IndicatorCategory.commodity, unit: 'USD/bbl'),
  IndicatorDef(symbol: 'BZ=F',     label: '두바이유', category: IndicatorCategory.commodity, unit: 'USD/bbl'),
  IndicatorDef(symbol: 'HG=F',     label: '구리',     category: IndicatorCategory.commodity, unit: 'USD/lb'),
];

const _stockIndices = <IndicatorDef>[
  IndicatorDef(symbol: '^KS11',  label: '코스피',   category: IndicatorCategory.stockIndex, unit: 'pt'),
  IndicatorDef(symbol: '^KQ11',  label: '코스닥',   category: IndicatorCategory.stockIndex, unit: 'pt'),
  IndicatorDef(symbol: '^GSPC',  label: 'S&P500',   category: IndicatorCategory.stockIndex, unit: 'pt'),
  IndicatorDef(symbol: '^IXIC',  label: '나스닥',   category: IndicatorCategory.stockIndex, unit: 'pt'),
  IndicatorDef(symbol: '^DJI',   label: '다우존스', category: IndicatorCategory.stockIndex, unit: 'pt'),
  IndicatorDef(symbol: '^N225',  label: '닛케이',   category: IndicatorCategory.stockIndex, unit: 'pt'),
];

const allIndicatorDefs = <IndicatorDef>[
  ..._exchangeRates,
  ..._commodities,
  ..._stockIndices,
];
