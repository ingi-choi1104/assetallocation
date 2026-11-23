import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/firebase_service.dart';

class SharedPortfolioScreen extends StatefulWidget {
  final String code;
  const SharedPortfolioScreen({super.key, required this.code});

  @override
  State<SharedPortfolioScreen> createState() => _SharedPortfolioScreenState();
}

class _SharedPortfolioScreenState extends State<SharedPortfolioScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  static final _comma = NumberFormat('#,##0', 'ko_KR');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await FirebaseService.instance
        .getSharedPortfolio(widget.code);
    if (mounted) {
      setState(() {
        _loading = false;
        _data = data;
        _error = data == null ? '공유 코드를 찾을 수 없습니다.' : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_data?['portfolioName'] as String? ?? '공유 포트폴리오'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('읽기 전용',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link_off,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final assets = (d['assets'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final totalValue = (d['totalValue'] as num?)?.toDouble() ?? 0;
    final returnRate = (d['returnRate'] as num?)?.toDouble();
    final currency = d['currency'] as String? ?? 'KRW';
    final sharedAt = (d['sharedAt'] as Timestamp?)?.toDate();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 요약 카드
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d['portfolioName'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  currency == 'KRW'
                      ? '₩${_comma.format(totalValue)}'
                      : '\$${totalValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                if (returnRate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '수익률 ${returnRate >= 0 ? "+" : ""}${(returnRate * 100).toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forChange(returnRate),
                    ),
                  ),
                ],
                if (sharedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '공유일: ${DateFormat('yyyy.MM.dd').format(sharedAt)}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 비중 분포 바
        if (assets.isNotEmpty) _WeightBar(assets: assets),
        const SizedBox(height: 8),
        // 종목 목록
        const Text('보유 종목',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        for (final a in assets)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  (a['name'] as String? ?? '?')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              title: Text(a['name'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(a['symbol'] as String? ?? '',
                  style: const TextStyle(fontSize: 11)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${((a['weight'] as num?) ?? 0).toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if ((a['value'] as num?) != null)
                    Text(
                      currency == 'KRW'
                          ? '₩${_comma.format((a['value'] as num).toDouble())}'
                          : '\$${(a['value'] as num).toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          '* 이 포트폴리오는 읽기 전용입니다. 수정할 수 없습니다.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _WeightBar extends StatelessWidget {
  final List<Map<String, dynamic>> assets;
  const _WeightBar({required this.assets});

  static const _colors = [
    Color(0xFF1976D2), Color(0xFF388E3C), Color(0xFFF57C00),
    Color(0xFF7B1FA2), Color(0xFF0097A7), Color(0xFFE91E63),
    Color(0xFF5D4037), Color(0xFF455A64),
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = [...assets]
      ..sort((a, b) =>
          ((b['weight'] as num?) ?? 0)
              .compareTo((a['weight'] as num?) ?? 0));
    double total = sorted.fold(
        0, (s, a) => s + ((a['weight'] as num?) ?? 0).toDouble());
    if (total <= 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('비중',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: sorted.asMap().entries.map((e) {
                    final pct =
                        ((e.value['weight'] as num?) ?? 0).toDouble() /
                            total;
                    return Expanded(
                      flex: (pct * 1000).round(),
                      child: Container(
                          color: _colors[e.key % _colors.length]),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 2,
              children: sorted.asMap().entries.map((e) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _colors[e.key % _colors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${e.value['name'] ?? ''} ${((e.value['weight'] as num?) ?? 0).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
