import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../domain/entities/portfolio_bundle.dart';
import '../../providers/metrics_providers.dart';
import '../../providers/portfolio_bundle_providers.dart';
import '../../providers/portfolio_providers.dart';
import '../../providers/price_providers.dart';

/// Shows all portfolios inside a bundle with individual metrics.
class PortfolioBundleScreen extends ConsumerWidget {
  final int bundleId;

  const PortfolioBundleScreen({super.key, required this.bundleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundles = ref.watch(portfolioBundleNotifierProvider);

    PortfolioBundle? bundle;
    for (final b in bundles) {
      if (b.id == bundleId) {
        bundle = b;
        break;
      }
    }

    if (bundle == null) {
      // Bundle was dissolved — go back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.canPop()) context.pop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _BundleContent(bundle: bundle);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BundleContent extends ConsumerStatefulWidget {
  final PortfolioBundle bundle;

  const _BundleContent({required this.bundle});

  @override
  ConsumerState<_BundleContent> createState() => _BundleContentState();
}

class _BundleContentState extends ConsumerState<_BundleContent> {
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bundle.name);
  }

  @override
  void didUpdateWidget(_BundleContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bundle.name != widget.bundle.name && !_isEditingName) {
      _nameController.text = widget.bundle.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveRename() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && name != widget.bundle.name) {
      ref.read(portfolioBundleNotifierProvider.notifier).renameBundle(bundleId, name);
    }
    setState(() => _isEditingName = false);
  }

  int get bundleId => widget.bundle.id;

  @override
  Widget build(BuildContext context) {
    final portfoliosAsync = ref.watch(sortedPortfoliosProvider);
    final portfolioMap = portfoliosAsync.whenData((list) => {for (final p in list) p.id: p}).value ?? {};

    final members = widget.bundle.portfolioIds
        .map((id) => portfolioMap[id])
        .where((p) => p != null)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: _isEditingName
            ? TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(border: InputBorder.none),
                onSubmitted: (_) => _saveRename(),
              )
            : GestureDetector(
                onTap: () => setState(() => _isEditingName = true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.bundle.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_outlined, size: 16, color: Colors.white70),
                  ],
                ),
              ),
        actions: [
          if (_isEditingName)
            IconButton(icon: const Icon(Icons.check), onPressed: _saveRename),
          PopupMenuButton<_Action>(
            onSelected: (action) {
              if (action == _Action.dissolve) _confirmDissolve(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _Action.dissolve,
                child: Row(children: [
                  Icon(Icons.link_off, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('묶음 해산', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: members.isEmpty
          ? const Center(child: Text('포트폴리오가 없습니다'))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _BundleSummaryCard(
                  portfolioIds: widget.bundle.portfolioIds,
                ),
                ...members.map((portfolio) => _BundleMemberCard(
                      portfolio: portfolio!,
                      onRemove: () => _confirmRemove(
                          context, portfolio.name, portfolio.id),
                      onTap: () =>
                          context.push('/portfolio/${portfolio.id}'),
                    )),
                const Center(child: BannerAdWidget()),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, String name, int portfolioId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('묶음에서 제거'),
        content: Text('$name을(를) 이 묶음에서 제거하시겠어요?\n포트폴리오 자체는 삭제되지 않습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('제거'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(portfolioBundleNotifierProvider.notifier).removeFromBundle(bundleId, portfolioId);
    }
  }

  Future<void> _confirmDissolve(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('묶음 해산'),
        content: const Text('이 묶음을 해산하시겠어요?\n포트폴리오들은 개별 항목으로 홈 화면에 표시됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('해산'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(portfolioBundleNotifierProvider.notifier).dissolveBundle(bundleId);
      // ignore: use_build_context_synchronously
      if (mounted && context.canPop()) context.pop();
    }
  }
}

// ─── Bundle Member Card ────────────────────────────────────────────────────────

class _BundleMemberCard extends ConsumerWidget {
  final dynamic portfolio; // Portfolio entity
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _BundleMemberCard({
    required this.portfolio,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(portfolioMetricsProvider(portfolio.id));
    final showKrw = ref.watch(showKrwProvider);
    final rate = ref.watch(usdKrwRateSyncProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  portfolio.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(portfolio.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Builder(builder: (_) {
                      final m = metricsAsync.valueOrNull;
                      if (m == null) {
                        return const Text('...',
                            style: TextStyle(fontSize: 12));
                      }
                      if (m.totalValue == 0) {
                        return const Text('거래 없음',
                            style: TextStyle(fontSize: 12, color: Colors.grey));
                      }
                      final valueStr = showKrw
                          ? CurrencyFormatter.formatKrw(m.totalValue)
                          : CurrencyFormatter.formatUsd(m.totalValue / rate);
                      final hasReturn = m.totalInvested > 0;
                      if (!hasReturn) {
                        return Text(valueStr,
                            style: const TextStyle(fontSize: 12));
                      }
                      final color = m.returnRate >= 0
                          ? AppColors.positive
                          : AppColors.negative;
                      return Text(
                        '$valueStr  ${CurrencyFormatter.formatSignedPercent(m.returnRate * 100)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color),
                      );
                    }),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(children: [
                      Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('묶음에서 제거', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
                onSelected: (v) { if (v == 'remove') onRemove(); },
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Action { dissolve }

// ─── Bundle Summary Card ───────────────────────────────────────────────────────

class _BundleSummaryCard extends ConsumerWidget {
  final List<int> portfolioIds;

  const _BundleSummaryCard({required this.portfolioIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(bundleMetricsProvider(portfolioIds));
    final showKrw = ref.watch(showKrwProvider);
    final rate = ref.watch(usdKrwRateSyncProvider);

    // Aggregate daily change across bundle members
    double totalDailyChange = 0;
    double totalPreviousValue = 0;
    bool hasDailyChange = false;

    for (final id in portfolioIds) {
      final dc = ref.watch(portfolioDailyChangeProvider(id));
      final m = ref.watch(portfolioMetricsProvider(id)).value;
      if (dc != null && m != null) {
        hasDailyChange = true;
        totalDailyChange += dc.amountChange;
        totalPreviousValue += m.totalValue - dc.amountChange;
      }
    }
    final dailyChange = (hasDailyChange && totalPreviousValue > 0)
        ? DailyChange(
            amountChange: totalDailyChange,
            percentChange: totalDailyChange / totalPreviousValue * 100,
          )
        : null;

    return metricsAsync.when(
      data: (m) {
        if (m.totalValue == 0 && m.totalInvested == 0) {
          return const SizedBox.shrink();
        }
        final hasInvestments = m.totalInvested > 0;
        final returnColor =
            m.returnRate >= 0 ? AppColors.positive : AppColors.negative;
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
                Text(
                  '묶음 전체',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  valueDisplay,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                if (dailyChange != null) ...[
                  const SizedBox(height: 2),
                  _BundleDailyChangeText(
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
      },
      loading: () => const Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _BundleDailyChangeText extends StatelessWidget {
  final DailyChange change;
  final bool showKrw;
  final double rate;

  const _BundleDailyChangeText({
    required this.change,
    required this.showKrw,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    final pct = change.percentChange;
    final amt = change.amountChange;
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
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
