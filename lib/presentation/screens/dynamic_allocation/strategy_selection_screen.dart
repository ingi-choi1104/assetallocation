import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/dynamic_allocation.dart';

/// Strategy selection screen — shows all 6 strategies as cards.
/// Tapping a card opens a bottom sheet with date picker + launch button.
class StrategySelectionScreen extends StatelessWidget {
  const StrategySelectionScreen({super.key});

  static const _strategies = DynamicStrategyType.values;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('동적 자산배분 전략'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _strategies.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) return _HeaderCard();
          final type = _strategies[index - 1];
          return _StrategyCard(
            type: type,
            onTap: () => _showConfigSheet(context, type),
          );
        },
      ),
    );
  }

  Future<void> _showConfigSheet(BuildContext context, DynamicStrategyType type) async {
    final config = await showModalBottomSheet<DynamicStrategyConfig>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StrategyConfigSheet(type: type),
    );
    if (config != null && context.mounted) {
      context.push('/dynamic-allocation/result', extra: config);
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.auto_graph, color: AppColors.primary, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '동적 자산배분이란?',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '모멘텀·이동평균 등 계량 신호를 활용해 시장 상황에 따라\n'
                    '자산 비중을 자동으로 조절하는 체계적 투자 전략입니다.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade700),
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

// ── Strategy Card ─────────────────────────────────────────────────────────────

class _StrategyCard extends StatelessWidget {
  final DynamicStrategyType type;
  final VoidCallback onTap;

  const _StrategyCard({required this.type, required this.onTap});

  static const _colors = [
    Color(0xFF1A5C38), // VAA — forest green
    Color(0xFF1565C0), // PAA — blue
    Color(0xFFEF6C00), // DAA — orange
    Color(0xFF6A1B9A), // Dual Momentum — purple
    Color(0xFF00838F), // GTAA — teal
    Color(0xFFAD1457), // FAA — pink
  ];

  Color get _accent => _colors[type.index % _colors.length];

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color accent bar
            Container(height: 4, color: _accent),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Strategy badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          type.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          type.fullName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          size: 14, color: Colors.grey.shade400),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Key rule chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.rule, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            type.keyRule,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type.creator,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
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

// ── Config Bottom Sheet ───────────────────────────────────────────────────────

class _StrategyConfigSheet extends StatefulWidget {
  final DynamicStrategyType type;

  const _StrategyConfigSheet({required this.type});

  @override
  State<_StrategyConfigSheet> createState() => _StrategyConfigSheetState();
}

class _StrategyConfigSheetState extends State<_StrategyConfigSheet> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final config = DynamicStrategyConfig.defaultFor(widget.type, date: _selectedDate);
    final offensiveAssets = config.assets.where((a) => a.role == AssetRole.offensive).toList();
    final defensiveAssets = config.assets.where((a) => a.role == AssetRole.defensive).toList();
    final canaryAssets    = config.assets.where((a) => a.role == AssetRole.canary).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Text(
                    '${widget.type.displayName} 전략 설정',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    widget.type.creator,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  // Date picker
                  _DatePickerTile(
                    date: _selectedDate,
                    onChanged: (d) => setState(() => _selectedDate = d),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    '기본 자산 구성',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '아래 자산들을 기준으로 전략을 계산합니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // Asset groups
          if (canaryAssets.isNotEmpty)
            SliverToBoxAdapter(
              child: _AssetGroup(
                label: '카나리아 자산',
                assets: canaryAssets,
                color: Colors.orange,
              ),
            ),
          SliverToBoxAdapter(
            child: _AssetGroup(
              label: '공격 자산',
              assets: offensiveAssets,
              color: AppColors.primary,
            ),
          ),
          SliverToBoxAdapter(
            child: _AssetGroup(
              label: '방어 자산',
              assets: defensiveAssets,
              color: Colors.blueGrey,
            ),
          ),
          // Launch button
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final finalConfig = DynamicStrategyConfig.defaultFor(
                          widget.type,
                          date: _selectedDate,
                        );
                        Navigator.of(context).pop(finalConfig);
                      },
                      icon: const Icon(Icons.calculate_outlined),
                      label: Text(
                        '${_formatDate(_selectedDate)} 기준으로 계산',
                        style: const TextStyle(fontSize: 15),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')}';
}

// ── Date Picker Tile ──────────────────────────────────────────────────────────

class _DatePickerTile extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerTile({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2010, 1, 1),
          lastDate: DateTime.now(),
          helpText: '계산 기준 날짜',
          confirmText: '선택',
          cancelText: '취소',
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '계산 기준 날짜',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  Text(
                    '${date.year}년 ${date.month}월 ${date.day}일',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ── Asset Group ───────────────────────────────────────────────────────────────

class _AssetGroup extends StatelessWidget {
  final String label;
  final List<StrategyAssetConfig> assets;
  final Color color;

  const _AssetGroup({required this.label, required this.assets, required this.color});

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 14,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
              Text(
                '$label (${assets.length}개)',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6, runSpacing: 4,
            children: assets.map((a) => Chip(
              label: Text(a.symbol, style: const TextStyle(fontSize: 11)),
              backgroundColor: color.withValues(alpha: 0.08),
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.zero,
              side: BorderSide(color: color.withValues(alpha: 0.2)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList(),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
