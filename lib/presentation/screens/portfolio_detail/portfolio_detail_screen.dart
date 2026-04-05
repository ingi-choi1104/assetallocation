import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../data/datasources/local/portfolio_strategy_local_ds.dart';
import '../../../domain/entities/asset.dart';
import '../../../domain/entities/dynamic_allocation.dart';
import '../../../domain/entities/investment.dart';
import '../../../domain/entities/portfolio.dart';
import '../../../domain/entities/portfolio_asset.dart';
import '../../../domain/enums/asset_type.dart';
import '../../providers/asset_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/dynamic_allocation_providers.dart';
import '../../providers/investment_providers.dart';
import '../../providers/metrics_providers.dart';
import '../../providers/portfolio_providers.dart';
import '../../providers/price_providers.dart';
import '../../../domain/services/financial_calculator.dart';

class PortfolioDetailScreen extends ConsumerWidget {
  final int portfolioId;

  const PortfolioDetailScreen({super.key, required this.portfolioId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioAsync = ref.watch(portfolioProvider(portfolioId));

    return portfolioAsync.when(
      data: (portfolio) {
        if (portfolio == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('포트폴리오')),
            body: const Center(child: Text('포트폴리오를 찾을 수 없습니다')),
          );
        }
        return _PortfolioDetailView(portfolio: portfolio);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _PortfolioDetailView extends ConsumerStatefulWidget {
  final Portfolio portfolio;

  const _PortfolioDetailView({required this.portfolio});

  @override
  ConsumerState<_PortfolioDetailView> createState() =>
      _PortfolioDetailViewState();
}

class _PortfolioDetailViewState extends ConsumerState<_PortfolioDetailView> {
  // Local sort order during/after drag — overrides stream until DB catches up
  List<PortfolioAsset>? _reorderedAssets;

  Portfolio get _portfolio => widget.portfolio;

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(portfolioMetricsProvider(_portfolio.id));
    final weightsAsync = ref.watch(portfolioWeightsProvider(_portfolio.id));
    final assetsAsync =
        ref.watch(portfolioAssetsStreamProvider(_portfolio.id));

    // Use local reorder state immediately; sync back to stream once DB matches
    final streamAssets = assetsAsync.value;
    List<PortfolioAsset> assets;
    if (_reorderedAssets != null && streamAssets != null) {
      final localIds = _reorderedAssets!.map((a) => a.id).join(',');
      final streamIds = streamAssets.map((a) => a.id).join(',');
      if (localIds == streamIds) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _reorderedAssets = null);
        });
      }
      assets = _reorderedAssets!;
    } else {
      assets = streamAssets ?? [];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_portfolio.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/portfolio/${_portfolio.id}/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'copy') {
                await _showCopyDialog(context, assets);
              } else if (v == 'delete') {
                final confirm = await _confirmDelete(context);
                if (confirm == true && context.mounted) {
                  await ref
                      .read(portfolioActionsProvider)
                      .delete(_portfolio.id);
                  if (context.mounted) context.pop();
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'copy',
                child: Text('포트폴리오 복사'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: assetsAsync.hasError
                ? const SizedBox.shrink()
                : (assetsAsync.isLoading && assets.isEmpty)
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBody(
                        context, assets, metricsAsync, weightsAsync),
          ),
          const SafeArea(top: false, child: BannerAdWidget()),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 52),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'investment',
              onPressed: () => _showInvestmentSheet(context, _portfolio.id),
              child: const Icon(Icons.attach_money),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'addAsset',
              onPressed: () =>
                  context.push('/portfolio/${_portfolio.id}/add-asset'),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  // ── 자산 순서 드래그 처리 ─────────────────────────────────────────────────────
  void _onReorder(List<PortfolioAsset> current, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final updated = List<PortfolioAsset>.from(current);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    setState(() => _reorderedAssets = updated);

    final idToSortOrder = <int, int>{
      for (int i = 0; i < updated.length; i++) updated[i].id: i,
    };
    ref.read(assetActionsProvider).updateSortOrders(idToSortOrder);
    HapticFeedback.lightImpact();
  }

  Widget _buildBody(
    BuildContext context,
    List<PortfolioAsset> assets,
    AsyncValue<PortfolioMetrics> metricsAsync,
    AsyncValue<List<RebalancingGap>> weightsAsync,
  ) {
    final gaps = weightsAsync.value ?? [];
    final gapMap = {for (final g in gaps) g.assetId: g};
    final totalWeight =
        assets.fold(0.0, (sum, pa) => sum + pa.targetWeight);
    final isIncomplete =
        assets.isNotEmpty && (totalWeight < 99.5 || totalWeight > 100.5);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 포트폴리오 미완성 경고 ─────────────────────────────────────────
          if (isIncomplete)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '포트폴리오 미완성 — 현재 ${totalWeight.toStringAsFixed(1)}% / 100%',
                      style: TextStyle(
                          fontSize: 13, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
          // ── 성과 지표 (최상단) ─────────────────────────────────────────────
          Builder(builder: (_) {
            final m = metricsAsync.valueOrNull;
            if (m == null) {
              return const Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            return Stack(
              children: [
                _MetricsCard(metrics: m, portfolioId: _portfolio.id),
                if (metricsAsync.isLoading)
                  const Positioned(
                    top: 12,
                    right: 24,
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            );
          }),

          // ── 자산 목록 (길게 눌러서 순서 변경) ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: Row(
              children: [
                Text(
                  '자산 목록',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 6),
                Text(
                  '길게 눌러 순서 변경',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: true,
            proxyDecorator: (child, index, animation) => Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: child,
            ),
            onReorder: (oldIndex, newIndex) =>
                _onReorder(assets, oldIndex, newIndex),
            children: [
              for (final pa in assets)
                _AssetListTile(
                  key: ValueKey(pa.id),
                  portfolioAsset: pa,
                  portfolioId: _portfolio.id,
                  gap: gapMap[pa.assetId],
                ),
            ],
          ),

          const SizedBox(height: 8),

          // ── 자산 배분 차트 ─────────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '자산 배분',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  assets.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('자산을 추가하세요'),
                          ),
                        )
                      : _AllocationChartsWidget(
                          assets: assets,
                          gaps: gaps,
                          isLoadingGaps: weightsAsync.isLoading,
                        ),
                ],
              ),
            ),
          ),

          // ── 리밸런싱 버튼 ──────────────────────────────────────────────────
          if (assets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () => context
                    .push('/portfolio/${_portfolio.id}/rebalance'),
                icon: const Icon(Icons.balance),
                label: const Text('리밸런싱'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),

          // ── 위험성 분석 / 시점 재생성 버튼 ────────────────────────────────
          if (assets.isNotEmpty)
            Builder(builder: (ctx) {
              final entry = ref.read(portfolioStrategyLocalDsProvider)
                  .getForPortfolio(_portfolio.id);

              if (entry != null) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showRegenerateSheet(context, entry, assets),
                    icon: const Icon(Icons.update),
                    label: const Text('시점 재생성'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (isIncomplete) {
                      showDialog(
                        context: context,
                        builder: (ctx2) => AlertDialog(
                          title: const Text('위험성 분석 불가'),
                          content: const Text(
                              '포트폴리오가 미완성 상태입니다.\n자산 비중 합계를 100%로 설정한 후 분석해주세요.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx2),
                              child: const Text('확인'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _RiskAnalysisSheet(
                          portfolioId: _portfolio.id,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('위험성 분석'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              );
            }),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('포트폴리오 삭제'),
          content: Text('${_portfolio.name}을(를) 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        ),
      );

  Future<void> _showCopyDialog(
    BuildContext context,
    List<PortfolioAsset> assets,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          _CopyNameDialog(defaultName: '${_portfolio.name} 복사본'),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;

    final now = DateTime.now();
    final newId = await ref.read(portfolioActionsProvider).create(
          Portfolio(
            id: 0,
            name: name.trim(),
            description: _portfolio.description,
            baseCurrency: _portfolio.baseCurrency,
            rebalancePeriod: _portfolio.rebalancePeriod,
            nextRebalanceDate: null,
            deviationThreshold: _portfolio.deviationThreshold,
            createdAt: now,
            updatedAt: now,
          ),
        );

    for (final pa in assets) {
      await ref.read(assetActionsProvider).addToPortfolio(
            portfolioId: newId,
            assetId: pa.assetId,
            targetWeight: pa.targetWeight,
            sortOrder: pa.sortOrder,
          );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${name.trim()} 으로 복사되었습니다')),
      );
    }
  }

  void _showInvestmentSheet(BuildContext context, int portfolioId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => _InvestmentSheet(
          portfolioId: portfolioId,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  void _showRegenerateSheet(
    BuildContext context,
    PortfolioStrategyEntry entry,
    List<PortfolioAsset> assets,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RegenerateSheet(
        portfolioId: _portfolio.id,
        entry: entry,
        currentAssets: assets,
      ),
    );
  }
}

/// 목표 배분과 현재 배분을 나란히 표시하는 이중 파이차트 위젯
class _AllocationChartsWidget extends StatelessWidget {
  final List<PortfolioAsset> assets;
  final List<RebalancingGap> gaps;
  final bool isLoadingGaps;

  const _AllocationChartsWidget({
    required this.assets,
    required this.gaps,
    required this.isLoadingGaps,
  });

  static const _titleStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    // assetId → 색상 인덱스 (두 차트 색상 일치)
    final colorIdx = <int, int>{};
    for (int i = 0; i < assets.length; i++) {
      colorIdx[assets[i].assetId] = i;
    }

    // 목표 배분 섹션 (항상 100% 기준)
    final targetSections = <PieChartSectionData>[];
    double totalTarget = 0;
    for (int i = 0; i < assets.length; i++) {
      final pa = assets[i];
      if (pa.targetWeight <= 0) continue;
      totalTarget += pa.targetWeight;
      targetSections.add(PieChartSectionData(
        value: pa.targetWeight,
        title: '${pa.targetWeight.toStringAsFixed(0)}%',
        color: AppColors.chartColors[i % AppColors.chartColors.length],
        radius: 52,
        titleStyle: _titleStyle,
      ));
    }
    if (totalTarget < 99.5) {
      targetSections.add(PieChartSectionData(
        value: 100 - totalTarget,
        title: '',
        color: Colors.grey.withValues(alpha: 0.15),
        radius: 52,
      ));
    }

    // 현재 배분 섹션 (항상 100% 기준)
    // 거래 내역이 있으면 실제 보유 기준, 없으면 포트폴리오 자산(목표) 기준으로 표시
    final currentSections = <PieChartSectionData>[];
    double totalCurrent = 0;
    if (gaps.isNotEmpty) {
      for (final gap in gaps) {
        if (gap.currentWeight <= 0) continue;
        totalCurrent += gap.currentWeight;
        final idx = colorIdx[gap.assetId] ?? 0;
        currentSections.add(PieChartSectionData(
          value: gap.currentWeight,
          title: '${gap.currentWeight.toStringAsFixed(0)}%',
          color: AppColors.chartColors[idx % AppColors.chartColors.length],
          radius: 52,
          titleStyle: _titleStyle,
        ));
      }
      if (totalCurrent < 99.5) {
        currentSections.add(PieChartSectionData(
          value: 100 - totalCurrent,
          title: '',
          color: Colors.grey.withValues(alpha: 0.15),
          radius: 52,
        ));
      }
    } else {
      // 거래 내역 없음 → 입력된 자산(목표 비율) 기준으로 표시
      for (int i = 0; i < assets.length; i++) {
        final pa = assets[i];
        if (pa.targetWeight <= 0) continue;
        totalCurrent += pa.targetWeight;
        currentSections.add(PieChartSectionData(
          value: pa.targetWeight,
          title: '${pa.targetWeight.toStringAsFixed(0)}%',
          color: AppColors.chartColors[i % AppColors.chartColors.length],
          radius: 52,
          titleStyle: _titleStyle,
        ));
      }
      if (totalCurrent < 99.5) {
        currentSections.add(PieChartSectionData(
          value: 100 - totalCurrent,
          title: '',
          color: Colors.grey.withValues(alpha: 0.15),
          radius: 52,
        ));
      }
    }
    final currentIsPlaceholder = gaps.isEmpty && assets.isNotEmpty;

    return Column(
      children: [
        // 두 차트 나란히
        SizedBox(
          height: 160,
          child: Row(
            children: [
              // 목표 배분
              Expanded(
                child: Column(
                  children: [
                    const Text('목표 배분',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sections: targetSections,
                          centerSpaceRadius: 22,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 구분선
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.grey.withValues(alpha: 0.2),
              ),
              // 현재 배분
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentIsPlaceholder ? '현재 배분*' : '현재 배분',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (isLoadingGaps) ...[
                          const SizedBox(width: 6),
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: currentSections.isNotEmpty
                          ? PieChart(
                              PieChartData(
                                sections: currentSections,
                                centerSpaceRadius: 22,
                                sectionsSpace: 2,
                              ),
                            )
                          : const Center(
                              child: Text(
                                '자산을 추가하세요',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (currentIsPlaceholder)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              '* 거래 미입력 — 목표 비율 기준',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        const SizedBox(height: 12),
        // 공유 범례
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (int i = 0; i < assets.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.chartColors[
                          i % AppColors.chartColors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    assets[i].asset?.symbol ??
                        assets[i].assetId.toString(),
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _MetricsCard extends ConsumerWidget {
  final PortfolioMetrics metrics;
  final int portfolioId;

  const _MetricsCard({required this.metrics, required this.portfolioId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(usdKrwRateSyncProvider);
    final showKrw = ref.watch(showKrwProvider);
    final dailyChange = ref.watch(portfolioDailyChangeProvider(portfolioId));
    final hasInvestments = metrics.totalInvested > 0;

    final returnColor = metrics.returnRate >= 0
        ? AppColors.positive
        : AppColors.negative;
    final annReturnColor = metrics.annualizedReturnRate >= 0
        ? AppColors.positive
        : AppColors.negative;

    final totalDisplay = showKrw
        ? CurrencyFormatter.format(metrics.totalValue, 'KRW')
        : CurrencyFormatter.format(metrics.totalValue / rate, 'USD');

    // Daily change formatting
    String? dailyChangeText;
    Color? dailyChangeColor;
    if (dailyChange != null) {
      final pct = dailyChange.percentChange;
      final amt = dailyChange.amountChange;
      final sign = pct >= 0 ? '+' : '';
      final amtSign = amt >= 0 ? '+' : '-';
      final amtStr = showKrw
          ? CurrencyFormatter.formatKrw(amt.abs())
          : CurrencyFormatter.formatUsd(amt.abs() / rate);
      dailyChangeText = '$amtSign$amtStr ($sign${pct.toStringAsFixed(2)}%)';
      dailyChangeColor = pct > 0
          ? AppColors.negative
          : (pct < 0 ? const Color(0xFF1565C0) : Colors.grey);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '성과 지표',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MetricItem(
                  label: '총 평가금액',
                  value: totalDisplay,
                  color: AppColors.neutral,
                ),
                if (hasInvestments)
                  _MetricItem(
                    label: '총 수익률',
                    value: CurrencyFormatter.formatSignedPercent(
                        metrics.returnRate * 100),
                    color: returnColor,
                  )
                else
                  const _MetricItem(
                    label: '총 수익률',
                    value: '투자금 미입력',
                    color: Colors.grey,
                  ),
              ],
            ),
            if (dailyChangeText != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _MetricItem(
                    label: '일간 변동',
                    value: dailyChangeText,
                    color: dailyChangeColor!,
                  ),
                  if (hasInvestments)
                    _MetricItem(
                      label: '연평균 수익률',
                      value: CurrencyFormatter.formatSignedPercent(
                          metrics.annualizedReturnRate * 100),
                      color: annReturnColor,
                    ),
                ],
              ),
            ] else if (hasInvestments) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _MetricItem(
                    label: '투자금',
                    value: showKrw
                        ? CurrencyFormatter.formatKrw(metrics.totalInvested)
                        : CurrencyFormatter.formatUsd(
                            metrics.totalInvested / rate),
                    color: AppColors.neutral,
                  ),
                  _MetricItem(
                    label: '연평균 수익률',
                    value: CurrencyFormatter.formatSignedPercent(
                        metrics.annualizedReturnRate * 100),
                    color: annReturnColor,
                  ),
                ],
              ),
            ],
            if (dailyChangeText != null && hasInvestments) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _MetricItem(
                    label: '투자금',
                    value: showKrw
                        ? CurrencyFormatter.formatKrw(metrics.totalInvested)
                        : CurrencyFormatter.formatUsd(
                            metrics.totalInvested / rate),
                    color: AppColors.neutral,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetListTile extends ConsumerWidget {
  final PortfolioAsset portfolioAsset;
  final int portfolioId;
  final RebalancingGap? gap;

  const _AssetListTile({
    super.key,
    required this.portfolioAsset,
    required this.portfolioId,
    this.gap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = portfolioAsset.asset;
    final showKrw = ref.watch(showKrwProvider);
    final rate = ref.watch(usdKrwRateSyncProvider);
    final priceChange = ref.watch(priceChangeProvider(portfolioAsset.assetId));

    // gap.currentValue is always in KRW (provider converts USD → KRW)
    final hasHoldings = (gap?.currentValue ?? 0) > 0;
    final krwValue = gap?.currentValue ?? 0;
    final isUsd = (asset?.currency ?? 'KRW').toUpperCase() == 'USD';
    final nativeValue = isUsd ? krwValue / rate : krwValue;
    final nativeCurrency = asset?.currency ?? 'KRW';

    // 한국 주식은 이름이 메인, 코드번호가 서브
    final isKrStock = asset?.assetType == AssetType.krStock;
    final titleText = isKrStock
        ? (asset?.name ?? asset?.symbol ?? 'Unknown')
        : (asset?.symbol ?? 'Unknown');
    final subtitleText =
        isKrStock ? (asset?.symbol ?? '') : (asset?.name ?? '');

    // ── 시세 (현재가 + 전일대비) ──────────────────────────────────────────────
    String? marketPriceText;
    String? changeText;
    Color? changeColor;
    if (priceChange != null) {
      final cp = priceChange.currentPrice;
      marketPriceText = showKrw
          ? (isUsd
              ? CurrencyFormatter.format(cp * rate, 'KRW')
              : CurrencyFormatter.format(cp, nativeCurrency))
          : CurrencyFormatter.format(cp, nativeCurrency);

      if (priceChange.changePercent != null) {
        final pct = priceChange.changePercent!;
        final sign = pct >= 0 ? '+' : '';
        changeText = '$sign${pct.toStringAsFixed(2)}%';
        changeColor =
            pct > 0 ? AppColors.negative : (pct < 0 ? const Color(0xFF1565C0) : Colors.grey);
      }
    } else if (asset?.lastPrice != null) {
      final lp = asset!.lastPrice!;
      marketPriceText = showKrw
          ? (isUsd
              ? CurrencyFormatter.format(lp * rate, 'KRW')
              : CurrencyFormatter.format(lp, nativeCurrency))
          : CurrencyFormatter.format(lp, nativeCurrency);
    }

    // ── 자산 (보유 평가금액) ──────────────────────────────────────────────
    String? holdingText;
    if (hasHoldings) {
      holdingText = showKrw
          ? CurrencyFormatter.format(krwValue, 'KRW')
          : CurrencyFormatter.format(nativeValue, nativeCurrency);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => context
            .push('/portfolio/$portfolioId/asset/${portfolioAsset.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // ── 왼쪽: 이름 / 코드 ─────────────────────────────────────────
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitleText.isNotEmpty)
                      Text(
                        subtitleText,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── 시세 ──────────────────────────────────────────────────────
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('시세',
                        style: TextStyle(fontSize: 9, color: Colors.grey)),
                    if (marketPriceText != null)
                      Text(
                        marketPriceText,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    if (changeText != null)
                      Text(
                        changeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: changeColor,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.grey.withValues(alpha: 0.2),
              ),
              // ── 자산 ──────────────────────────────────────────────────────
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('자산',
                        style: TextStyle(fontSize: 9, color: Colors.grey)),
                    if (holdingText != null)
                      Text(
                        holdingText,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      )
                    else
                      const Text('-',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    // 비중 표시: 목표 vs 현재 (탭하면 목표 비중 수정)
                    GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => _EditWeightDialog(
                          portfolioAsset: portfolioAsset,
                        ),
                      ),
                      child: Text(
                        hasHoldings
                            ? '${gap!.currentWeight.toStringAsFixed(1)}% / ${portfolioAsset.targetWeight.toStringAsFixed(1)}%'
                            : '목표 ${portfolioAsset.targetWeight.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: hasHoldings
                              ? _weightColor(
                                  gap!.currentWeight,
                                  portfolioAsset.targetWeight,
                                )
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _weightColor(double current, double target) {
    const tolerance = 0.05;
    if (current > target + tolerance) return AppColors.negative;
    if (current < target - tolerance) return const Color(0xFF1565C0);
    return AppColors.positive;
  }
}

// ── 투자금 바텀시트 (목록 + 추가/수정/삭제) ─────────────────────────────────
class _InvestmentSheet extends ConsumerWidget {
  final int portfolioId;
  final ScrollController scrollController;

  const _InvestmentSheet({
    required this.portfolioId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investmentsAsync =
        ref.watch(investmentsStreamProvider(portfolioId));

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('투자금 내역',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: '투자금 추가',
                onPressed: () => _showForm(context, ref),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List
        Expanded(
          child: investmentsAsync.when(
            data: (investments) {
              if (investments.isEmpty) {
                return const Center(
                  child: Text('투자금 내역이 없습니다',
                      style: TextStyle(color: Colors.grey)),
                );
              }
              final total =
                  investments.fold(0.0, (sum, i) => sum + i.amount);
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('총 투자금',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(CurrencyFormatter.formatKrw(total),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const Divider(height: 24),
                  ...investments.map((inv) => _InvestmentTile(
                        investment: inv,
                        onEdit: () => _showForm(context, ref, existing: inv),
                      )),
                ],
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  void _showForm(BuildContext context, WidgetRef ref,
      {Investment? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _InvestmentFormDialog(
        portfolioId: portfolioId,
        existing: existing,
      ),
    );
  }
}

class _InvestmentTile extends ConsumerWidget {
  final Investment investment;
  final VoidCallback onEdit;

  const _InvestmentTile({
    required this.investment,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = investment.investmentDate;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Date
          Text(dateStr,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 12),
          // Amount
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CurrencyFormatter.formatKrw(investment.amount),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (investment.memo != null && investment.memo!.isNotEmpty)
                  Text(
                    investment.memo!,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Edit
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: '수정',
            onPressed: onEdit,
          ),
          // Delete
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.red.withValues(alpha: 0.7), size: 18),
            tooltip: '삭제',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('투자금 삭제'),
        content: const Text('이 투자금 내역을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(investmentActionsProvider).delete(investment.id);
    }
  }
}

// ── 투자금 입력/수정 다이얼로그 ──────────────────────────────────────────────
class _InvestmentFormDialog extends ConsumerStatefulWidget {
  final int portfolioId;
  final Investment? existing;

  const _InvestmentFormDialog({
    required this.portfolioId,
    this.existing,
  });

  @override
  ConsumerState<_InvestmentFormDialog> createState() =>
      _InvestmentFormDialogState();
}

class _InvestmentFormDialogState
    extends ConsumerState<_InvestmentFormDialog> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _memoCtrl;
  late DateTime _date;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountCtrl = TextEditingController(
      text: e != null
          ? _ThousandsSeparatorInputFormatter.format(e.amount.toInt())
          : '',
    );
    _memoCtrl = TextEditingController(text: e?.memo ?? '');
    _date = e?.investmentDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

    return AlertDialog(
      title: Text(_isEditing ? '투자금 수정' : '투자금 입력'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('투자 날짜'),
              subtitle: Text(dateStr),
              trailing: const Icon(Icons.calendar_today, size: 20),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 8),
            // Amount
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: '투자 금액 (원)',
                hintText: '예: 1,000,000',
                suffixText: '원',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [_ThousandsSeparatorInputFormatter()],
            ),
            const SizedBox(height: 8),
            // Memo
            TextField(
              controller: _memoCtrl,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final rawText = _amountCtrl.text.replaceAll(',', '');
    final amount = double.tryParse(rawText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유효한 금액을 입력하세요')),
      );
      return;
    }

    final memo = _memoCtrl.text.isEmpty ? null : _memoCtrl.text;
    final actions = ref.read(investmentActionsProvider);

    if (_isEditing) {
      await actions.update(
        id: widget.existing!.id,
        amount: amount,
        date: _date,
        memo: memo,
      );
    } else {
      await actions.add(
        portfolioId: widget.portfolioId,
        amount: amount,
        date: _date,
        memo: memo,
      );
    }

    if (mounted) Navigator.pop(context);
  }
}

// ── 자산 순서 편집 다이얼로그 ──────────────────────────────────────────────────
class _ReorderAssetsDialog extends ConsumerStatefulWidget {
  final List<PortfolioAsset> assets;

  const _ReorderAssetsDialog({required this.assets});

  @override
  ConsumerState<_ReorderAssetsDialog> createState() =>
      _ReorderAssetsDialogState();
}

class _ReorderAssetsDialogState extends ConsumerState<_ReorderAssetsDialog> {
  late List<PortfolioAsset> _ordered;

  @override
  void initState() {
    super.initState();
    _ordered = List.of(widget.assets);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('자산 순서 편집'),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ReorderableListView.builder(
          shrinkWrap: true,
          itemCount: _ordered.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _ordered.removeAt(oldIndex);
              _ordered.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final pa = _ordered[index];
            final asset = pa.asset;
            final isKr = asset?.assetType == AssetType.krStock;
            final title = isKr
                ? (asset?.name ?? asset?.symbol ?? '?')
                : (asset?.symbol ?? '?');
            final subtitle = isKr ? (asset?.symbol ?? '') : (asset?.name ?? '');

            return ListTile(
              key: ValueKey(pa.id),
              leading: Icon(Icons.drag_handle, color: Colors.grey.shade400),
              title: Text(title, style: const TextStyle(fontSize: 14)),
              subtitle: subtitle.isNotEmpty
                  ? Text(subtitle, style: const TextStyle(fontSize: 12))
                  : null,
              trailing: Text(
                '${pa.targetWeight.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final idToSortOrder = <int, int>{};
    for (int i = 0; i < _ordered.length; i++) {
      idToSortOrder[_ordered[i].id] = i;
    }
    await ref.read(assetActionsProvider).updateSortOrders(idToSortOrder);
    if (mounted) Navigator.pop(context);
  }
}

// ── 포트폴리오 복사 이름 입력 다이얼로그 ─────────────────────────────────────
class _CopyNameDialog extends StatefulWidget {
  final String defaultName;

  const _CopyNameDialog({required this.defaultName});

  @override
  State<_CopyNameDialog> createState() => _CopyNameDialogState();
}

class _CopyNameDialogState extends State<_CopyNameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.defaultName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('포트폴리오 복사'),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(labelText: '새 포트폴리오 이름'),
        autofocus: true,
        onSubmitted: (_) => Navigator.pop(context, _ctrl.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('복사'),
        ),
      ],
    );
  }
}

// ── 숫자 세자리마다 콤마 포매터 ────────────────────────────────────────────────
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    final formatted = format(int.parse(raw));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String format(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── 목표 비중 수정 다이얼로그 ─────────────────────────────────────────────────
class _EditWeightDialog extends ConsumerStatefulWidget {
  final PortfolioAsset portfolioAsset;

  const _EditWeightDialog({required this.portfolioAsset});

  @override
  ConsumerState<_EditWeightDialog> createState() => _EditWeightDialogState();
}

class _EditWeightDialogState extends ConsumerState<_EditWeightDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.portfolioAsset.targetWeight.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.portfolioAsset.asset?.symbol ?? widget.portfolioAsset.assetId.toString()} 목표 비중',
      ),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          labelText: '목표 비중',
          suffixText: '%',
        ),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final weight = double.tryParse(_ctrl.text);
    if (weight == null || weight < 0 || weight > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('0~100 사이의 값을 입력하세요')),
      );
      return;
    }
    await ref
        .read(assetActionsProvider)
        .updateWeight(widget.portfolioAsset.id, weight);
    if (mounted) Navigator.pop(context);
  }
}

// ── 위험성 분석 바텀시트 ────────────────────────────────────────────────────
class _RiskAnalysisSheet extends ConsumerStatefulWidget {
  final int portfolioId;

  const _RiskAnalysisSheet({required this.portfolioId});

  @override
  ConsumerState<_RiskAnalysisSheet> createState() =>
      _RiskAnalysisSheetState();
}

class _RiskAnalysisSheetState extends ConsumerState<_RiskAnalysisSheet> {
  DateTime _startDate = DateTime(
    DateTime.now().year - 3,
    DateTime.now().month,
    DateTime.now().day,
  );
  String _period = 'quarterly';
  RiskAnalysisInput? _input;

  static const _periodLabel = {
    'monthly': '매월',
    'quarterly': '분기',
    'yearly': '매년',
  };

  @override
  Widget build(BuildContext context) {
    final riskAsync =
        _input != null ? ref.watch(riskAnalysisProvider(_input!)) : null;

    final dateStr =
        '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text(
            '위험성 분석',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '포트폴리오 목표 비율대로 투자했다고 가정했을 때의 MDD와 연간 변동성을 계산합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          // ── 시작 날짜 ────────────────────────────────────────────────────
          const Text('시작 날짜',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().subtract(const Duration(days: 31)),
              );
              if (d != null) setState(() => _startDate = d);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16,
                      color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(dateStr,
                      style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 리밸런싱 주기 ─────────────────────────────────────────────────
          const Text('리밸런싱 주기',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'monthly', label: Text('매월')),
              ButtonSegment(value: 'quarterly', label: Text('분기')),
              ButtonSegment(value: 'yearly', label: Text('매년')),
            ],
            selected: {_period},
            onSelectionChanged: (s) =>
                setState(() => _period = s.first),
          ),
          const SizedBox(height: 16),

          // ── 계산 버튼 ────────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: (riskAsync?.isLoading ?? false)
                ? null
                : () {
                    setState(() {
                      _input = RiskAnalysisInput(
                        portfolioId: widget.portfolioId,
                        startDate: _startDate,
                        rebalancePeriod: _period,
                      );
                    });
                  },
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('계산하기'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          // ── 결과 ─────────────────────────────────────────────────────────
          if (riskAsync != null) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            riskAsync.when(
              data: (risk) {
                if (risk == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '계산 결과 없음',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '다음 중 하나에 해당할 수 있습니다:',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        ...[
                          '• 시작일이 너무 최근 (30일 이상 이전이어야 함)',
                          '• 가상화폐·국내 펀드는 역사 데이터 미지원',
                          '• Yahoo Finance / Naver 가격 조회 실패 (네트워크 오류 또는 일시적 제한)',
                          '• 해당 자산의 상장일이 시작일보다 늦음',
                        ].map((t) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(t,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                            )),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ResultItem(
                            label: 'MDD',
                            value:
                                '${(risk.mdd * 100).toStringAsFixed(2)}%',
                            color: AppColors.negative,
                            description: '최대 낙폭',
                          ),
                        ),
                        Expanded(
                          child: _ResultItem(
                            label: '연간 변동성 (σ)',
                            value:
                                '${(risk.stdDev * 100).toStringAsFixed(2)}%',
                            color: AppColors.neutral,
                            description: '연환산 표준편차',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '* $dateStr 시작, ${_periodLabel[_period]} 리밸런싱 기준',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '계산 중 오류가 발생했습니다. 네트워크를 확인해주세요.',
                  style: TextStyle(color: Colors.red.shade400),
                ),
              ),
            ),
          ],
        ],
      ),
    ),   // SingleChildScrollView 닫기
    );   // SafeArea 닫기
  }
}

class _ResultItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String description;

  const _ResultItem({
    required this.label,
    required this.value,
    required this.color,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(description,
            style:
                const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ── 시점 재생성 시트 ────────────────────────────────────────────────────────────

class _RegenerateSheet extends ConsumerStatefulWidget {
  final int portfolioId;
  final PortfolioStrategyEntry entry;
  final List<PortfolioAsset> currentAssets;

  const _RegenerateSheet({
    required this.portfolioId,
    required this.entry,
    required this.currentAssets,
  });

  @override
  ConsumerState<_RegenerateSheet> createState() => _RegenerateSheetState();
}

class _RegenerateSheetState extends ConsumerState<_RegenerateSheet> {
  late DateTime _selectedDate;
  bool _isCalculating = false;
  StrategyResult? _result;
  String? _error;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  DynamicStrategyType get _strategyType => DynamicStrategyType.values.firstWhere(
        (t) => t.name == widget.entry.strategyType,
        orElse: () => DynamicStrategyType.vaa,
      );

  String _fmt(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  Future<void> _calculate() async {
    setState(() {
      _isCalculating = true;
      _result = null;
      _error = null;
    });
    try {
      final config = DynamicStrategyConfig.defaultFor(
        _strategyType,
        date: _selectedDate,
      );
      final priceDs = ref.read(dynamicPriceDsProvider);
      final service = ref.read(dynamicAllocationServiceProvider);
      final priceData =
          await priceDs.fetchMonthlyPrices(config.symbols, config.calculationDate);
      final result = service.calculate(config, priceData);
      if (mounted) setState(() { _result = result; _isCalculating = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isCalculating = false; });
    }
  }

  Future<void> _applyUpdate() async {
    final result = _result;
    if (result == null) return;
    setState(() => _isApplying = true);

    try {
      final assetActions = ref.read(assetActionsProvider);
      final assetRepo = ref.read(assetRepositoryProvider);
      final existing = widget.currentAssets;

      // Map existing portfolio assets by symbol (uppercase)
      final existingBySymbol = <String, PortfolioAsset>{
        for (final pa in existing)
          if (pa.asset?.symbol != null) pa.asset!.symbol.toUpperCase(): pa,
      };

      // Symbols that appear in the new allocation
      final newSymbols = result.allocations
          .map((a) => a.symbol.toUpperCase())
          .toSet();

      // For assets NOT in new allocation: remove if no holdings, else set weight 0
      for (final pa in existing) {
        final symbol = pa.asset?.symbol.toUpperCase() ?? '';
        if (!newSymbols.contains(symbol)) {
          final txs = await assetRepo.getTransactions(pa.id);
          final holdings = FinancialCalculator.calculateHoldings(transactions: txs);
          if (holdings.abs() < 0.000001) {
            await assetActions.removeFromPortfolio(pa.id);
          } else {
            await assetActions.updateWeight(pa.id, 0.0);
          }
        }
      }

      // Apply new allocations
      for (int i = 0; i < result.allocations.length; i++) {
        final alloc = result.allocations[i];
        final symbol = alloc.symbol.toUpperCase();
        final newWeight = alloc.weight * 100; // fraction → %

        final existingPa = existingBySymbol[symbol];
        if (existingPa != null) {
          // Update existing asset weight
          await assetActions.updateWeight(existingPa.id, newWeight);
        } else {
          // Add new asset
          final dbAsset = await assetRepo.getAssetBySymbolAndType(
              alloc.symbol, AssetType.usStock.value);
          final int assetId;
          if (dbAsset != null) {
            assetId = dbAsset.id;
          } else {
            assetId = await assetActions.upsertAsset(Asset(
              id: 0,
              symbol: alloc.symbol,
              name: alloc.name,
              assetType: AssetType.usStock,
              currency: 'USD',
              createdAt: DateTime.now(),
            ));
          }
          await assetActions.addToPortfolio(
            portfolioId: widget.portfolioId,
            assetId: assetId,
            targetWeight: newWeight,
            sortOrder: existing.length + i,
          );
        }
      }

      // Save new calculation date
      await ref.read(portfolioStrategyLocalDsProvider).save(
            PortfolioStrategyEntry(
              portfolioId: widget.portfolioId,
              strategyType: widget.entry.strategyType,
              calculationDate: _selectedDate,
            ),
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_fmt(_selectedDate)} 기준으로 포트폴리오가 업데이트되었습니다'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('업데이트 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = _strategyType;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      type.displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '시점 재생성',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '직전 기준일: ${_fmt(widget.entry.calculationDate)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2010, 1, 1),
                    lastDate: DateTime.now(),
                    helpText: '새 기준 날짜',
                    confirmText: '선택',
                    cancelText: '취소',
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '새 기준 날짜',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                            Text(
                              '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit_outlined,
                          size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Calculate button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCalculating ? null : _calculate,
                  icon: _isCalculating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.calculate_outlined),
                  label: Text(_isCalculating ? '계산 중...' : '전략 계산'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '계산 실패: $_error',
                          style: TextStyle(
                              fontSize: 12, color: Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Result
              if (_result != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _result!.isOffensive
                            ? AppColors.positive
                            : AppColors.negative,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _result!.regime,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _result!.isOffensive
                            ? AppColors.positive
                            : AppColors.negative,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '새 배분 결과',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ..._result!.allocations.map(
                  (a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: a.isDefensive
                                ? Colors.blueGrey
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          a.symbol,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            a.name,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(a.weight * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Apply button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isApplying ? null : _applyUpdate,
                    icon: _isApplying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.update),
                    label: Text(_isApplying
                        ? '업데이트 중...'
                        : '${_fmt(_selectedDate)} 기준으로 포트폴리오 업데이트'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '기존 거래 내역은 유지됩니다',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
