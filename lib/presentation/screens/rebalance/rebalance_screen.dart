import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../providers/metrics_providers.dart';

class RebalanceScreen extends ConsumerWidget {
  final int portfolioId;

  const RebalanceScreen({super.key, required this.portfolioId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightsAsync =
        ref.watch(portfolioWeightsProvider(portfolioId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('리밸런싱'),
      ),
      body: weightsAsync.when(
        data: (gaps) => _buildBody(context, gaps),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<RebalancingGap> gaps) {
    if (gaps.isEmpty) {
      return const Center(
        child: Text('자산이 없거나 가격 정보가 없습니다'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '리밸런싱 분석',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '현재 비중과 목표 비중의 차이를 보여줍니다.\n갭이 큰 자산부터 조정이 필요합니다.',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...gaps.map((gap) => _GapTile(gap: gap)),
      ],
    );
  }
}

class _GapTile extends StatelessWidget {
  final RebalancingGap gap;

  const _GapTile({required this.gap});

  String _unitLabel() {
    if (gap.assetType == 'gold') return 'g';
    if (gap.assetType == 'crypto') return '개';
    return '주';
  }

  @override
  Widget build(BuildContext context) {
    final isOver = gap.gap > 0;
    final gapColor = gap.gap.abs() >= 5
        ? (isOver ? AppColors.negative : AppColors.positive)
        : AppColors.neutral;

    // Calculate target value and shares to trade
    final targetValue =
        gap.totalPortfolioValue * gap.targetWeight / 100;
    final diffKrw = targetValue - gap.currentValue;
    final unit = _unitLabel();

    // Calculate quantity to trade
    double qtyToTrade = 0;
    if (gap.pricePerUnit > 0) {
      qtyToTrade = diffKrw / gap.pricePerUnit;
      // For USD assets, pricePerUnit is in USD but diffKrw is in KRW
      // currentValue = holdings * pricePerUnit * rate (for USD)
      // So diffKrw / (pricePerUnit * rate) = qty
      // But we can derive rate: if holdings > 0, rate = currentValue / (holdings * pricePerUnit)
      if (gap.currency == 'USD' && gap.holdings > 0 && gap.pricePerUnit > 0) {
        final impliedRate =
            gap.currentValue / (gap.holdings * gap.pricePerUnit);
        qtyToTrade = diffKrw / (gap.pricePerUnit * impliedRate);
      }
    }

    final isBuy = qtyToTrade > 0;
    final absQty = qtyToTrade.abs();
    // Format quantity based on asset type
    final String qtyStr;
    if (gap.assetType == 'gold') {
      qtyStr = absQty.toStringAsFixed(1);
    } else if (gap.assetType == 'crypto') {
      // Crypto: show up to 6 decimal places, trim trailing zeros
      qtyStr = absQty.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    } else {
      qtyStr = absQty.toStringAsFixed(0);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gap.assetName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (gap.assetType == 'krStock' && gap.symbol.isNotEmpty)
                        Text(
                          gap.symbol,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  CurrencyFormatter.formatSignedPercent(gap.gap),
                  style: TextStyle(
                    color: gapColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _WeightBar(
                    current: gap.currentWeight,
                    target: gap.targetWeight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '현재 ${gap.currentWeight.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '목표 ${gap.targetWeight.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            if (gap.pricePerUnit > 0 && diffKrw.abs() >= 1000) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Icon(
                    isBuy ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 18,
                    color: isBuy ? AppColors.positive : AppColors.negative,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isBuy ? '매수 $qtyStr$unit' : '매도 $qtyStr$unit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isBuy ? AppColors.positive : AppColors.negative,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '약 ${CurrencyFormatter.formatKrw(diffKrw.abs())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
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

class _WeightBar extends StatelessWidget {
  final double current;
  final double target;

  const _WeightBar({required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    final max = [current, target, 100.0].reduce(
        (a, b) => a > b ? a : b);
    final targetFraction = (target / max).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        final markerLeft =
            (targetFraction * barWidth - 1).clamp(0.0, barWidth - 2);

        return Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (current / max).clamp(0.0, 1.0),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Positioned(
              left: markerLeft,
              child: Container(
                width: 2,
                height: 8,
                color: AppColors.negative,
              ),
            ),
          ],
        );
      },
    );
  }
}
