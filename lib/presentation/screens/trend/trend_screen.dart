import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../domain/entities/asset_trend.dart';
import '../../providers/asset_trend_providers.dart';

/// 추이 탭 — 전체 자산의 평가금액(실선)과 투입금액(점선)을 최대 5년까지
/// 일별 / 주별 / 월별로 보여준다.
class TrendScreen extends ConsumerStatefulWidget {
  const TrendScreen({super.key});

  @override
  ConsumerState<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends ConsumerState<TrendScreen> {
  /// x축에 항상 놓는 눈금 수. 선택한 단위가 곧 표시 범위가 된다 —
  /// 월별이면 최근 60개월(5년), 주별이면 60주, 일별이면 60일.
  static const int _visibleUnits = 60;
  static const double _chartHeight = 260;

  static final NumberFormat _krwFormat = NumberFormat('#,##0', 'ko_KR');
  static final DateFormat _dayFormat = DateFormat('M/d');
  static final DateFormat _monthFormat = DateFormat('yy.M');
  static final DateFormat _fullFormat = DateFormat('yyyy.MM.dd');

  TrendInterval _interval = TrendInterval.daily;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(assetTrendProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('자산 추이'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '시세 다시 받기',
            onPressed: () async {
              await ref.read(trendCacheDsProvider).clear();
              ref.read(trendReloadProvider.notifier).state++;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () => const _Centered(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('과거 시세를 불러오는 중…',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              error: (_, __) => const _Centered(
                child: Text('추이를 계산하지 못했습니다',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ),
              data: (series) => series.isUsable
                  ? _buildBody(series)
                  : const _Centered(
                      child: Text('거래 내역을 추가하면 자산 추이가 표시됩니다',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey)),
                    ),
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildBody(TrendSeries series) {
    final points = _visible(series);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _summaryCard(series, points),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legend(series.hasInvested, points),
                const SizedBox(height: 12),
                SizedBox(
                  height: _chartHeight,
                  child: _chart(points, series.hasInvested),
                ),
                const SizedBox(height: 10),
                _intervalChips(),
                if (series.approximated.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${series.approximated.join(', ')}은(는) 과거 시세 제공처가 없어 '
                    '현재가로 근사했습니다',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── 요약 ────────────────────────────────────────────────────────────────────

  Widget _summaryCard(TrendSeries series, List<TrendPoint> points) {
    final value = series.currentValueKrw;
    final invested = series.currentInvestedKrw;
    final profit = value - invested;
    final hasInvested = series.hasInvested && invested > 0;
    final profitColor = AppColors.forChange(profit);
    final start = points.first.date;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('전체 평가금액',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const Spacer(),
                Text(
                  '${_fullFormat.format(start)} ~ '
                  '${_fullFormat.format(points.last.date)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              CurrencyFormatter.formatKrw(value),
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (hasInvested) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _metric('투입금액',
                        CurrencyFormatter.formatKrw(invested), null),
                  ),
                  Expanded(
                    child: _metric(
                      '평가손익',
                      '${profit >= 0 ? '+' : '-'}'
                          '${CurrencyFormatter.formatKrw(profit.abs())}',
                      profitColor,
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      '수익률',
                      CurrencyFormatter.formatSignedPercent(
                          profit / invested * 100),
                      profitColor,
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

  Widget _metric(String label, String value, Color? color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _legend(bool hasInvested, List<TrendPoint> points) {
    return Row(
      children: [
        _legendItem('평가금액', AppColors.primary, dashed: false),
        if (hasInvested) ...[
          const SizedBox(width: 16),
          _legendItem('투입금액', Colors.grey.shade600, dashed: true),
        ],
        const Spacer(),
        Text(
          '최근 ${points.length}$_unitSuffix',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  String get _unitSuffix {
    switch (_interval) {
      case TrendInterval.daily:
        return '일';
      case TrendInterval.weekly:
        return '주';
      case TrendInterval.monthly:
        return '개월';
    }
  }

  Widget _legendItem(String label, Color color, {required bool dashed}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 3,
          child: CustomPaint(
            painter: _LinePainter(color: color, dashed: dashed),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  // ── 기간 단위 선택 ──────────────────────────────────────────────────────────

  Widget _intervalChips() {
    return Row(
      children: [
        for (final i in TrendInterval.values)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _interval = i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: _interval == i
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _interval == i
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  i.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        _interval == i ? FontWeight.bold : FontWeight.normal,
                    color: _interval == i
                        ? AppColors.primary
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── 그래프 ──────────────────────────────────────────────────────────────────

  Widget _chart(List<TrendPoint> points, bool hasInvested) {
    final valueSpots = [
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].valueKrw)
    ];
    final investedSpots = hasInvested
        ? [
            for (int i = 0; i < points.length; i++)
              FlSpot(i.toDouble(), points[i].investedKrw)
          ]
        : const <FlSpot>[];

    var minY = valueSpots.first.y;
    var maxY = valueSpots.first.y;
    for (final s in [...valueSpots, ...investedSpots]) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    final span = (maxY - minY).abs();
    final pad = span == 0 ? (maxY.abs() * 0.1 + 1) : span * 0.12;
    minY -= pad;
    maxY += pad;
    final gridStep = (maxY - minY) / 4;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: gridStep,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: gridStep,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  _compactKrw(value),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: _labelInterval(points.length),
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _axisFormat().format(points[i].date),
                    style:
                        TextStyle(fontSize: 9, color: Colors.grey.shade500),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            tooltipRoundedRadius: 6,
            maxContentWidth: 220,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItems: (touched) {
              return [
                for (int i = 0; i < touched.length; i++)
                  if (i != 0)
                    null
                  else
                    LineTooltipItem(
                      _tooltipText(
                        points[touched[i].x.round().clamp(
                              0,
                              points.length - 1,
                            )],
                        hasInvested,
                      ),
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              ];
            },
          ),
        ),
        lineBarsData: [
          // 평가금액 — 실선이 주된 표시.
          LineChartBarData(
            spots: valueSpots,
            isCurved: true,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            color: AppColors.primary,
            barWidth: 2.4,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.22),
                  AppColors.primary.withValues(alpha: 0.01),
                ],
              ),
            ),
          ),
          // 투입금액 — 점선 보조선.
          if (hasInvested)
            LineChartBarData(
              spots: investedSpots,
              isCurved: false,
              color: Colors.grey.shade600,
              barWidth: 1.4,
              dashArray: const [5, 4],
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  String _tooltipText(TrendPoint point, bool hasInvested) {
    final buffer = StringBuffer()
      ..writeln(_fullFormat.format(point.date))
      ..write('평가 ₩${_krwFormat.format(point.valueKrw)}');
    if (hasInvested && point.investedKrw > 0) {
      buffer
        ..writeln()
        ..write('투입 ₩${_krwFormat.format(point.investedKrw)}');
    }
    return buffer.toString();
  }

  // ── 보조 ────────────────────────────────────────────────────────────────────

  /// 선택한 단위로 묶은 뒤 마지막 [_visibleUnits]개만 남긴다.
  /// 데이터가 그보다 적으면 있는 만큼 그린다.
  List<TrendPoint> _visible(TrendSeries series) {
    final aggregated = series.aggregate(_interval);
    if (aggregated.length <= _visibleUnits) return aggregated;
    return aggregated.sublist(aggregated.length - _visibleUnits);
  }

  double _labelInterval(int count) {
    // 60눈금에 라벨 6개 정도가 겹치지 않고 읽힌다.
    final interval = (count / 6).floorToDouble();
    return interval < 1 ? 1 : interval;
  }

  /// x축 라벨은 선택한 단위를 따른다 — 월별은 연·월, 주별·일별은 월/일.
  DateFormat _axisFormat() {
    switch (_interval) {
      case TrendInterval.monthly:
        return _monthFormat;
      case TrendInterval.weekly:
      case TrendInterval.daily:
        return _dayFormat;
    }
  }

  String _compactKrw(double value) {
    final abs = value.abs();
    if (abs >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(abs >= 1000000000 ? 0 : 1)}억';
    }
    if (abs >= 10000) return '${(value / 10000).toStringAsFixed(0)}만';
    return value.toStringAsFixed(0);
  }
}

class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});

  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(32), child: child));
}

/// 범례의 짧은 선 (실선 / 점선).
class _LinePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  const _LinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = dashed ? 1.6 : 2.4
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    const dash = 4.0;
    const gap = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}
