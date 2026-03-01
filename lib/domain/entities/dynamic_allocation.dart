import 'dart:math';

// ═══════════════════════════════════════════════════════════════════════════════
// Dynamic Asset Allocation — Domain Models
// 6 Strategies: VAA, PAA, DAA, Dual Momentum, GTAA, FAA
// ═══════════════════════════════════════════════════════════════════════════════

enum DynamicStrategyType { vaa, paa, daa, dualMomentum, gtaa, faa }

extension DynamicStrategyTypeX on DynamicStrategyType {
  String get displayName => switch (this) {
        DynamicStrategyType.vaa => 'VAA',
        DynamicStrategyType.paa => 'PAA',
        DynamicStrategyType.daa => 'DAA',
        DynamicStrategyType.dualMomentum => '듀얼 모멘텀',
        DynamicStrategyType.gtaa => 'GTAA',
        DynamicStrategyType.faa => 'FAA',
      };

  String get fullName => switch (this) {
        DynamicStrategyType.vaa => 'Vigilant Asset Allocation',
        DynamicStrategyType.paa => 'Protective Asset Allocation',
        DynamicStrategyType.daa => 'Defensive Asset Allocation',
        DynamicStrategyType.dualMomentum => 'Dual Momentum (GEM)',
        DynamicStrategyType.gtaa => 'Global Tactical Asset Allocation',
        DynamicStrategyType.faa => 'Flexible Asset Allocation',
      };

  String get creator => switch (this) {
        DynamicStrategyType.vaa => 'Keller & Keuning (2017)',
        DynamicStrategyType.paa => 'Keller & Keuning (2016)',
        DynamicStrategyType.daa => 'Keller & Keuning (2018)',
        DynamicStrategyType.dualMomentum => 'Gary Antonacci',
        DynamicStrategyType.gtaa => 'Mebane Faber',
        DynamicStrategyType.faa => 'Keuning & Keller (2012)',
      };

  String get description => switch (this) {
        DynamicStrategyType.vaa =>
          '공격 자산 중 하나라도 모멘텀이 음수이면 즉시 방어 자산으로 전환하는 고위험회피 전략입니다. '
              '모멘텀 점수 = 12×1개월 + 4×3개월 + 2×6개월 + 12개월 수익률로 계산합니다.',
        DynamicStrategyType.paa =>
          '공격 자산 중 양의 모멘텀 개수(B)에 따라 주식 비중을 조절합니다. '
              '보호 비율 = (N-B)/N으로 안전 자산 비중을 결정합니다.',
        DynamicStrategyType.daa =>
          '카나리아 자산(VWO, BND)이 시장 위험 신호를 탐지하면 방어 모드로 전환합니다. '
              '카나리아가 정상이면 상위 공격 자산에 균등 투자합니다.',
        DynamicStrategyType.dualMomentum =>
          '절대 모멘텀(SPY vs 현금)으로 주식 여부를 결정하고, '
              '상대 모멘텀(미국 vs 해외)으로 어느 주식을 보유할지 결정합니다.',
        DynamicStrategyType.gtaa =>
          '5개 글로벌 자산을 동일 비중으로 보유하되, '
              '각 자산이 10개월 이동평균 아래이면 현금으로 대체합니다.',
        DynamicStrategyType.faa =>
          '모멘텀·변동성·상관관계 세 가지 지표를 순위화하여 합산 점수가 낮은 '
              '(= 더 우수한) 상위 3개 자산에 균등 투자합니다.',
      };

  String get keyRule => switch (this) {
        DynamicStrategyType.vaa => '모든 공격 자산 M>0 → 공격\n하나라도 M≤0 → 최고 방어 자산',
        DynamicStrategyType.paa => '보호비율=(N-B)/N → 안전자산\n나머지 → 상위 공격 자산',
        DynamicStrategyType.daa => '카나리아 이상 → 최고 방어 자산\n카나리아 정상 → 상위 3 공격 자산',
        DynamicStrategyType.dualMomentum => 'SPY 12m>0 → 주식(SPY vs 해외)\nSPY 12m≤0 → 채권(AGG)',
        DynamicStrategyType.gtaa => '가격 > SMA10 → 보유\n가격 ≤ SMA10 → 현금 대체',
        DynamicStrategyType.faa => '모멘텀+변동성+상관관계 순위 합산\n상위 3개(양의 모멘텀만) 균등 투자',
      };
}

// ─── Asset Role ───────────────────────────────────────────────────────────────

enum AssetRole { offensive, defensive, canary }

extension AssetRoleX on AssetRole {
  String get label => switch (this) {
        AssetRole.offensive => '공격',
        AssetRole.defensive => '방어',
        AssetRole.canary => '카나리아',
      };
}

// ─── Strategy Asset Configuration ────────────────────────────────────────────

class StrategyAssetConfig {
  final String symbol;
  final String name;
  final AssetRole role;

  const StrategyAssetConfig({
    required this.symbol,
    required this.name,
    required this.role,
  });
}

// ─── Full Strategy Configuration ─────────────────────────────────────────────

class DynamicStrategyConfig {
  final DynamicStrategyType strategyType;
  final List<StrategyAssetConfig> assets;
  final DateTime calculationDate;
  final int topN; // how many top offensive assets to hold

  const DynamicStrategyConfig({
    required this.strategyType,
    required this.assets,
    required this.calculationDate,
    this.topN = 1,
  });

  List<String> get symbols => assets.map((a) => a.symbol).toList();

  // ── Default configurations per strategy ──────────────────────────────────
  static DynamicStrategyConfig defaultFor(
    DynamicStrategyType type, {
    DateTime? date,
  }) {
    final now = date ?? DateTime.now();
    switch (type) {
      case DynamicStrategyType.vaa:
        return DynamicStrategyConfig(
          strategyType: type,
          calculationDate: now,
          topN: 1,
          assets: const [
            StrategyAssetConfig(symbol: 'SPY',  name: 'S&P 500 (SPY)',       role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'QQQ',  name: 'NASDAQ 100 (QQQ)',    role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'VEA',  name: '선진국주식 (VEA)',      role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'EEM',  name: '신흥국주식 (EEM)',      role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'SHY',  name: '단기채권 (SHY)',        role: AssetRole.defensive),
            StrategyAssetConfig(symbol: 'IEF',  name: '중기채권 (IEF)',        role: AssetRole.defensive),
            StrategyAssetConfig(symbol: 'LQD',  name: '투자등급채권 (LQD)',    role: AssetRole.defensive),
          ],
        );

      case DynamicStrategyType.paa:
        return DynamicStrategyConfig(
          strategyType: type,
          calculationDate: now,
          topN: 6,
          assets: const [
            StrategyAssetConfig(symbol: 'SPY',  name: 'S&P 500 (SPY)',       role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'QQQ',  name: 'NASDAQ 100 (QQQ)',    role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'IWM',  name: '소형주 (IWM)',          role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'VGK',  name: '유럽주식 (VGK)',        role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'EWJ',  name: '일본주식 (EWJ)',        role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'EEM',  name: '신흥국주식 (EEM)',      role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'VNQ',  name: '리츠 (VNQ)',           role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'DBC',  name: '원자재 (DBC)',          role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'GLD',  name: '금 (GLD)',             role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'TLT',  name: '장기채권 (TLT)',        role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'HYG',  name: '하이일드채권 (HYG)',    role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'AGG',  name: '종합채권 (AGG)',        role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'BIL',  name: '현금/T-Bill (BIL)',    role: AssetRole.defensive),
          ],
        );

      case DynamicStrategyType.daa:
        return DynamicStrategyConfig(
          strategyType: type,
          calculationDate: now,
          topN: 3,
          assets: const [
            StrategyAssetConfig(symbol: 'VWO',  name: '신흥국ETF (VWO)',      role: AssetRole.canary),
            StrategyAssetConfig(symbol: 'BND',  name: '종합채권 (BND)',        role: AssetRole.canary),
            StrategyAssetConfig(symbol: 'SPY',  name: 'S&P 500 (SPY)',       role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'VEA',  name: '선진국주식 (VEA)',      role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'EEM',  name: '신흥국주식 (EEM)',      role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'AGG',  name: '종합채권 (AGG)',        role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'LQD',  name: '투자등급채권 (LQD)',    role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'TLT',  name: '장기채권 (TLT)',        role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'DBC',  name: '원자재 (DBC)',          role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'SHY',  name: '단기채권 (SHY)',        role: AssetRole.defensive),
            StrategyAssetConfig(symbol: 'IEF',  name: '중기채권 (IEF)',        role: AssetRole.defensive),
            StrategyAssetConfig(symbol: 'BIL',  name: '현금/T-Bill (BIL)',    role: AssetRole.defensive),
          ],
        );

      case DynamicStrategyType.dualMomentum:
        return DynamicStrategyConfig(
          strategyType: type,
          calculationDate: now,
          topN: 1,
          assets: const [
            StrategyAssetConfig(symbol: 'SPY',  name: '미국주식 (SPY)',        role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'ACWX', name: '해외주식 (ACWX)',       role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'AGG',  name: '채권 (AGG)',            role: AssetRole.defensive),
          ],
        );

      case DynamicStrategyType.gtaa:
        return DynamicStrategyConfig(
          strategyType: type,
          calculationDate: now,
          topN: 5,
          assets: const [
            StrategyAssetConfig(symbol: 'SPY',  name: 'S&P 500 (SPY)',       role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'EFA',  name: '선진국주식 (EFA)',      role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'IEF',  name: '중기채권 (IEF)',        role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'GSG',  name: '원자재 (GSG)',          role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'VNQ',  name: '리츠 (VNQ)',           role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'BIL',  name: '현금/T-Bill (BIL)',    role: AssetRole.defensive),
          ],
        );

      case DynamicStrategyType.faa:
        return DynamicStrategyConfig(
          strategyType: type,
          calculationDate: now,
          topN: 3,
          assets: const [
            StrategyAssetConfig(symbol: 'SPY',  name: 'S&P 500 (SPY)',       role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'VEU',  name: '미국外 선진국 (VEU)',   role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'IEF',  name: '중기채권 (IEF)',        role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'VNQ',  name: '리츠 (VNQ)',           role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'GSG',  name: '원자재 (GSG)',          role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'GLD',  name: '금 (GLD)',             role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'HYG',  name: '하이일드채권 (HYG)',    role: AssetRole.offensive),
            StrategyAssetConfig(symbol: 'SHY',  name: '단기채권 (SHY)',        role: AssetRole.offensive),
          ],
        );
    }
  }
}

// ─── Monthly Price Bar ────────────────────────────────────────────────────────

class MonthlyBar {
  final DateTime date;
  final double price;

  const MonthlyBar({required this.date, required this.price});
}

// ─── Per-Asset Signal Data (for display) ─────────────────────────────────────

class AssetSignalData {
  final String symbol;
  final String name;
  final AssetRole role;
  final double? currentPrice;
  final double? return1m;
  final double? return3m;
  final double? return6m;
  final double? return12m;
  final double? momentumScore; // 12r1+4r3+2r6+r12
  final double? volatility12m;
  final double? sma10;
  final bool? isAboveSma;
  final double? faaScore;      // FAA rank sum (lower = better)
  final int? rank;             // overall rank within strategy universe
  final bool selected;         // is this asset chosen in the allocation?

  const AssetSignalData({
    required this.symbol,
    required this.name,
    required this.role,
    this.currentPrice,
    this.return1m,
    this.return3m,
    this.return6m,
    this.return12m,
    this.momentumScore,
    this.volatility12m,
    this.sma10,
    this.isAboveSma,
    this.faaScore,
    this.rank,
    this.selected = false,
  });
}

// ─── Final Allocation Entry ───────────────────────────────────────────────────

class AllocationEntry {
  final String symbol;
  final String name;
  final double weight; // 0.0 → 1.0
  final AssetRole role;

  const AllocationEntry({
    required this.symbol,
    required this.name,
    required this.weight,
    required this.role,
  });

  bool get isDefensive => role == AssetRole.defensive || role == AssetRole.canary;
}

// ─── Full Strategy Result ─────────────────────────────────────────────────────

class StrategyResult {
  final DynamicStrategyType strategyType;
  final DateTime calculationDate;
  final List<AllocationEntry> allocations;
  final List<AssetSignalData> signals;
  final String regime;          // e.g. "공격 모드" / "방어 모드"
  final String explanation;     // Korean explanation
  final double? breadthRatio;   // B/N (VAA/PAA/DAA)
  final double? cashWeight;     // PAA cash protection weight

  const StrategyResult({
    required this.strategyType,
    required this.calculationDate,
    required this.allocations,
    required this.signals,
    required this.regime,
    required this.explanation,
    this.breadthRatio,
    this.cashWeight,
  });

  bool get isOffensive =>
      allocations.any((a) => a.role == AssetRole.offensive);
}

// ─── Calculation Helpers (pure functions) ─────────────────────────────────────

/// Returns price at [monthsBack] months before the last bar.
/// Returns null if not enough data.
double? priceAt(List<MonthlyBar> bars, int monthsBack) {
  final idx = bars.length - 1 - monthsBack;
  if (idx < 0) return null;
  return bars[idx].price;
}

/// Simple return: (current - past) / past
double? calcReturn(double? current, double? past) {
  if (current == null || past == null || past == 0) return null;
  return (current - past) / past;
}

/// VAA/DAA momentum score: 12×r1m + 4×r3m + 2×r6m + r12m
double? calcMomentumScore(List<MonthlyBar> bars) {
  final cur = priceAt(bars, 0);
  final p1  = priceAt(bars, 1);
  final p3  = priceAt(bars, 3);
  final p6  = priceAt(bars, 6);
  final p12 = priceAt(bars, 12);
  if (cur == null || p1 == null || p3 == null || p6 == null || p12 == null) {
    return null;
  }
  final r1  = (cur - p1)  / p1;
  final r3  = (cur - p3)  / p3;
  final r6  = (cur - p6)  / p6;
  final r12 = (cur - p12) / p12;
  return 12 * r1 + 4 * r3 + 2 * r6 + r12;
}

/// Simple moving average of last [periods] bars.
double? calcSMA(List<MonthlyBar> bars, int periods) {
  if (bars.length < periods) return null;
  final subset = bars.sublist(bars.length - periods);
  return subset.map((b) => b.price).reduce((a, b) => a + b) / periods;
}

/// Annualised std dev of monthly returns over last [months] months.
/// Requires [months+1] price bars.
double? calcVolatility(List<MonthlyBar> bars, int months) {
  if (bars.length < months + 1) return null;
  final subset = bars.sublist(bars.length - months - 1);
  final returns = <double>[];
  for (int i = 1; i < subset.length; i++) {
    if (subset[i - 1].price > 0) {
      returns.add((subset[i].price - subset[i - 1].price) / subset[i - 1].price);
    }
  }
  if (returns.length < 2) return null;
  final mean = returns.reduce((a, b) => a + b) / returns.length;
  final variance = returns
          .map((r) => (r - mean) * (r - mean))
          .reduce((a, b) => a + b) /
      (returns.length - 1);
  return sqrt(variance) * sqrt(12); // annualise
}

/// Monthly returns list (length = months) for the last [months] periods.
List<double>? monthlyReturns(List<MonthlyBar> bars, int months) {
  if (bars.length < months + 1) return null;
  final subset = bars.sublist(bars.length - months - 1);
  final result = <double>[];
  for (int i = 1; i < subset.length; i++) {
    if (subset[i - 1].price > 0) {
      result.add((subset[i].price - subset[i - 1].price) / subset[i - 1].price);
    }
  }
  return result.length == months ? result : null;
}

/// Pearson correlation between two equal-length lists.
double? pearsonCorr(List<double> x, List<double> y) {
  final n = x.length;
  if (n != y.length || n < 2) return null;
  final mx = x.reduce((a, b) => a + b) / n;
  final my = y.reduce((a, b) => a + b) / n;
  double num = 0, dx = 0, dy = 0;
  for (int i = 0; i < n; i++) {
    num += (x[i] - mx) * (y[i] - my);
    dx  += (x[i] - mx) * (x[i] - mx);
    dy  += (y[i] - my) * (y[i] - my);
  }
  if (dx == 0 || dy == 0) return null;
  return num / sqrt(dx * dy);
}
