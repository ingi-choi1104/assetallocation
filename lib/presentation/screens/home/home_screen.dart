import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../providers/metrics_providers.dart';
import '../../providers/portfolio_bundle_providers.dart';
import '../../providers/portfolio_providers.dart';
import '../../providers/price_providers.dart';
import '../../../domain/entities/portfolio.dart';
import '../../../domain/entities/portfolio_bundle.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedTab = 0;

  static const _tabs = [
    NavigationDestination(
      icon: Icon(Icons.pie_chart_outline),
      selectedIcon: Icon(Icons.pie_chart),
      label: '포트폴리오',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: '설정',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: const [
          _PortfolioListTab(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        destinations: _tabs,
      ),
    );
  }
}

// ── Portfolio List Tab ────────────────────────────────────────────────────────
class _PortfolioListTab extends ConsumerWidget {
  const _PortfolioListTab();

  Future<void> _showPortfolioTypeSheet(BuildContext context) async {
    // Await the sheet's result so the sheet is fully gone before we navigate.
    // Calling Navigator.pop + context.push synchronously causes a
    // '_dependents.isEmpty' assertion in Flutter's element lifecycle.
    final choice = await showModalBottomSheet<_PortfolioType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '포트폴리오 유형 선택',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _TypeTile(
                icon: Icons.bar_chart,
                title: '정적 포트폴리오',
                subtitle: '목표 비중을 직접 설정하고 리밸런싱합니다',
                onTap: () =>
                    Navigator.pop(sheetCtx, _PortfolioType.static_),
              ),
              const SizedBox(height: 10),
              _TypeTile(
                icon: Icons.auto_graph,
                title: '동적 포트폴리오',
                subtitle: '계량 전략(VAA, PAA, GTAA 등)으로 비중을 자동 산출합니다',
                onTap: () =>
                    Navigator.pop(sheetCtx, _PortfolioType.dynamic),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _PortfolioType.static_:
        context.push('/portfolio/new');
      case _PortfolioType.dynamic:
        context.push('/dynamic-allocation');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeItemsAsync = ref.watch(homeItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('자산배분 헬퍼'),
        actions: [
          _CurrencyToggleChips(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: '순서 편집',
            onPressed: () {
              final items = homeItemsAsync.value;
              if (items != null && items.length > 1) {
                showDialog(
                  context: context,
                  builder: (_) =>
                      _ReorderHomeItemsDialog(items: items),
                );
              }
            },
          ),
          IconButton(
            icon: ref.watch(syncNotifierProvider).isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: () => ref.read(syncNotifierProvider.notifier).syncAll(),
            tooltip: '가격 동기화',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: homeItemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptyPortfoliosView();
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    const _GlobalSummaryCard(),
                    const SizedBox(height: 4),
                    // ── 드래그-병합 안내 배너 (포트폴리오 2개 이상일 때만) ─
                    if (items.whereType<HomePortfolioItem>().length >= 2)
                      const _DragHintBanner(),
                    // ── 묶음 카드 ────────────────────────────────────────
                    ...items.map((item) => switch (item) {
                          HomePortfolioItem(:final portfolio) =>
                            _DraggablePortfolioCard(portfolio: portfolio),
                          HomeBundleItem(:final bundle, :final portfolios) =>
                            _BundleCard(bundle: bundle, portfolios: portfolios),
                        }),
                    const SizedBox(height: 80),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          // 배너 광고: 항상 목록 하단에 고정
          const BannerAdWidget(),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: FloatingActionButton.extended(
          heroTag: 'new_portfolio_fab',
          onPressed: () => _showPortfolioTypeSheet(context),
          icon: const Icon(Icons.add),
          label: const Text('포트폴리오 추가'),
        ),
      ),
    );
  }
}

// ── 전체 포트폴리오 합산 요약 카드 ────────────────────────────────────────────
class _GlobalSummaryCard extends ConsumerWidget {
  const _GlobalSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(globalMetricsProvider);
    final showKrw = ref.watch(showKrwProvider);
    final rate = ref.watch(usdKrwRateSyncProvider);
    final dailyChange = ref.watch(globalDailyChangeProvider);

    final m = metricsAsync.valueOrNull;
    if (m == null) {
      if (metricsAsync.isLoading) {
        return const Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            height: 100,
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        );
      }
      return const SizedBox.shrink();
    }
    if (m.totalValue == 0 && m.totalInvested == 0) {
      return const SizedBox.shrink();
    }
    final hasInvestments = m.totalInvested > 0;
    final returnColor = m.returnRate >= 0
        ? AppColors.positive
        : AppColors.negative;
    final annReturnColor = m.annualizedReturnRate >= 0
        ? AppColors.positive
        : AppColors.negative;

    final valueDisplay = showKrw
        ? CurrencyFormatter.formatKrw(m.totalValue)
        : CurrencyFormatter.formatUsd(m.totalValue / rate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('전체 포트폴리오',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey)),
                if (metricsAsync.isLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              valueDisplay,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (dailyChange != null) ...[
              const SizedBox(height: 2),
              _DailyChangeText(
                change: dailyChange,
                showKrw: showKrw,
                rate: rate,
              ),
            ],
            if (hasInvestments) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '수익률 ${CurrencyFormatter.formatSignedPercent(m.returnRate * 100)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: returnColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '연평균 ${CurrencyFormatter.formatSignedPercent(m.annualizedReturnRate * 100)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: annReturnColor,
                    ),
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

class _EmptyPortfoliosView extends StatelessWidget {
  const _EmptyPortfoliosView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '포트폴리오가 없습니다',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '+ 버튼을 눌러 포트폴리오를 만들어보세요',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioCard extends ConsumerWidget {
  final Portfolio portfolio;

  const _PortfolioCard({required this.portfolio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync =
        ref.watch(portfolioMetricsProvider(portfolio.id));
    final showKrw = ref.watch(showKrwProvider);
    final rate = ref.watch(usdKrwRateSyncProvider);
    final dailyChange =
        ref.watch(portfolioDailyChangeProvider(portfolio.id));
    final isExcluded = ref.watch(
        excludedPortfoliosProvider.select((s) => s.contains(portfolio.id)));

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Tooltip(
          message: isExcluded ? '전체 합산에서 제외됨 (탭하여 포함)' : '탭하면 전체 합산에서 제외',
          child: GestureDetector(
            onTap: () => ref
                .read(excludedPortfoliosProvider.notifier)
                .toggle(portfolio.id),
            child: CircleAvatar(
              backgroundColor: isExcluded
                  ? Colors.grey.shade300
                  : Theme.of(context).colorScheme.primaryContainer,
              child: isExcluded
                  ? Icon(Icons.remove_circle_outline,
                      size: 18, color: Colors.grey.shade500)
                  : Text(
                      portfolio.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
        title: Text(
          portfolio.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: _buildPortfolioSubtitle(
          metricsAsync, dailyChange, showKrw, rate),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (metricsAsync.isLoading && metricsAsync.hasValue)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () =>
            context.push('/portfolio/${portfolio.id}'),
      ),
    );
  }

  static Widget? _buildPortfolioSubtitle(
    AsyncValue<PortfolioMetrics> metricsAsync,
    DailyChange? dailyChange,
    bool showKrw,
    double rate,
  ) {
    final m = metricsAsync.valueOrNull;
    if (m == null) return null;
    if (m.totalValue == 0) return null;
    final valueStr = showKrw
        ? CurrencyFormatter.formatKrw(m.totalValue)
        : CurrencyFormatter.formatUsd(m.totalValue / rate);
    final hasReturn = m.totalInvested > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasReturn
              ? '$valueStr  ${CurrencyFormatter.formatSignedPercent(m.returnRate * 100)}'
              : valueStr,
          style: TextStyle(
            fontSize: 12,
            color: hasReturn
                ? (m.returnRate >= 0
                    ? AppColors.positive
                    : AppColors.negative)
                : null,
          ),
        ),
        if (dailyChange != null)
          _DailyChangeText(
            change: dailyChange,
            showKrw: showKrw,
            rate: rate,
            fontSize: 11,
          ),
      ],
    );
  }
}

/// Reusable daily change text widget
class _DailyChangeText extends StatelessWidget {
  final DailyChange change;
  final bool showKrw;
  final double rate;
  final double fontSize;

  const _DailyChangeText({
    required this.change,
    required this.showKrw,
    required this.rate,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final pct = change.percentChange;
    final amt = change.amountChange;
    // + → red (상승), - → blue (하락)
    final color = pct > 0
        ? AppColors.negative
        : (pct < 0 ? const Color(0xFF1565C0) : Colors.grey);
    final sign = pct >= 0 ? '+' : '';

    final amtStr = showKrw
        ? CurrencyFormatter.formatKrw(amt.abs())
        : CurrencyFormatter.formatUsd(amt.abs() / rate);
    final amtSign = amt >= 0 ? '+' : '-';

    return Text(
      '($amtSign$amtStr / $sign${pct.toStringAsFixed(2)}%)',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

// ── 통화 전환 칩 (AppBar용) ─────────────────────────────────────────────────
class _CurrencyToggleChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showKrw = ref.watch(showKrwProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SmallChip(
          label: 'USD',
          selected: !showKrw,
          onTap: () => ref.read(showKrwProvider.notifier).toggle(false),
        ),
        const SizedBox(width: 4),
        _SmallChip(
          label: 'KRW',
          selected: showKrw,
          onTap: () => ref.read(showKrwProvider.notifier).toggle(true),
        ),
      ],
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SmallChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ── 홈 아이템 순서 편집 다이얼로그 (포트폴리오 + 묶음 통합) ──────────────────
class _ReorderHomeItemsDialog extends ConsumerStatefulWidget {
  final List<HomeItem> items;

  const _ReorderHomeItemsDialog({required this.items});

  @override
  ConsumerState<_ReorderHomeItemsDialog> createState() =>
      _ReorderHomeItemsDialogState();
}

class _ReorderHomeItemsDialogState
    extends ConsumerState<_ReorderHomeItemsDialog> {
  late List<_OrderEntry> _ordered;

  @override
  void initState() {
    super.initState();
    _ordered = widget.items.map((item) {
      return switch (item) {
        HomePortfolioItem(:final portfolio) => _OrderEntry(
            key: 'p:${portfolio.id}',
            name: portfolio.name,
            icon: Icons.pie_chart_outline,
            count: 0,
          ),
        HomeBundleItem(:final bundle, :final portfolios) => _OrderEntry(
            key: 'b:${bundle.id}',
            name: bundle.name,
            icon: Icons.folder_outlined,
            count: portfolios.length,
          ),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('순서 편집'),
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
            final entry = _ordered[index];
            return ListTile(
              key: ValueKey(entry.key),
              leading: Icon(Icons.drag_handle, color: Colors.grey.shade400),
              title: Text(entry.name, style: const TextStyle(fontSize: 14)),
              trailing: entry.count > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${entry.count}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700)),
                    )
                  : null,
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
          onPressed: () {
            ref
                .read(homeOrderProvider.notifier)
                .updateOrder(_ordered.map((e) => e.key).toList());
            Navigator.pop(context);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _OrderEntry {
  final String key;
  final String name;
  final IconData icon;
  final int count;

  const _OrderEntry({
    required this.key,
    required this.name,
    required this.icon,
    required this.count,
  });
}

// ── 드래그 힌트 배너 ──────────────────────────────────────────────────────────
class _DragHintBanner extends StatelessWidget {
  const _DragHintBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '카드를 길게 눌러 다른 카드에 겹치면 묶음이 만들어져요',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Draggable Portfolio Card (LongPressDraggable + DragTarget) ─────────────────
class _DraggablePortfolioCard extends ConsumerWidget {
  final Portfolio portfolio;

  const _DraggablePortfolioCard({required this.portfolio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LongPressDraggable<int>(
      data: portfolio.id,
      hapticFeedbackOnStart: true,
      feedback: _DragFeedback(name: portfolio.name),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: IgnorePointer(child: _PortfolioCard(portfolio: portfolio)),
      ),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != portfolio.id,
        onAcceptWithDetails: (details) =>
            _handleDrop(context, ref, droppedId: details.data),
        builder: (context, candidates, _) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: candidates.isNotEmpty
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1565C0), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                )
              : null,
          child: _PortfolioCard(portfolio: portfolio),
        ),
      ),
    );
  }

  void _handleDrop(BuildContext context, WidgetRef ref, {required int droppedId}) {
    // Auto-name from both portfolio names
    final bundles = ref.read(portfolioBundleNotifierProvider);
    final portfoliosAsync = ref.read(sortedPortfoliosProvider);
    final allPortfolios = portfoliosAsync.value ?? [];

    // Find the dragged portfolio's name for a descriptive default name
    String droppedName = '';
    for (final p in allPortfolios) {
      if (p.id == droppedId) { droppedName = p.name; break; }
    }
    final bundleName = droppedName.isNotEmpty
        ? '${droppedName.split('').take(6).join()} + ${portfolio.name.split('').take(6).join()}'
        : '묶음 ${bundles.length + 1}';

    ref.read(portfolioBundleNotifierProvider.notifier)
        .createBundle([portfolio.id, droppedId], bundleName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('묶음이 만들어졌습니다. 묶음 이름을 탭해서 변경할 수 있어요.'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(label: '확인', onPressed: () {}),
      ),
    );
  }
}

// ── Drag Feedback Widget ──────────────────────────────────────────────────────
class _DragFeedback extends StatelessWidget {
  final String name;

  const _DragFeedback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              radius: 16,
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.drag_indicator, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Bundle Card ───────────────────────────────────────────────────────────────
class _BundleCard extends ConsumerWidget {
  final PortfolioBundle bundle;
  final List<Portfolio> portfolios;

  const _BundleCard({required this.bundle, required this.portfolios});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Aggregate total value and daily change across all member portfolios
    double totalValue = 0;
    double totalInvested = 0;
    double totalDailyChange = 0;
    double totalPreviousValue = 0;
    bool hasDailyChange = false;

    final showKrw = ref.watch(showKrwProvider);
    final rate = ref.watch(usdKrwRateSyncProvider);
    final isExcluded = ref.watch(
        excludedBundlesProvider.select((s) => s.contains(bundle.id)));
    for (final p in portfolios) {
      final m = ref.watch(portfolioMetricsProvider(p.id)).value;
      if (m != null) {
        totalValue += m.totalValue;
        totalInvested += m.totalInvested;
      }
      final dc = ref.watch(portfolioDailyChangeProvider(p.id));
      if (dc != null) {
        hasDailyChange = true;
        totalDailyChange += dc.amountChange;
        if (m != null) {
          totalPreviousValue += m.totalValue - dc.amountChange;
        }
      }
    }
    final bundleDailyChange = (hasDailyChange && totalPreviousValue > 0)
        ? DailyChange(
            amountChange: totalDailyChange,
            percentChange: totalDailyChange / totalPreviousValue * 100,
          )
        : null;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) =>
          !bundle.portfolioIds.contains(details.data),
      onAcceptWithDetails: (details) {
        ref
            .read(portfolioBundleNotifierProvider.notifier)
            .addToBundle(bundle.id, details.data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('묶음에 추가되었습니다'),
              duration: Duration(seconds: 2)),
        );
      },
      builder: (context, candidates, _) {
        final isTarget = candidates.isNotEmpty;

        return Container(
          // Extra right+bottom margin to show the ghost card edges
          margin: const EdgeInsets.fromLTRB(16, 4, 22, 10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Ghost card (back layer, offset right+down)
              Positioned(
                top: 5,
                left: 5,
                right: -5,
                bottom: -5,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ??
                        Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                ),
              ),

              // Main card (front)
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isTarget
                      ? const BorderSide(
                          color: Color(0xFF1565C0), width: 2.5)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () => context.push('/bundle/${bundle.id}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Tooltip(
                          message: isExcluded
                              ? '전체 합산에서 제외됨 (탭하여 포함)'
                              : '탭하면 전체 합산에서 제외',
                          child: GestureDetector(
                            onTap: () => ref
                                .read(excludedBundlesProvider.notifier)
                                .toggle(bundle.id),
                            child: CircleAvatar(
                              backgroundColor: isExcluded
                                  ? Colors.grey.shade300
                                  : Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                              child: isExcluded
                                  ? Icon(Icons.remove_circle_outline,
                                      size: 18,
                                      color: Colors.grey.shade500)
                                  : Icon(
                                      Icons.folder,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                      size: 20,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                bundle.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              if (isTarget)
                                const Text(
                                  '여기에 놓으면 묶음에 추가됩니다',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF1565C0)),
                                )
                              else if (totalValue > 0)
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _BundleSubtitle(
                                      totalValue: totalValue,
                                      totalInvested: totalInvested,
                                      showKrw: showKrw,
                                      rate: rate,
                                    ),
                                    if (bundleDailyChange != null)
                                      _DailyChangeText(
                                        change: bundleDailyChange,
                                        showKrw: showKrw,
                                        rate: rate,
                                        fontSize: 11,
                                      ),
                                  ],
                                )
                              else
                                Text(
                                  '포트폴리오 ${portfolios.length}개',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),

              // Count badge (top-right corner)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${portfolios.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BundleSubtitle extends StatelessWidget {
  final double totalValue;
  final double totalInvested;
  final bool showKrw;
  final double rate;

  const _BundleSubtitle({
    required this.totalValue,
    required this.totalInvested,
    required this.showKrw,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    final valueStr = showKrw
        ? CurrencyFormatter.formatKrw(totalValue)
        : CurrencyFormatter.formatUsd(totalValue / rate);
    if (totalInvested <= 0) {
      return Text(valueStr,
          style: const TextStyle(fontSize: 12));
    }
    final returnRate = (totalValue - totalInvested) / totalInvested;
    final color =
        returnRate >= 0 ? AppColors.positive : AppColors.negative;
    return Text(
      '$valueStr  ${CurrencyFormatter.formatSignedPercent(returnRate * 100)}',
      style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: color),
    );
  }
}


// ── Type selection tile (used in portfolio type bottom sheet) ──────────────────
class _TypeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TypeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

enum _PortfolioType { static_, dynamic }
