// ignore_for_file: unnecessary_brace_in_string_interps
import '../entities/dynamic_allocation.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Dynamic Allocation Calculation Service
// Implements: VAA, PAA, DAA, Dual Momentum, GTAA, FAA
// ═══════════════════════════════════════════════════════════════════════════════

class DynamicAllocationService {
  const DynamicAllocationService();

  /// Main entry point — dispatches to the correct strategy.
  StrategyResult calculate(
    DynamicStrategyConfig config,
    Map<String, List<MonthlyBar>> priceData,
  ) {
    return switch (config.strategyType) {
      DynamicStrategyType.vaa          => _calcVAA(config, priceData),
      DynamicStrategyType.paa          => _calcPAA(config, priceData),
      DynamicStrategyType.daa          => _calcDAA(config, priceData),
      DynamicStrategyType.dualMomentum => _calcDualMomentum(config, priceData),
      DynamicStrategyType.gtaa         => _calcGTAA(config, priceData),
      DynamicStrategyType.faa          => _calcFAA(config, priceData),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VAA — Vigilant Asset Allocation (Keller & Keuning 2017)
  // Rule: ALL offensive assets must have M>0 to be in offensive mode.
  //       If ANY is ≤0 → hold the best defensive asset.
  // ─────────────────────────────────────────────────────────────────────────────
  StrategyResult _calcVAA(
    DynamicStrategyConfig config,
    Map<String, List<MonthlyBar>> priceData,
  ) {
    final offensive = config.assets.where((a) => a.role == AssetRole.offensive).toList();
    final defensive = config.assets.where((a) => a.role == AssetRole.defensive).toList();

    // Compute signals for all assets
    final signals = _buildMomentumSignals(config.assets, priceData);

    final offSignals = signals.where((s) => s.role == AssetRole.offensive).toList();
    final defSignals = signals.where((s) => s.role == AssetRole.defensive).toList();

    // Count offensive assets with positive momentum
    final posCount = offSignals
        .where((s) => s.momentumScore != null && s.momentumScore! > 0)
        .length;
    final n = offensive.length;
    final breadth = n > 0 ? posCount / n : 0.0;

    final allPositive = posCount == n;

    List<AllocationEntry> allocations;
    String regime;
    String explanation;

    if (allPositive) {
      // Offensive mode: top topN by momentum score
      final ranked = offSignals
          .where((s) => s.momentumScore != null)
          .toList()
        ..sort((a, b) => (b.momentumScore ?? 0).compareTo(a.momentumScore ?? 0));
      final chosen = ranked.take(config.topN).toList();
      final weight = chosen.isNotEmpty ? 1.0 / chosen.length : 0.0;
      allocations = chosen
          .map((s) => AllocationEntry(
                symbol: s.symbol,
                name: s.name,
                weight: weight,
                role: AssetRole.offensive,
              ))
          .toList();
      regime = '공격 모드';
      final names = chosen.map((s) => s.symbol).join(', ');
      explanation = '공격 자산 ${n}개 모두 양의 모멘텀을 보유 중입니다.\n'
          '모멘텀 순위 상위 ${config.topN}개 자산($names)에 '
          '${(weight * 100).toStringAsFixed(0)}%씩 균등 투자합니다.';
    } else {
      // Defensive mode: best defensive by momentum score
      final ranked = defSignals
          .where((s) => s.momentumScore != null)
          .toList()
        ..sort((a, b) => (b.momentumScore ?? 0).compareTo(a.momentumScore ?? 0));

      AllocationEntry chosen;
      if (ranked.isNotEmpty) {
        final top = ranked.first;
        chosen = AllocationEntry(
          symbol: top.symbol,
          name: top.name,
          weight: 1.0,
          role: AssetRole.defensive,
        );
      } else if (defensive.isNotEmpty) {
        chosen = AllocationEntry(
          symbol: defensive.first.symbol,
          name: defensive.first.name,
          weight: 1.0,
          role: AssetRole.defensive,
        );
      } else {
        chosen = const AllocationEntry(symbol: 'CASH', name: '현금', weight: 1.0, role: AssetRole.defensive);
      }
      allocations = [chosen];
      regime = '방어 모드';
      final negNames = offSignals
          .where((s) => s.momentumScore == null || s.momentumScore! <= 0)
          .map((s) => s.symbol)
          .join(', ');
      explanation = '공격 자산 ${n}개 중 ${n - posCount}개($negNames)가 음의 모멘텀입니다.\n'
          'VAA는 단 하나의 공격 자산이라도 음수이면 방어 모드로 전환합니다.\n'
          '방어 자산 중 모멘텀이 가장 높은 ${chosen.symbol}에 100% 투자합니다.';
    }

    // Mark selected signals
    final selectedSymbols = allocations.map((a) => a.symbol).toSet();
    final markedSignals = signals
        .map((s) => AssetSignalData(
              symbol: s.symbol, name: s.name, role: s.role,
              currentPrice: s.currentPrice,
              return1m: s.return1m, return3m: s.return3m,
              return6m: s.return6m, return12m: s.return12m,
              momentumScore: s.momentumScore, selected: selectedSymbols.contains(s.symbol),
            ))
        .toList();

    return StrategyResult(
      strategyType: config.strategyType,
      calculationDate: config.calculationDate,
      allocations: allocations,
      signals: markedSignals,
      regime: regime,
      explanation: explanation,
      breadthRatio: breadth,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PAA — Protective Asset Allocation (Keller & Keuning 2016)
  // Protection = (N-B)/N where B = # offensive with positive 12m return.
  // ─────────────────────────────────────────────────────────────────────────────
  StrategyResult _calcPAA(
    DynamicStrategyConfig config,
    Map<String, List<MonthlyBar>> priceData,
  ) {
    final offensive = config.assets.where((a) => a.role == AssetRole.offensive).toList();

    final signals = _buildMomentumSignals(config.assets, priceData);
    final offSignals = signals.where((s) => s.role == AssetRole.offensive).toList();
    final defSignals = signals.where((s) => s.role == AssetRole.defensive).toList();

    final n = offensive.length;
    // B = # offensive with positive 12m return
    final b = offSignals
        .where((s) => s.return12m != null && s.return12m! > 0)
        .length;

    final cashFraction = n > 0 ? (n - b) / n : 1.0;
    final equityFraction = 1.0 - cashFraction;

    final allocations = <AllocationEntry>[];

    // Safe asset (cash/bonds)
    final safeAsset = defSignals.isNotEmpty ? defSignals.first : null;

    // Select top topN offensive assets with positive 12m return
    final positiveOff = offSignals
        .where((s) => s.return12m != null && s.return12m! > 0)
        .toList()
      ..sort((a, b) => (b.return12m ?? 0).compareTo(a.return12m ?? 0));
    final chosen = positiveOff.take(config.topN).toList();

    if (equityFraction > 0 && chosen.isNotEmpty) {
      final perAsset = equityFraction / chosen.length;
      for (final s in chosen) {
        allocations.add(AllocationEntry(
          symbol: s.symbol, name: s.name,
          weight: perAsset, role: AssetRole.offensive,
        ));
      }
    }

    if (cashFraction > 0 && safeAsset != null) {
      allocations.add(AllocationEntry(
        symbol: safeAsset.symbol, name: safeAsset.name,
        weight: cashFraction, role: AssetRole.defensive,
      ));
    } else if (cashFraction > 0) {
      allocations.add(const AllocationEntry(
        symbol: 'CASH', name: '현금', weight: 1.0, role: AssetRole.defensive,
      ));
    }

    final regime = cashFraction >= 0.5 ? '방어 모드' : '공격 모드';
    final explanation = '공격 자산 ${n}개 중 ${b}개가 양의 12개월 수익률을 보유합니다.\n'
        '보호 비율 = (${n}-${b}) / ${n} = ${(cashFraction * 100).toStringAsFixed(0)}%\n'
        '→ 안전 자산(${safeAsset?.symbol ?? 'CASH'}) ${(cashFraction * 100).toStringAsFixed(0)}%, '
        '주식 자산 ${(equityFraction * 100).toStringAsFixed(0)}%\n'
        '주식 portion: 양의 모멘텀 상위 ${chosen.length}개 자산에 균등 배분';

    final selectedSymbols = allocations.map((a) => a.symbol).toSet();
    final markedSignals = signals.map((s) => AssetSignalData(
      symbol: s.symbol, name: s.name, role: s.role,
      currentPrice: s.currentPrice,
      return1m: s.return1m, return3m: s.return3m,
      return6m: s.return6m, return12m: s.return12m,
      momentumScore: s.momentumScore, selected: selectedSymbols.contains(s.symbol),
    )).toList();

    return StrategyResult(
      strategyType: config.strategyType,
      calculationDate: config.calculationDate,
      allocations: allocations,
      signals: markedSignals,
      regime: regime,
      explanation: explanation,
      breadthRatio: n > 0 ? b / n : 0,
      cashWeight: cashFraction,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DAA — Defensive Asset Allocation (Keller & Keuning 2018)
  // Canary assets (VWO, BND) signal market health.
  // ─────────────────────────────────────────────────────────────────────────────
  StrategyResult _calcDAA(
    DynamicStrategyConfig config,
    Map<String, List<MonthlyBar>> priceData,
  ) {
    final signals = _buildMomentumSignals(config.assets, priceData);
    final canarySignals   = signals.where((s) => s.role == AssetRole.canary).toList();
    final offSignals      = signals.where((s) => s.role == AssetRole.offensive).toList();
    final defSignals      = signals.where((s) => s.role == AssetRole.defensive).toList();

    final badCanary = canarySignals.where(
      (s) => s.momentumScore == null || s.momentumScore! <= 0,
    ).toList();

    final List<AllocationEntry> allocations;
    final String regime;
    final String explanation;

    if (badCanary.isNotEmpty) {
      // Defensive: best defensive by momentum
      final ranked = defSignals
          .where((s) => s.momentumScore != null)
          .toList()
        ..sort((a, b) => (b.momentumScore ?? 0).compareTo(a.momentumScore ?? 0));
      final best = ranked.isNotEmpty ? ranked.first
          : (defSignals.isNotEmpty ? defSignals.first : null);
      allocations = best != null
          ? [AllocationEntry(symbol: best.symbol, name: best.name, weight: 1.0, role: AssetRole.defensive)]
          : [const AllocationEntry(symbol: 'CASH', name: '현금', weight: 1.0, role: AssetRole.defensive)];
      regime = '방어 모드';
      final badNames = badCanary.map((s) => s.symbol).join(', ');
      explanation = '카나리아 자산 중 ${badNames}이 음의 모멘텀을 보입니다.\n'
          'DAA는 카나리아가 위험 신호를 보내면 즉시 방어 모드로 전환합니다.\n'
          '방어 자산 중 모멘텀이 가장 높은 ${allocations.first.symbol}에 100% 투자합니다.';
    } else {
      // Offensive: top topN by momentum
      final ranked = offSignals
          .where((s) => s.momentumScore != null)
          .toList()
        ..sort((a, b) => (b.momentumScore ?? 0).compareTo(a.momentumScore ?? 0));
      final chosen = ranked.take(config.topN).toList();
      final weight = chosen.isNotEmpty ? 1.0 / chosen.length : 0.0;
      allocations = chosen.map((s) => AllocationEntry(
        symbol: s.symbol, name: s.name, weight: weight, role: AssetRole.offensive,
      )).toList();
      regime = '공격 모드';
      final names = chosen.map((s) => s.symbol).join(', ');
      explanation = '카나리아 자산(${canarySignals.map((s) => s.symbol).join(', ')}) '
          '모두 양의 모멘텀입니다.\n시장이 정상 범위에 있으므로 공격 모드를 유지합니다.\n'
          '공격 자산 모멘텀 상위 ${config.topN}개($names)에 균등 투자합니다.';
    }

    final canaryOK = badCanary.isEmpty;
    final selectedSymbols = allocations.map((a) => a.symbol).toSet();
    final markedSignals = signals.map((s) => AssetSignalData(
      symbol: s.symbol, name: s.name, role: s.role,
      currentPrice: s.currentPrice,
      return1m: s.return1m, return3m: s.return3m,
      return6m: s.return6m, return12m: s.return12m,
      momentumScore: s.momentumScore, selected: selectedSymbols.contains(s.symbol),
    )).toList();

    return StrategyResult(
      strategyType: config.strategyType,
      calculationDate: config.calculationDate,
      allocations: allocations,
      signals: markedSignals,
      regime: regime,
      explanation: explanation,
      breadthRatio: canarySignals.isNotEmpty
          ? (canaryOK ? 1.0 : badCanary.length / canarySignals.length)
          : null,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dual Momentum / GEM (Gary Antonacci)
  // SPY 12m > 0 → equities (SPY or ACWX by relative momentum)
  // SPY 12m ≤ 0 → bonds (AGG)
  // ─────────────────────────────────────────────────────────────────────────────
  StrategyResult _calcDualMomentum(
    DynamicStrategyConfig config,
    Map<String, List<MonthlyBar>> priceData,
  ) {
    final offAssets = config.assets.where((a) => a.role == AssetRole.offensive).toList();
    final defAssets = config.assets.where((a) => a.role == AssetRole.defensive).toList();

    // Expected: SPY and ACWX as offensive; AGG as defensive
    final spyBars  = priceData['SPY'];
    final acwxBars = priceData['ACWX'];

    final r12Spy  = spyBars  != null ? calcReturn(priceAt(spyBars,  0), priceAt(spyBars,  12)) : null;
    final r12Acwx = acwxBars != null ? calcReturn(priceAt(acwxBars, 0), priceAt(acwxBars, 12)) : null;

    // Build signals for display
    final signals = <AssetSignalData>[];
    for (final asset in config.assets) {
      final bars = priceData[asset.symbol];
      signals.add(AssetSignalData(
        symbol: asset.symbol,
        name: asset.name,
        role: asset.role,
        currentPrice: bars != null ? priceAt(bars, 0) : null,
        return12m: bars != null ? calcReturn(priceAt(bars, 0), priceAt(bars, 12)) : null,
        return1m:  bars != null ? calcReturn(priceAt(bars, 0), priceAt(bars, 1))  : null,
        return3m:  bars != null ? calcReturn(priceAt(bars, 0), priceAt(bars, 3))  : null,
        return6m:  bars != null ? calcReturn(priceAt(bars, 0), priceAt(bars, 6))  : null,
      ));
    }

    final List<AllocationEntry> allocations;
    final String regime;
    final String explanation;

    if (r12Spy == null) {
      // No data
      final def = defAssets.isNotEmpty ? defAssets.first : null;
      allocations = def != null
          ? [AllocationEntry(symbol: def.symbol, name: def.name, weight: 1.0, role: AssetRole.defensive)]
          : [const AllocationEntry(symbol: 'CASH', name: '현금', weight: 1.0, role: AssetRole.defensive)];
      regime = '데이터 부족';
      explanation = 'SPY 데이터를 불러오지 못했습니다. 방어 자산으로 배분합니다.';
    } else if (r12Spy > 0) {
      // Absolute momentum positive → equities
      // Relative momentum: SPY vs ACWX
      final usaBetter = (r12Acwx == null) || (r12Spy >= r12Acwx);
      final chosen = usaBetter
          ? offAssets.firstWhere((a) => a.symbol == 'SPY', orElse: () => offAssets.first)
          : offAssets.firstWhere((a) => a.symbol == 'ACWX', orElse: () => offAssets.last);
      allocations = [AllocationEntry(symbol: chosen.symbol, name: chosen.name, weight: 1.0, role: AssetRole.offensive)];
      regime = '공격 모드 (주식)';
      final r12SpyPct   = (r12Spy * 100).toStringAsFixed(1);
      final r12AcwxPct  = r12Acwx != null ? (r12Acwx * 100).toStringAsFixed(1) : 'N/A';
      explanation = '절대 모멘텀: SPY 12개월 수익률 = ${r12SpyPct}% > 0 → 주식 모드\n'
          '상대 모멘텀: SPY(${r12SpyPct}%) vs ACWX(${r12AcwxPct}%)\n'
          '→ ${chosen.symbol}(${chosen.name})에 100% 투자';
    } else {
      // Absolute momentum negative → bonds
      final def = defAssets.isNotEmpty ? defAssets.first : null;
      allocations = def != null
          ? [AllocationEntry(symbol: def.symbol, name: def.name, weight: 1.0, role: AssetRole.defensive)]
          : [const AllocationEntry(symbol: 'CASH', name: '현금', weight: 1.0, role: AssetRole.defensive)];
      regime = '방어 모드 (채권)';
      final r12SpyPct = (r12Spy * 100).toStringAsFixed(1);
      explanation = '절대 모멘텀: SPY 12개월 수익률 = ${r12SpyPct}% ≤ 0\n'
          '주식 시장이 절대적으로 부진합니다.\n'
          '→ 채권(${allocations.first.symbol})에 100% 투자';
    }

    final selectedSymbols = allocations.map((a) => a.symbol).toSet();
    final markedSignals = signals.map((s) => AssetSignalData(
      symbol: s.symbol, name: s.name, role: s.role,
      currentPrice: s.currentPrice,
      return1m: s.return1m, return3m: s.return3m,
      return6m: s.return6m, return12m: s.return12m,
      selected: selectedSymbols.contains(s.symbol),
    )).toList();

    return StrategyResult(
      strategyType: config.strategyType,
      calculationDate: config.calculationDate,
      allocations: allocations,
      signals: markedSignals,
      regime: regime,
      explanation: explanation,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // GTAA — Global Tactical Asset Allocation (Mebane Faber)
  // Hold each offensive asset equally if price > SMA10, else hold cash.
  // ─────────────────────────────────────────────────────────────────────────────
  StrategyResult _calcGTAA(
    DynamicStrategyConfig config,
    Map<String, List<MonthlyBar>> priceData,
  ) {
    final offAssets = config.assets.where((a) => a.role == AssetRole.offensive).toList();
    final defAssets = config.assets.where((a) => a.role == AssetRole.defensive).toList();
    final defSymbol = defAssets.isNotEmpty ? defAssets.first : null;

    final signals = <AssetSignalData>[];
    final aboveSma = <StrategyAssetConfig>[];

    for (final asset in offAssets) {
      final bars = priceData[asset.symbol];
      final cur  = bars != null ? priceAt(bars, 0) : null;
      final sma  = bars != null ? calcSMA(bars, 10) : null;
      final above = (cur != null && sma != null) ? cur > sma : null;

      signals.add(AssetSignalData(
        symbol: asset.symbol, name: asset.name, role: asset.role,
        currentPrice: cur,
        return1m:  bars != null ? calcReturn(priceAt(bars, 0), priceAt(bars, 1))  : null,
        return12m: bars != null ? calcReturn(priceAt(bars, 0), priceAt(bars, 12)) : null,
        sma10: sma,
        isAboveSma: above,
      ));

      if (above == true) aboveSma.add(asset);
    }

    final List<AllocationEntry> allocations;
    final String regime;
    final String explanation;

    if (aboveSma.isEmpty) {
      // All below SMA → 100% cash
      final def = defSymbol;
      allocations = def != null
          ? [AllocationEntry(symbol: def.symbol, name: def.name, weight: 1.0, role: AssetRole.defensive)]
          : [const AllocationEntry(symbol: 'CASH', name: '현금', weight: 1.0, role: AssetRole.defensive)];
      regime = '전량 현금';
      explanation = '${offAssets.length}개 자산 모두 10개월 이동평균 아래에 있습니다.\n'
          '시장이 전반적으로 약세이므로 전량 현금(${allocations.first.symbol})으로 보유합니다.';
    } else {
      final weight = 1.0 / offAssets.length; // always 1/N of total universe
      final cashCount = offAssets.length - aboveSma.length;
      final cashWeight = cashCount * weight;

      allocations = aboveSma
          .map((a) => AllocationEntry(symbol: a.symbol, name: a.name, weight: weight, role: AssetRole.offensive))
          .toList();

      if (cashWeight > 0 && defSymbol != null) {
        allocations.add(AllocationEntry(
          symbol: defSymbol.symbol, name: defSymbol.name,
          weight: cashWeight, role: AssetRole.defensive,
        ));
      }

      regime = cashWeight > 0 ? '부분 방어' : '공격 모드';
      final aboveNames = aboveSma.map((a) => a.symbol).join(', ');
      final defName = defSymbol?.symbol ?? 'CASH';
      explanation = '${offAssets.length}개 자산 중 ${aboveSma.length}개($aboveNames)가 '
          '10개월 이동평균 위에 있습니다.\n'
          '각 자산은 전체 포트폴리오의 ${(weight * 100).toStringAsFixed(0)}%를 차지합니다.\n'
          '이동평균 아래 ${cashCount}개 자산 = 현금($defName)으로 대체';
    }

    final selectedSymbols = allocations.map((a) => a.symbol).toSet();
    // Add defensive signal for display
    if (defSymbol != null) {
      final defBars = priceData[defSymbol.symbol];
      signals.add(AssetSignalData(
        symbol: defSymbol.symbol, name: defSymbol.name, role: AssetRole.defensive,
        currentPrice: defBars != null ? priceAt(defBars, 0) : null,
        selected: selectedSymbols.contains(defSymbol.symbol),
      ));
    }
    final markedSignals = signals.map((s) => AssetSignalData(
      symbol: s.symbol, name: s.name, role: s.role,
      currentPrice: s.currentPrice,
      return1m: s.return1m, return12m: s.return12m,
      sma10: s.sma10, isAboveSma: s.isAboveSma,
      selected: selectedSymbols.contains(s.symbol),
    )).toList();

    return StrategyResult(
      strategyType: config.strategyType,
      calculationDate: config.calculationDate,
      allocations: allocations,
      signals: markedSignals,
      regime: regime,
      explanation: explanation,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FAA — Flexible Asset Allocation (Keuning & Keller 2012)
  // Score each asset on momentum rank + volatility rank + correlation rank.
  // Hold top topN with positive momentum.
  // ─────────────────────────────────────────────────────────────────────────────
  StrategyResult _calcFAA(
    DynamicStrategyConfig config,
    Map<String, List<MonthlyBar>> priceData,
  ) {
    const lookback = 12; // months
    final assets = config.assets.where((a) => a.role == AssetRole.offensive).toList();

    // Compute monthly returns for each asset
    final monthlyRets = <String, List<double>>{};
    for (final asset in assets) {
      final bars = priceData[asset.symbol];
      if (bars != null) {
        final rets = monthlyReturns(bars, lookback);
        if (rets != null) monthlyRets[asset.symbol] = rets;
      }
    }

    // Equal-weight portfolio monthly returns
    final validSymbols = monthlyRets.keys.toList();
    List<double>? portfolioRets;
    if (validSymbols.isNotEmpty) {
      portfolioRets = List.generate(lookback, (i) {
        final vals = validSymbols
            .map((s) => monthlyRets[s]![i])
            .toList();
        return vals.reduce((a, b) => a + b) / vals.length;
      });
    }

    // Compute per-asset metrics
    final metrics = <_FAAAssetMetric>[];
    for (final asset in assets) {
      final bars = priceData[asset.symbol];
      final r12m = bars != null ? calcReturn(priceAt(bars, 0), priceAt(bars, 12)) : null;
      final vol  = bars != null ? calcVolatility(bars, lookback) : null;
      final rets = monthlyRets[asset.symbol];
      final corr = (rets != null && portfolioRets != null)
          ? pearsonCorr(rets, portfolioRets)
          : null;
      metrics.add(_FAAAssetMetric(asset: asset, r12m: r12m, vol: vol, corr: corr));
    }

    // Rank each metric (1 = best)
    // Momentum: higher return → rank 1
    _assignRanks(metrics, (m) => m.r12m, ascending: false);
    // Volatility: lower vol → rank 1
    _assignVolRanks(metrics);
    // Correlation: lower corr → rank 1
    _assignCorrRanks(metrics);

    // FAA score = sum of three ranks (lower = better)
    for (final m in metrics) {
      final rRank = m.momentumRank ?? (metrics.length + 1);
      final vRank = m.volRank ?? (metrics.length + 1);
      final cRank = m.corrRank ?? (metrics.length + 1);
      m.faaScore = (rRank + vRank + cRank).toDouble();
    }

    // Sort by FAA score, then filter to positive momentum, take topN
    metrics.sort((a, b) => (a.faaScore ?? 999).compareTo(b.faaScore ?? 999));
    final positiveM = metrics.where((m) => m.r12m != null && m.r12m! > 0).toList();
    final chosen = positiveM.take(config.topN).toList();

    final weight = chosen.isNotEmpty ? 1.0 / chosen.length : 0.0;
    final allocations = chosen.map((m) => AllocationEntry(
      symbol: m.asset.symbol, name: m.asset.name,
      weight: weight, role: AssetRole.offensive,
    )).toList();

    final selectedSymbols = chosen.map((m) => m.asset.symbol).toSet();

    // Build signals
    final signals = metrics.map((m) {
      final bars = priceData[m.asset.symbol];
      return AssetSignalData(
        symbol: m.asset.symbol, name: m.asset.name, role: m.asset.role,
        currentPrice: bars != null ? priceAt(bars, 0) : null,
        return12m: m.r12m,
        return1m:  bars != null ? calcReturn(priceAt(bars, 0), priceAt(bars, 1)) : null,
        return3m:  bars != null ? calcReturn(priceAt(bars, 0), priceAt(bars, 3)) : null,
        return6m:  bars != null ? calcReturn(priceAt(bars, 0), priceAt(bars, 6)) : null,
        volatility12m: m.vol,
        faaScore: m.faaScore,
        rank: m.momentumRank,
        selected: selectedSymbols.contains(m.asset.symbol),
      );
    }).toList();

    final regime = chosen.isNotEmpty ? '공격 모드' : '방어 모드 (양의 모멘텀 없음)';
    final chosenNames = chosen.map((m) => m.asset.symbol).join(', ');
    final explanation = '${assets.length}개 자산의 모멘텀·변동성·상관관계를 순위화하여 합산합니다.\n'
        '(점수가 낮을수록 우수)\n'
        '양의 12개월 수익률 자산 중 FAA 점수 상위 ${config.topN}개에 투자합니다.\n'
        '→ 선택: ${chosenNames.isNotEmpty ? chosenNames : "없음 (전량 현금)"}';

    return StrategyResult(
      strategyType: config.strategyType,
      calculationDate: config.calculationDate,
      allocations: allocations.isNotEmpty
          ? allocations
          : [const AllocationEntry(symbol: 'CASH', name: '현금', weight: 1.0, role: AssetRole.defensive)],
      signals: signals,
      regime: regime,
      explanation: explanation,
    );
  }

  // ─── Shared Helper: Build momentum-based signal list ─────────────────────────

  List<AssetSignalData> _buildMomentumSignals(
    List<StrategyAssetConfig> assets,
    Map<String, List<MonthlyBar>> priceData,
  ) {
    return assets.map((asset) {
      final bars = priceData[asset.symbol];
      final cur  = bars != null ? priceAt(bars, 0)  : null;
      final p1   = bars != null ? priceAt(bars, 1)  : null;
      final p3   = bars != null ? priceAt(bars, 3)  : null;
      final p6   = bars != null ? priceAt(bars, 6)  : null;
      final p12  = bars != null ? priceAt(bars, 12) : null;
      return AssetSignalData(
        symbol: asset.symbol,
        name: asset.name,
        role: asset.role,
        currentPrice: cur,
        return1m:  calcReturn(cur, p1),
        return3m:  calcReturn(cur, p3),
        return6m:  calcReturn(cur, p6),
        return12m: calcReturn(cur, p12),
        momentumScore: bars != null ? calcMomentumScore(bars) : null,
      );
    }).toList();
  }

  // ─── FAA Ranking Helpers ──────────────────────────────────────────────────

  void _assignRanks(
    List<_FAAAssetMetric> metrics,
    double? Function(_FAAAssetMetric) getValue, {
    required bool ascending,
  }) {
    final sorted = metrics
        .where((m) => getValue(m) != null)
        .toList()
      ..sort((a, b) => ascending
          ? (getValue(a)!).compareTo(getValue(b)!)
          : (getValue(b)!).compareTo(getValue(a)!));
    for (int i = 0; i < sorted.length; i++) {
      sorted[i].momentumRank = i + 1;
    }
  }

  void _assignVolRanks(List<_FAAAssetMetric> metrics) {
    final sorted = metrics
        .where((m) => m.vol != null)
        .toList()
      ..sort((a, b) => a.vol!.compareTo(b.vol!)); // lower vol = rank 1
    for (int i = 0; i < sorted.length; i++) {
      sorted[i].volRank = i + 1;
    }
  }

  void _assignCorrRanks(List<_FAAAssetMetric> metrics) {
    final sorted = metrics
        .where((m) => m.corr != null)
        .toList()
      ..sort((a, b) => a.corr!.compareTo(b.corr!)); // lower corr = rank 1
    for (int i = 0; i < sorted.length; i++) {
      sorted[i].corrRank = i + 1;
    }
  }
}

// ─── Private helper class for FAA ────────────────────────────────────────────

class _FAAAssetMetric {
  final StrategyAssetConfig asset;
  final double? r12m;
  final double? vol;
  final double? corr;
  int? momentumRank;
  int? volRank;
  int? corrRank;
  double? faaScore;

  _FAAAssetMetric({
    required this.asset,
    this.r12m,
    this.vol,
    this.corr,
  });
}
