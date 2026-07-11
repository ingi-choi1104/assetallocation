import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../providers/price_providers.dart';
import '../../providers/tax_providers.dart';

class TaxScreen extends ConsumerStatefulWidget {
  const TaxScreen({super.key});

  @override
  ConsumerState<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends ConsumerState<TaxScreen> {
  int? _selectedMonthIndex;

  @override
  Widget build(BuildContext context) {
    final projectionAsync = ref.watch(taxDividendProjectionProvider);
    final showKrw = ref.watch(showKrwProvider);
    final rate = ref.watch(usdKrwRateSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('배당 세금'),
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
              Text('세금 정보를 계산하는 중…',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final List<TaxedMonthlyDividend> months;
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

  @override
  Widget build(BuildContext context) {
    final annualGross = months.fold(0.0, (s, m) => s + m.grossKrw);
    final annualTax   = months.fold(0.0, (s, m) => s + m.taxKrw);
    final annualNet   = months.fold(0.0, (s, m) => s + m.netKrw);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SummaryCard(
            annualGross: annualGross,
            annualTax: annualTax,
            annualNet: annualNet,
            showKrw: showKrw,
            rate: rate),
        _BarChartCard(
          months: months,
          showKrw: showKrw,
          rate: rate,
          selectedMonthIndex: selectedMonthIndex,
          onBarTap: onBarTap,
          onShowAnnual: onShowAnnual,
        ),
        if (selectedMonthIndex != null)
          _MonthDetailCard(
            month: months[selectedMonthIndex!],
            showKrw: showKrw,
            rate: rate,
          )
        else
          _AnnualSummaryCard(months: months, showKrw: showKrw, rate: rate),
      ],
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double annualGross, annualTax, annualNet;
  final bool showKrw;
  final double rate;

  const _SummaryCard({
    required this.annualGross,
    required this.annualTax,
    required this.annualNet,
    required this.showKrw,
    required this.rate,
  });

  String _fmt(double krw) => showKrw
      ? CurrencyFormatter.formatKrw(krw)
      : CurrencyFormatter.formatUsd(krw / rate);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('연간 예상 배당 세금',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                _Col(label: '세전 배당', value: _fmt(annualGross),
                    color: Colors.blueGrey),
                const SizedBox(width: 20),
                _Col(label: '예상 세금', value: _fmt(annualTax),
                    color: Colors.red.shade400),
                const SizedBox(width: 20),
                _Col(label: '세후 배당', value: _fmt(annualNet),
                    color: const Color(0xFF1976D2)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '* 일반계좌 15.4% / ISA 9.9% / 연금·IRP 비과세',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _Col extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Col(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ── Bar chart card ────────────────────────────────────────────────────────────

const _barAreaH     = 180.0;
const _bottomReserved = 22.0;
const _totalChartH  = _barAreaH + _bottomReserved;
const _labelH       = 16.0;

class _BarChartCard extends StatelessWidget {
  final List<TaxedMonthlyDividend> months;
  final bool showKrw;
  final double rate;
  final int? selectedMonthIndex;
  final ValueChanged<int> onBarTap;
  final VoidCallback onShowAnnual;

  const _BarChartCard({
    required this.months,
    required this.showKrw,
    required this.rate,
    required this.selectedMonthIndex,
    required this.onBarTap,
    required this.onShowAnnual,
  });

  String _barLabel(double krw) {
    if (showKrw) {
      if (krw >= 10000000) return '${(krw / 10000000).toStringAsFixed(0)}천만';
      if (krw >= 1000000) return '${(krw / 10000).toStringAsFixed(0)}만원';
      return '${krw.toStringAsFixed(0)}원';
    } else {
      final usd = krw / rate;
      if (usd >= 1000) return '${(usd / 1000).toStringAsFixed(0)}천달러';
      return '${usd.toStringAsFixed(0)}달러';
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxGross =
        months.map((m) => m.grossKrw).fold(0.0, (a, b) => a > b ? a : b);

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < months.length; i++) {
      final m = months[i];
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: maxGross > 0 ? m.grossKrw : 0,
            width: 16,
            borderRadius: BorderRadius.circular(3),
            rodStackItems: [
              BarChartRodStackItem(0, m.netKrw, const Color(0xFF1976D2)),
              BarChartRodStackItem(
                  m.netKrw, m.grossKrw, Colors.red.shade300),
            ],
          ),
        ],
      ));
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                const Text('월별 예상 세금',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                // legend
                _LegendDot(color: const Color(0xFF1976D2), label: '세후'),
                const SizedBox(width: 8),
                _LegendDot(color: Colors.red.shade300, label: '세금'),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: selectedMonthIndex != null
                      ? TextButton(
                          key: const ValueKey('annual'),
                          onPressed: onShowAnnual,
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(56, 28),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap),
                          child: const Text('연간 전체',
                              style: TextStyle(fontSize: 12)),
                        )
                      : const SizedBox.shrink(key: ValueKey('none')),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LayoutBuilder(builder: (context, constraints) {
              final chartW = constraints.maxWidth;
              final n = months.length;

              // label positions
              final labelWidgets = <Widget>[];
              for (int i = 0; i < n; i++) {
                final m = months[i];
                if (m.grossKrw <= 0) continue;
                final frac = maxGross > 0 ? m.grossKrw / maxGross : 0.0;
                final barCenterX = (i + 0.5) / n * chartW;
                final barTopY = _barAreaH * (1 - frac);
                final labelTop = (barTopY - _labelH).clamp(0.0, _barAreaH - _labelH);
                labelWidgets.add(Positioned(
                  left: barCenterX - 28,
                  top: labelTop,
                  width: 56,
                  height: _labelH,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomCenter,
                    child: Text(_barLabel(m.grossKrw),
                        style: const TextStyle(fontSize: 11)),
                  ),
                ));
              }

              return Stack(
                children: [
                  SizedBox(
                    height: _totalChartH,
                    child: BarChart(
                      BarChartData(
                        maxY: maxGross > 0 ? maxGross * 1.15 : 1,
                        barGroups: barGroups,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: false, reservedSize: 0)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: false, reservedSize: 0)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: false, reservedSize: 0)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: _bottomReserved,
                              getTitlesWidget: (val, _) {
                                final idx = val.toInt();
                                if (idx < 0 || idx >= months.length) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  '${months[idx].month}월',
                                  style: const TextStyle(fontSize: 9),
                                );
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          handleBuiltInTouches: false,
                          touchCallback: (event, response) {
                            if (event is FlTapUpEvent) {
                              final idx = response
                                  ?.spot?.touchedBarGroupIndex;
                              if (idx != null) onBarTap(idx);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _barAreaH,
                    child: Stack(children: labelWidgets),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ── Monthly detail card ───────────────────────────────────────────────────────

class _MonthDetailCard extends StatelessWidget {
  final TaxedMonthlyDividend month;
  final bool showKrw;
  final double rate;

  const _MonthDetailCard(
      {required this.month, required this.showKrw, required this.rate});

  String _fmt(double krw) => showKrw
      ? CurrencyFormatter.formatKrw(krw)
      : CurrencyFormatter.formatUsd(krw / rate);

  @override
  Widget build(BuildContext context) {
    if (month.entries.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('이 달에 예상되는 배당이 없습니다.',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${month.month}월 종목별 세금',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const Divider(height: 12),
            ...month.entries.map((e) {
              final titleText = e.isKrStock ? e.name : e.symbol;
              final subtitleText = e.isKrStock ? e.symbol : e.name;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(titleText,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(subtitleText,
                    style: const TextStyle(fontSize: 11)),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_fmt(e.grossKrw),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.blueGrey)),
                    Text('세금 ${_fmt(e.taxKrw)} (${(e.taxRate * 100).toStringAsFixed(1)}%)',
                        style: TextStyle(
                            fontSize: 11, color: Colors.red.shade400)),
                    Text(_fmt(e.netKrw),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2))),
                  ],
                ),
              );
            }),
            const Divider(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('합계',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_fmt(month.grossKrw),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.blueGrey)),
                    Text('세금 ${_fmt(month.taxKrw)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.red.shade400)),
                    Text(_fmt(month.netKrw),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2))),
                  ],
                ),
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
  final List<TaxedMonthlyDividend> months;
  final bool showKrw;
  final double rate;

  const _AnnualSummaryCard(
      {required this.months, required this.showKrw, required this.rate});

  String _fmt(double krw) => showKrw
      ? CurrencyFormatter.formatKrw(krw)
      : CurrencyFormatter.formatUsd(krw / rate);

  @override
  Widget build(BuildContext context) {
    // aggregate per assetId
    final grossMap = <int, double>{};
    final taxMap   = <int, double>{};
    final infoMap  = <int, TaxedDividendEntry>{};

    for (final m in months) {
      for (final e in m.entries) {
        grossMap[e.assetId] = (grossMap[e.assetId] ?? 0) + e.grossKrw;
        taxMap[e.assetId]   = (taxMap[e.assetId]   ?? 0) + e.taxKrw;
        infoMap[e.assetId]  ??= e;
      }
    }

    if (infoMap.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('배당 데이터가 없습니다.',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final sorted = infoMap.keys.toList()
      ..sort((a, b) => (grossMap[b] ?? 0).compareTo(grossMap[a] ?? 0));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('연간 종목별 세금',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const Divider(height: 12),
            ...sorted.map((id) {
              final e = infoMap[id]!;
              final gross = grossMap[id] ?? 0;
              final tax   = taxMap[id] ?? 0;
              final net   = gross - tax;
              final titleText = e.isKrStock ? e.name : e.symbol;
              final subtitleText = e.isKrStock ? e.symbol : e.name;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(titleText,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(subtitleText,
                    style: const TextStyle(fontSize: 11)),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_fmt(gross),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.blueGrey)),
                    Text('세금 ${_fmt(tax)} (${(e.taxRate * 100).toStringAsFixed(1)}%)',
                        style: TextStyle(
                            fontSize: 11, color: Colors.red.shade400)),
                    Text(_fmt(net),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
