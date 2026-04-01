import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/portfolio_snapshot.dart';
import '../../providers/snapshot_providers.dart';

class SnapshotDetailScreen extends ConsumerStatefulWidget {
  final int snapshotId;
  const SnapshotDetailScreen({super.key, required this.snapshotId});

  @override
  ConsumerState<SnapshotDetailScreen> createState() =>
      _SnapshotDetailScreenState();
}

class _SnapshotDetailScreenState
    extends ConsumerState<SnapshotDetailScreen> {
  final Set<int> _expandedPortfolios = {};

  PortfolioSnapshot? _findSnapshot(List<PortfolioSnapshot> list) {
    for (final s in list) {
      if (s.id == widget.snapshotId) return s;
    }
    return null;
  }

  Future<void> _delete(PortfolioSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('스냅샷 삭제'),
        content: const Text('이 스냅샷을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(snapshotNotifierProvider.notifier)
        .deleteSnapshot(snapshot.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editMemo(PortfolioSnapshot snapshot) async {
    final controller =
        TextEditingController(text: snapshot.memo ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('메모 편집'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '스냅샷에 대한 메모를 입력하세요'),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    await ref
        .read(snapshotNotifierProvider.notifier)
        .updateMemo(snapshot.id, result);
  }

  @override
  Widget build(BuildContext context) {
    final snapshots = ref.watch(snapshotNotifierProvider);
    final snapshot = _findSnapshot(snapshots);

    if (snapshot == null) {
      return const Scaffold(
        body: Center(child: Text('스냅샷을 찾을 수 없습니다.')),
      );
    }

    final dateStr =
        DateFormat('yyyy년 M월 d일 HH:mm').format(snapshot.takenAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(dateStr),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: '메모 편집',
            onPressed: () => _editMemo(snapshot),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: '삭제',
            onPressed: () => _delete(snapshot),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 전체 요약 카드 ──────────────────────────────────────────────
          _SummaryCard(snapshot: snapshot),
          const SizedBox(height: 12),

          // ── 전체 파이차트 ───────────────────────────────────────────────
          if (snapshot.portfolios.length > 1) ...[
            _PortfolioPieChart(snapshot: snapshot),
            const SizedBox(height: 12),
          ],

          // ── 메모 ────────────────────────────────────────────────────────
          if (snapshot.memo != null && snapshot.memo!.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.notes, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(snapshot.memo!)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── 포트폴리오별 카드 ───────────────────────────────────────────
          ...snapshot.portfolios.map((p) => _PortfolioCard(
                entry: p,
                totalValue: snapshot.totalValueKrw,
                expanded: _expandedPortfolios.contains(p.portfolioId),
                onToggle: () {
                  setState(() {
                    if (_expandedPortfolios.contains(p.portfolioId)) {
                      _expandedPortfolios.remove(p.portfolioId);
                    } else {
                      _expandedPortfolios.add(p.portfolioId);
                    }
                  });
                },
              )),
        ],
      ),
          ),
          // 배너 광고 (홈바 위에 표시)
          const SafeArea(top: false, child: BannerAdWidget()),
        ],
      ),
    );
  }
}

// ── 전체 요약 카드 ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final PortfolioSnapshot snapshot;
  const _SummaryCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final hasInv = snapshot.totalInvested > 0;
    final returnColor =
        snapshot.returnRate >= 0 ? AppColors.positive : AppColors.negative;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('전체 자산',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.formatKrw(snapshot.totalValueKrw),
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (hasInv) ...[
              const SizedBox(height: 8),
              Text(
                '투자금 ${CurrencyFormatter.formatKrw(snapshot.totalInvested)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '수익률 ${CurrencyFormatter.formatSignedPercent(snapshot.returnRate * 100)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: returnColor),
                  ),
                  if (snapshot.annualizedReturnRate != 0) ...[
                    const SizedBox(width: 16),
                    Text(
                      '연평균 ${CurrencyFormatter.formatSignedPercent(snapshot.annualizedReturnRate * 100)}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: snapshot.annualizedReturnRate >= 0
                              ? AppColors.positive
                              : AppColors.negative),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '손익 ${CurrencyFormatter.formatKrw(snapshot.totalValueKrw - snapshot.totalInvested)}',
                style: TextStyle(
                    fontSize: 13,
                    color: returnColor,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 포트폴리오 파이차트 ──────────────────────────────────────────────────────────
class _PortfolioPieChart extends StatefulWidget {
  final PortfolioSnapshot snapshot;
  const _PortfolioPieChart({required this.snapshot});

  @override
  State<_PortfolioPieChart> createState() => _PortfolioPieChartState();
}

class _PortfolioPieChartState extends State<_PortfolioPieChart> {
  int? _touched;

  static const _colors = [
    Color(0xFF4285F4),
    Color(0xFF34A853),
    Color(0xFFFBBC05),
    Color(0xFFEA4335),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
    Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context) {
    final total = widget.snapshot.totalValueKrw;
    if (total == 0) return const SizedBox.shrink();

    final entries = widget.snapshot.portfolios
        .where((p) => p.valueKrw > 0)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('포트폴리오 구성',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sections: entries.asMap().entries.map((e) {
                        final idx = e.key;
                        final p = e.value;
                        final pct = p.valueKrw / total * 100;
                        final isTouched = _touched == idx;
                        return PieChartSectionData(
                          value: p.valueKrw,
                          color: _colors[idx % _colors.length],
                          radius: isTouched ? 58 : 50,
                          title: '${pct.toStringAsFixed(1)}%',
                          titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          showTitle: pct >= 8,
                        );
                      }).toList(),
                      pieTouchData: PieTouchData(
                        touchCallback: (event, resp) {
                          setState(() {
                            _touched = (event.isInterestedForInteractions &&
                                    resp?.touchedSection != null)
                                ? resp!.touchedSection!.touchedSectionIndex
                                : null;
                          });
                        },
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.asMap().entries.map((e) {
                      final idx = e.key;
                      final p = e.value;
                      final pct = total == 0
                          ? 0.0
                          : p.valueKrw / total * 100;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _colors[idx % _colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 포트폴리오별 자산 카드 ───────────────────────────────────────────────────────
class _PortfolioCard extends StatelessWidget {
  final PortfolioSnapshotEntry entry;
  final double totalValue;
  final bool expanded;
  final VoidCallback onToggle;

  const _PortfolioCard({
    required this.entry,
    required this.totalValue,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasInv = entry.invested > 0;
    final returnColor =
        entry.returnRate >= 0 ? AppColors.positive : AppColors.negative;
    final portfolioShare =
        totalValue == 0 ? 0.0 : entry.valueKrw / totalValue * 100;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                entry.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${portfolioShare.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatKrw(entry.valueKrw),
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (hasInv) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '수익률 ${CurrencyFormatter.formatSignedPercent(entry.returnRate * 100)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: returnColor,
                                    fontWeight: FontWeight.w600),
                              ),
                              if (entry.annualizedReturnRate != 0) ...[
                                const SizedBox(width: 10),
                                Text(
                                  '연 ${CurrencyFormatter.formatSignedPercent(entry.annualizedReturnRate * 100)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: entry.annualizedReturnRate >= 0
                                          ? AppColors.positive
                                          : AppColors.negative,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            // ── 자산 파이차트 ─────────────────────────────────────────────
            if (entry.assets.length > 1 && entry.valueKrw > 0)
              _AssetPieChart(entry: entry),
            // ── 자산 목록 ──────────────────────────────────────────────────
            ...entry.assets.map((a) => _AssetRow(asset: a,
                totalPortfolioValue: entry.valueKrw)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AssetPieChart extends StatelessWidget {
  final PortfolioSnapshotEntry entry;

  static const _colors = [
    Color(0xFF4285F4),
    Color(0xFF34A853),
    Color(0xFFFBBC05),
    Color(0xFFEA4335),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
    Color(0xFF607D8B),
    Color(0xFF795548),
    Color(0xFF009688),
  ];

  const _AssetPieChart({required this.entry});

  @override
  Widget build(BuildContext context) {
    final assets =
        entry.assets.where((a) => a.valueKrw > 0).toList();
    if (assets.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: PieChart(
              PieChartData(
                sections: assets.asMap().entries.map((e) {
                  final idx = e.key;
                  final a = e.value;
                  final pct = a.valueKrw / entry.valueKrw * 100;
                  return PieChartSectionData(
                    value: a.valueKrw,
                    color: _colors[idx % _colors.length],
                    radius: 42,
                    title: '${pct.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    showTitle: pct >= 10,
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: assets.asMap().entries.map((e) {
                final idx = e.key;
                final a = e.value;
                final pct = a.valueKrw / entry.valueKrw * 100;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _colors[idx % _colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: Text(
                        '${a.name} ${pct.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  final AssetSnapshotEntry asset;
  final double totalPortfolioValue;

  const _AssetRow(
      {required this.asset, required this.totalPortfolioValue});

  @override
  Widget build(BuildContext context) {
    final actualPct = totalPortfolioValue == 0
        ? 0.0
        : asset.valueKrw / totalPortfolioValue * 100;
    final holdingsStr = asset.holdings < 1
        ? asset.holdings.toStringAsFixed(4)
        : asset.holdings.toStringAsFixed(2);
    final typeLabel = _assetTypeLabel(asset.assetType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        asset.name,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (asset.symbol.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        asset.symbol,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (typeLabel.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: const TextStyle(
                              fontSize: 9, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$holdingsStr주  ×  ${CurrencyFormatter.formatKrw(asset.priceKrw)}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatKrw(asset.valueKrw),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
                Text(
                  '실제 ${actualPct.toStringAsFixed(1)}%  목표 ${asset.targetWeight.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _assetTypeLabel(String type) {
    switch (type) {
      case 'usStock':
        return '미국주식';
      case 'krStock':
        return '국내주식';
      case 'crypto':
        return '암호화폐';
      case 'gold':
        return '금';
      case 'fund':
        return '펀드';
      case 'cash':
        return '현금';
      default:
        return '';
    }
  }
}
