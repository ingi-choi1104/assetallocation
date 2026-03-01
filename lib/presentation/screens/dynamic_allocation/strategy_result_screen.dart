import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/datasources/local/portfolio_strategy_local_ds.dart';
import '../../../domain/entities/asset.dart';
import '../../../domain/entities/dynamic_allocation.dart';
import '../../../domain/entities/portfolio.dart';
import '../../../domain/enums/asset_type.dart';
import '../../providers/asset_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/dynamic_allocation_providers.dart';
import '../../providers/portfolio_providers.dart';

/// Result screen: fetches price data and displays the strategy recommendation.
class StrategyResultScreen extends ConsumerStatefulWidget {
  final DynamicStrategyConfig config;

  const StrategyResultScreen({super.key, required this.config});

  @override
  ConsumerState<StrategyResultScreen> createState() => _StrategyResultScreenState();
}

class _StrategyResultScreenState extends ConsumerState<StrategyResultScreen> {
  StrategyResult? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  Future<void> _calculate() async {
    try {
      final priceDs  = ref.read(dynamicPriceDsProvider);
      final service  = ref.read(dynamicAllocationServiceProvider);
      final priceData = await priceDs.fetchMonthlyPrices(
        widget.config.symbols,
        widget.config.calculationDate,
      );
      final result = service.calculate(widget.config, priceData);
      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.config.strategyType;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              '${_formatDate(widget.config.calculationDate)} 기준',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          if (!_loading && _result != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '다시 계산',
              onPressed: () {
                setState(() { _loading = true; _error = null; _result = null; });
                _calculate();
              },
            ),
        ],
      ),
      body: _loading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(error: _error!, onRetry: () {
                  setState(() { _loading = true; _error = null; });
                  _calculate();
                })
              : _ResultView(result: _result!),
      bottomNavigationBar: (!_loading && _result != null)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: () => _createPortfolio(context),
                  icon: const Icon(Icons.add),
                  label: const Text('이 전략으로 포트폴리오 만들기'),
                ),
              ),
            )
          : null,
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')}';

  Future<void> _createPortfolio(BuildContext context) async {
    // Capture router before any await to avoid async-gap lint
    final router = GoRouter.of(context);
    final nameCtrl = TextEditingController(
        text: widget.config.strategyType.displayName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('포트폴리오 만들기'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '포트폴리오 이름'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('만들기')),
        ],
      ),
    );
    // Read text BEFORE dispose to avoid _dependents.isEmpty assertion
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();

    if (confirmed != true || !mounted) return;
    if (name.isEmpty) return;

    final portfolio = Portfolio(
      id: 0,
      name: name,
      baseCurrency: 'USD',
      deviationThreshold: 5.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final newId = await ref.read(portfolioActionsProvider).create(portfolio);

    // Auto-add all strategy assets with weights from the calculation result
    final assetActions = ref.read(assetActionsProvider);
    final assetRepo = ref.read(assetRepositoryProvider);
    final allocations = _result!.allocations;

    for (int i = 0; i < allocations.length; i++) {
      final entry = allocations[i];
      // All dynamic allocation assets are US ETFs (USD-denominated)
      final existing = await assetRepo.getAssetBySymbolAndType(
          entry.symbol, AssetType.usStock.value);

      final int assetId;
      if (existing != null) {
        assetId = existing.id;
      } else {
        assetId = await assetActions.upsertAsset(Asset(
          id: 0,
          symbol: entry.symbol,
          name: entry.name,
          assetType: AssetType.usStock,
          currency: 'USD',
          createdAt: DateTime.now(),
        ));
      }

      await assetActions.addToPortfolio(
        portfolioId: newId,
        assetId: assetId,
        targetWeight: entry.weight * 100, // fraction (0-1) → percentage (0-100)
        sortOrder: i,
      );
    }

    await ref.read(portfolioStrategyLocalDsProvider).save(
          PortfolioStrategyEntry(
            portfolioId: newId,
            strategyType: widget.config.strategyType.name,
            calculationDate: widget.config.calculationDate,
          ),
        );

    // Capture GoRouter while context is still valid, then navigate
    // after the current frame AND pending microtasks (Drift stream
    // notifications) have fully settled.  This avoids
    // "setState() called during build" / "_children.contains(child)"
    // assertions caused by late stream notifications arriving during
    // a GoRouter route transition.
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.microtask(() {
          router.go('/');
          router.push('/portfolio/$newId');
        });
      });
    }
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('월별 가격 데이터를 불러오는 중...', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 4),
          Text('최대 15개월 데이터를 조회합니다', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('가격 데이터 조회 실패', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main Result View ──────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final StrategyResult result;

  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _RegimeCard(result: result),
        const SizedBox(height: 12),
        _AllocationCard(result: result),
        const SizedBox(height: 12),
        _SignalCard(result: result),
        const SizedBox(height: 12),
        _ExplanationCard(result: result),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Regime Badge Card ─────────────────────────────────────────────────────────

class _RegimeCard extends StatelessWidget {
  final StrategyResult result;

  const _RegimeCard({required this.result});

  static const _offensiveColor = AppColors.positive;
  static const _defensiveColor = Color(0xFFC62828);
  static const _neutralColor   = Color(0xFFEF6C00);

  Color get _regimeColor {
    final r = result.regime;
    if (r.contains('공격')) return _offensiveColor;
    if (r.contains('방어') || r.contains('현금')) return _defensiveColor;
    return _neutralColor;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _regimeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                result.isOffensive ? Icons.trending_up : Icons.shield_outlined,
                color: _regimeColor, size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 시장 판단',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    result.regime,
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: _regimeColor,
                    ),
                  ),
                  if (result.breadthRatio != null)
                    Text(
                      '브레스 비율: ${(result.breadthRatio! * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Allocation Card with Pie Chart ────────────────────────────────────────────

class _AllocationCard extends StatefulWidget {
  final StrategyResult result;

  const _AllocationCard({required this.result});

  @override
  State<_AllocationCard> createState() => _AllocationCardState();
}

class _AllocationCardState extends State<_AllocationCard> {
  int _touchedIndex = -1;

  static const _colors = AppColors.chartColors;

  @override
  Widget build(BuildContext context) {
    final allocations = widget.result.allocations;
    if (allocations.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '권장 자산 배분',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Pie chart
                SizedBox(
                  width: 160, height: 160,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse?.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse!
                                .touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: [
                        for (int i = 0; i < allocations.length; i++)
                          PieChartSectionData(
                            value: allocations[i].weight * 100,
                            color: _colors[i % _colors.length],
                            radius: _touchedIndex == i ? 64 : 52,
                            title: _touchedIndex == i
                                ? '${(allocations[i].weight * 100).toStringAsFixed(0)}%'
                                : '',
                            titleStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white,
                            ),
                          ),
                      ],
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < allocations.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(
                                  color: _colors[i % _colors.length],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      allocations[i].symbol,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      _shortName(allocations[i].name),
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${(allocations[i].weight * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: allocations[i].isDefensive
                                      ? Colors.blueGrey
                                      : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortName(String name) {
    final idx = name.lastIndexOf('(');
    return idx > 0 ? name.substring(0, idx).trim() : name;
  }
}

// ── Signal Detail Card ────────────────────────────────────────────────────────

class _SignalCard extends StatefulWidget {
  final StrategyResult result;

  const _SignalCard({required this.result});

  @override
  State<_SignalCard> createState() => _SignalCardState();
}

class _SignalCardState extends State<_SignalCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final type = widget.result.strategyType;
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.bar_chart, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '자산별 신호 상세',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_expanded) _buildSignalTable(type),
        ],
      ),
    );
  }

  Widget _buildSignalTable(DynamicStrategyType type) {
    return switch (type) {
      DynamicStrategyType.gtaa          => _GTAASignalTable(signals: widget.result.signals),
      DynamicStrategyType.faa           => _FAASignalTable(signals: widget.result.signals),
      DynamicStrategyType.dualMomentum  => _DualMomSignalTable(signals: widget.result.signals),
      _                                 => _MomentumSignalTable(
                                              signals: widget.result.signals,
                                              showMScore: type != DynamicStrategyType.paa,
                                            ),
    };
  }
}

// ── Momentum Table (VAA / PAA / DAA) ─────────────────────────────────────────

class _MomentumSignalTable extends StatelessWidget {
  final List<AssetSignalData> signals;
  final bool showMScore;

  const _MomentumSignalTable({required this.signals, this.showMScore = true});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 32,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 36,
        headingTextStyle: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey,
        ),
        columns: [
          const DataColumn(label: Text('자산')),
          const DataColumn(label: Text('역할')),
          const DataColumn(label: Text('1개월'), numeric: true),
          const DataColumn(label: Text('3개월'), numeric: true),
          const DataColumn(label: Text('6개월'), numeric: true),
          const DataColumn(label: Text('12개월'), numeric: true),
          if (showMScore) const DataColumn(label: Text('M점수'), numeric: true),
          const DataColumn(label: Text('상태')),
        ],
        rows: signals.map((s) {
          final isSelected = s.selected;
          return DataRow(
            color: WidgetStateProperty.all(
              isSelected ? AppColors.primary.withValues(alpha: 0.07) : null,
            ),
            cells: [
              DataCell(Text(s.symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataCell(_RoleChip(role: s.role)),
              DataCell(_ReturnText(s.return1m)),
              DataCell(_ReturnText(s.return3m)),
              DataCell(_ReturnText(s.return6m)),
              DataCell(_ReturnText(s.return12m)),
              if (showMScore) DataCell(
                s.momentumScore != null
                    ? Text(
                        s.momentumScore!.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 12,
                          color: s.momentumScore! > 0 ? AppColors.positive : AppColors.negative,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : const Text('-', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              DataCell(
                isSelected
                    ? const Icon(Icons.check_circle, color: AppColors.positive, size: 16)
                    : (s.momentumScore != null && s.momentumScore! <= 0
                        ? const Icon(Icons.cancel_outlined, color: AppColors.negative, size: 16)
                        : const Icon(Icons.remove, color: Colors.grey, size: 16)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── GTAA Table ────────────────────────────────────────────────────────────────

class _GTAASignalTable extends StatelessWidget {
  final List<AssetSignalData> signals;

  const _GTAASignalTable({required this.signals});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 32,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 36,
        headingTextStyle: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey,
        ),
        columns: const [
          DataColumn(label: Text('자산')),
          DataColumn(label: Text('현재가'), numeric: true),
          DataColumn(label: Text('SMA10'), numeric: true),
          DataColumn(label: Text('판단')),
          DataColumn(label: Text('배분')),
        ],
        rows: signals.map((s) {
          final hold = s.isAboveSma == true;
          return DataRow(
            color: WidgetStateProperty.all(
              hold ? AppColors.primary.withValues(alpha: 0.07) : null,
            ),
            cells: [
              DataCell(Text(s.symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataCell(Text(
                s.currentPrice != null ? '\$${s.currentPrice!.toStringAsFixed(2)}' : '-',
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(Text(
                s.sma10 != null ? '\$${s.sma10!.toStringAsFixed(2)}' : '-',
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(
                s.isAboveSma == null
                    ? const Text('-', style: TextStyle(fontSize: 12))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            s.isAboveSma! ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 12,
                            color: s.isAboveSma! ? AppColors.positive : AppColors.negative,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            s.isAboveSma! ? '이평 위' : '이평 아래',
                            style: TextStyle(
                              fontSize: 11,
                              color: s.isAboveSma! ? AppColors.positive : AppColors.negative,
                            ),
                          ),
                        ],
                      ),
              ),
              DataCell(
                s.selected
                    ? const Icon(Icons.check_circle, color: AppColors.positive, size: 16)
                    : const Text('현금 대체', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── FAA Table ─────────────────────────────────────────────────────────────────

class _FAASignalTable extends StatelessWidget {
  final List<AssetSignalData> signals;

  const _FAASignalTable({required this.signals});

  @override
  Widget build(BuildContext context) {
    final sorted = [...signals]..sort((a, b) => (a.faaScore ?? 999).compareTo(b.faaScore ?? 999));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 32,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 36,
        headingTextStyle: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey,
        ),
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('자산')),
          DataColumn(label: Text('12개월'), numeric: true),
          DataColumn(label: Text('변동성'), numeric: true),
          DataColumn(label: Text('FAA점수'), numeric: true),
          DataColumn(label: Text('선택')),
        ],
        rows: sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return DataRow(
            color: WidgetStateProperty.all(
              s.selected ? AppColors.primary.withValues(alpha: 0.07) : null,
            ),
            cells: [
              DataCell(Text('${i+1}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
              DataCell(Text(s.symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataCell(_ReturnText(s.return12m)),
              DataCell(Text(
                s.volatility12m != null ? '${(s.volatility12m! * 100).toStringAsFixed(1)}%' : '-',
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(Text(
                s.faaScore != null ? s.faaScore!.toStringAsFixed(0) : '-',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: s.selected ? AppColors.primary : null,
                ),
              )),
              DataCell(
                s.selected
                    ? const Icon(Icons.check_circle, color: AppColors.positive, size: 16)
                    : const Icon(Icons.remove, color: Colors.grey, size: 16),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Dual Momentum Table ───────────────────────────────────────────────────────

class _DualMomSignalTable extends StatelessWidget {
  final List<AssetSignalData> signals;

  const _DualMomSignalTable({required this.signals});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 32,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 36,
        headingTextStyle: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey,
        ),
        columns: const [
          DataColumn(label: Text('자산')),
          DataColumn(label: Text('역할')),
          DataColumn(label: Text('1개월'), numeric: true),
          DataColumn(label: Text('12개월'), numeric: true),
          DataColumn(label: Text('선택')),
        ],
        rows: signals.map((s) => DataRow(
          color: WidgetStateProperty.all(
            s.selected ? AppColors.primary.withValues(alpha: 0.07) : null,
          ),
          cells: [
            DataCell(Text(s.symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataCell(_RoleChip(role: s.role)),
            DataCell(_ReturnText(s.return1m)),
            DataCell(_ReturnText(s.return12m)),
            DataCell(
              s.selected
                  ? const Icon(Icons.check_circle, color: AppColors.positive, size: 16)
                  : const Icon(Icons.remove, color: Colors.grey, size: 16),
            ),
          ],
        )).toList(),
      ),
    );
  }
}

// ── Explanation Card ──────────────────────────────────────────────────────────

class _ExplanationCard extends StatelessWidget {
  final StrategyResult result;

  const _ExplanationCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary.withValues(alpha: 0.05),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  '배분 근거',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              result.explanation,
              style: const TextStyle(height: 1.7, fontSize: 13),
            ),
            if (result.cashWeight != null) ...[
              const SizedBox(height: 10),
              _ProgressRow(
                label: '보호 비율',
                value: result.cashWeight!,
                color: AppColors.negative,
              ),
              _ProgressRow(
                label: '주식 비율',
                value: 1.0 - result.cashWeight!,
                color: AppColors.positive,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ProgressRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Shared Small Widgets ──────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final AssetRole role;

  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      AssetRole.offensive => AppColors.primary,
      AssetRole.defensive => Colors.blueGrey,
      AssetRole.canary    => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ReturnText extends StatelessWidget {
  final double? value;

  const _ReturnText(this.value);

  @override
  Widget build(BuildContext context) {
    if (value == null) return const Text('-', style: TextStyle(fontSize: 12, color: Colors.grey));
    final pct = (value! * 100).toStringAsFixed(1);
    final color = value! > 0 ? AppColors.positive : (value! < 0 ? AppColors.negative : Colors.grey);
    final sign = value! > 0 ? '+' : '';
    return Text(
      '$sign$pct%',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    );
  }
}
