import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/dividend_info.dart';
import '../../providers/dividend_providers.dart';
import '../../providers/price_providers.dart';

class DividendScreen extends ConsumerStatefulWidget {
  const DividendScreen({super.key});

  @override
  ConsumerState<DividendScreen> createState() => _DividendScreenState();
}

class _DividendScreenState extends ConsumerState<DividendScreen> {
  int? _selectedMonthIndex;

  @override
  Widget build(BuildContext context) {
    final projectionAsync = ref.watch(dividendProjectionProvider);
    final showKrw = ref.watch(showKrwProvider);
    final rate = ref.watch(usdKrwRateSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('배당'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('KRW'),
              selected: showKrw,
              onSelected: (v) => ref.read(showKrwProvider.notifier).toggle(v),
            ),
          ),
        ],
      ),
      body: projectionAsync.when(
        data: (months) => _Body(
          months: months,
          showKrw: showKrw,
          rate: rate,
          selectedMonthIndex: _selectedMonthIndex,
          onBarTap: (i) => setState(() => _selectedMonthIndex = i),
          onShowAnnual: () => setState(() => _selectedMonthIndex = null),
        ),
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('배당 정보를 불러오는 중…', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final List<MonthlyDividend> months;
  final bool showKrw;
  final double rate;
  final int? selectedMonthIndex;
  final ValueChanged<int> onBarTap;
  final VoidCallback onShowAnnual;

  const _Body({
    required this.months,
    required this.showKrw,
    required this.rate,
    required this.selectedMonthIndex,
    required this.onBarTap,
    required this.onShowAnnual,
  });

  double get _annualKrw => months.fold(0.0, (s, m) => s + m.totalKrw);
  bool get _hasDividends => months.any((m) => m.totalKrw > 0);

  String _fmt(double krw) => showKrw
      ? CurrencyFormatter.formatKrw(krw)
      : CurrencyFormatter.formatUsd(krw / rate);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _SummaryCard(annualKrw: _annualKrw, fmt: _fmt),
        const SizedBox(height: 8),
        if (!_hasDividends)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 40, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    '배당 데이터가 없습니다.\n배당주를 보유하고 있으면\n자동으로 집계됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else ...[
          _BarChartCard(
            months: months,
            showKrw: showKrw,
            rate: rate,
            selectedMonthIndex: selectedMonthIndex,
            onBarTap: onBarTap,
            onShowAnnual: onShowAnnual,
          ),
          const SizedBox(height: 4),
          if (selectedMonthIndex != null)
            _MonthDetailCard(
              month: months[selectedMonthIndex!],
              fmt: _fmt,
            )
          else
            _AnnualSummaryCard(months: months, fmt: _fmt),
        ],
      ],
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double annualKrw;
  final String Function(double) fmt;

  const _SummaryCard({required this.annualKrw, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.savings_outlined, size: 32, color: AppColors.positive),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('연간 예상 배당금',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  annualKrw > 0 ? fmt(annualKrw) : '-',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bar chart card ────────────────────────────────────────────────────────────

/// Compact label above each bar: "77만원" / "600달러"
String _barLabel(double krw, bool showKrw, double rate) {
  if (krw <= 0) return '';
  if (showKrw) {
    final man = krw / 10000;
    if (man >= 1) return '${man.round()}만원';
    return '${krw.round()}원';
  } else {
    final usd = krw / rate;
    if (usd >= 1000) return '${(usd / 1000).toStringAsFixed(1)}천달러';
    return '${usd.round()}달러';
  }
}

class _BarChartCard extends StatelessWidget {
  final List<MonthlyDividend> months;
  final bool showKrw;
  final double rate;
  final int? selectedMonthIndex;
  final ValueChanged<int> onBarTap;
  final VoidCallback onShowAnnual;

  // Fixed heights
  static const double _bottomReserved = 22.0; // month label row
  static const double _labelH = 16.0;         // label above bar
  static const double _barAreaH = 180.0;      // pure bar drawing area
  static const double _totalChartH = _barAreaH + _bottomReserved;

  const _BarChartCard({
    required this.months,
    required this.showKrw,
    required this.rate,
    required this.selectedMonthIndex,
    required this.onBarTap,
    required this.onShowAnnual,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxKrw = months.map((m) => m.totalKrw).fold(0.0, (a, b) => a > b ? a : b);
    final maxY = maxKrw > 0 ? maxKrw * 1.3 : 100.0;
    final n = months.length; // 12

    return Card(
      // 좌우 마진을 줄여서 그래프가 화면을 꽉 채우도록
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Text('월별 예상 배당금',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  GestureDetector(
                    onTap: onShowAnnual,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: selectedMonthIndex == null
                            ? colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selectedMonthIndex == null
                              ? colorScheme.primary
                              : Colors.grey.shade400,
                        ),
                      ),
                      child: Text(
                        '연간 전체',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selectedMonthIndex == null
                              ? colorScheme.primary
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── 차트 + 라벨 오버레이 ───────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final chartW = constraints.maxWidth;
                final slotW = chartW / n;
                // 막대 넓이: 슬롯의 80%, 최소 10px 최대 30px
                final barW = (slotW * 0.80).clamp(10.0, 30.0);

                return SizedBox(
                  height: _totalChartH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ── fl_chart BarChart ──────────────────────────
                      BarChart(
                        BarChartData(
                          maxY: maxY,
                          barTouchData: BarTouchData(
                            handleBuiltInTouches: false,
                            touchCallback: (event, response) {
                              if (event is FlTapUpEvent &&
                                  response?.spot != null) {
                                onBarTap(response!
                                    .spot!.touchedBarGroupIndex);
                              }
                            },
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: false, reservedSize: 0)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: false, reservedSize: 0)),
                            leftTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: false, reservedSize: 0)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: _bottomReserved,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= n) {
                                    return const SizedBox.shrink();
                                  }
                                  final isSelected =
                                      idx == selectedMonthIndex;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '${months[idx].month}월',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? colorScheme.primary
                                            : Colors.grey,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: maxKrw > 0 ? maxKrw / 4 : 25,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: Colors.grey.withValues(alpha: 0.15),
                              strokeWidth: 1,
                            ),
                          ),
                          barGroups: months.asMap().entries.map((e) {
                            final idx = e.key;
                            final m = e.value;
                            final isSelected = idx == selectedMonthIndex;
                            return BarChartGroupData(
                              x: idx,
                              barRods: [
                                BarChartRodData(
                                  toY: m.totalKrw,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.primary
                                          .withValues(alpha: 0.55),
                                  width: barW,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3)),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      // ── 바 위 라벨 오버레이 ─────────────────────────
                      ...months.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final m = entry.value;
                        if (m.totalKrw <= 0) return const SizedBox.shrink();

                        final label = _barLabel(m.totalKrw, showKrw, rate);
                        // 바 top Y (바 영역 기준)
                        final frac =
                            (m.totalKrw / maxY).clamp(0.0, 1.0);
                        final barTopY = _barAreaH * (1.0 - frac);
                        // 라벨은 바 바로 위, 넘치면 상단에 고정
                        final labelTop =
                            (barTopY - _labelH).clamp(0.0, _barAreaH - _labelH);
                        // 바 중심 X
                        final barCenterX = (idx + 0.5) / n * chartW;
                        final isSelected = idx == selectedMonthIndex;

                        return Positioned(
                          left: barCenterX - slotW / 2,
                          top: labelTop,
                          width: slotW,
                          height: _labelH,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomCenter,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Monthly detail card ───────────────────────────────────────────────────────

class _MonthDetailCard extends StatelessWidget {
  final MonthlyDividend month;
  final String Function(double) fmt;

  const _MonthDetailCard({required this.month, required this.fmt});

  @override
  Widget build(BuildContext context) {
    if (month.entries.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${month.year}년 ${month.month}월 — 예상 배당 없음',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${month.year}년 ${month.month}월 종목별 예상 배당금',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            ...month.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                e.isKrStock && e.name.isNotEmpty
                                    ? e.name
                                    : e.symbol,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            if (e.isKrStock && e.name.isNotEmpty
                                ? e.symbol.isNotEmpty
                                : e.name.isNotEmpty && e.name != e.symbol)
                              Text(
                                  e.isKrStock ? e.symbol : e.name,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Text(
                        fmt(e.amountKrw),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('합계',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(fmt(month.totalKrw),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Annual summary card ───────────────────────────────────────────────────────

class _AnnualSummaryCard extends StatelessWidget {
  final List<MonthlyDividend> months;
  final String Function(double) fmt;

  const _AnnualSummaryCard({required this.months, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final totals =
        <int, ({String symbol, String name, double krw, bool isKrStock})>{};
    for (final m in months) {
      for (final e in m.entries) {
        final prev = totals[e.assetId];
        totals[e.assetId] = (
          symbol: e.symbol,
          name: e.name,
          krw: (prev?.krw ?? 0) + e.amountKrw,
          isKrStock: e.isKrStock,
        );
      }
    }
    if (totals.isEmpty) return const SizedBox.shrink();

    final sorted = totals.values.toList()
      ..sort((a, b) => b.krw.compareTo(a.krw));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('종목별 연간 예상 배당금',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ...sorted.map((a) {
            final titleText =
                a.isKrStock && a.name.isNotEmpty ? a.name : a.symbol;
            final subtitleText =
                a.isKrStock && a.name.isNotEmpty ? a.symbol : a.name;
            final showSub =
                subtitleText.isNotEmpty && subtitleText != titleText;
            return ListTile(
                dense: true,
                title: Text(titleText,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: showSub
                    ? Text(subtitleText,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis)
                    : null,
                trailing: Text(
                  fmt(a.krw),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
