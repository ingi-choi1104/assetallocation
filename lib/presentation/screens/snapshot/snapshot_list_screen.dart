import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../domain/entities/portfolio_snapshot.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../providers/asset_providers.dart';
import '../../providers/investment_providers.dart';
import '../../providers/metrics_providers.dart';
import '../../providers/portfolio_providers.dart';
import '../../providers/price_providers.dart';
import '../../providers/snapshot_providers.dart';

class SnapshotListScreen extends ConsumerStatefulWidget {
  const SnapshotListScreen({super.key});

  @override
  ConsumerState<SnapshotListScreen> createState() => _SnapshotListScreenState();
}

class _SnapshotListScreenState extends ConsumerState<SnapshotListScreen> {
  bool _isTaking = false;

  Future<void> _takeSnapshot() async {
    setState(() => _isTaking = true);
    try {
      final portfolios = await ref.read(portfoliosStreamProvider.future);
      if (portfolios.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('포트폴리오가 없습니다.')),
          );
        }
        return;
      }

      final rate = await ref.read(usdKrwRateProvider.future);
      final portfolioEntries = <PortfolioSnapshotEntry>[];
      double grandTotal = 0;
      double grandInvested = 0;

      // 전체 연수익률 계산용 — 모든 포트폴리오 투자 기록
      final allAmounts = <double>[];
      final allDates = <DateTime>[];

      for (final p in portfolios) {
        final metrics = await ref.read(portfolioMetricsProvider(p.id).future);
        final weights = await ref.read(portfolioWeightsProvider(p.id).future);
        final pas =
            await ref.read(portfolioAssetsStreamProvider(p.id).future);
        final investments =
            await ref.read(investmentsStreamProvider(p.id).future);

        // assetId → symbol 매핑
        final symbolMap = {
          for (final pa in pas) pa.assetId: pa.asset?.symbol ?? '',
        };

        final assetEntries = weights.map((g) {
          final isUsd = g.currency.toUpperCase() == 'USD';
          final priceKrw = isUsd ? g.pricePerUnit * rate : g.pricePerUnit;
          return AssetSnapshotEntry(
            name: g.assetName,
            symbol: symbolMap[g.assetId] ?? '',
            assetType: g.assetType,
            holdings: g.holdings,
            priceKrw: priceKrw,
            valueKrw: g.currentValue,
            targetWeight: g.targetWeight,
            currency: g.currency,
          );
        }).toList();

        portfolioEntries.add(PortfolioSnapshotEntry(
          portfolioId: p.id,
          name: p.name,
          valueKrw: metrics.totalValue,
          invested: metrics.totalInvested,
          returnRate: metrics.returnRate,
          annualizedReturnRate: metrics.annualizedReturnRate,
          assets: assetEntries,
        ));

        grandTotal += metrics.totalValue;
        grandInvested += metrics.totalInvested;

        for (final inv in investments) {
          allAmounts.add(inv.amount);
          allDates.add(inv.investmentDate);
        }
      }

      // 전체 연수익률: 제외 여부 무관하게 모든 포트폴리오 투자 기록으로 계산
      double grandAnnualizedReturn = 0;
      if (allAmounts.isNotEmpty && grandTotal > 0) {
        grandAnnualizedReturn =
            FinancialCalculator.annualizedReturnFromInvestments(
          investmentAmounts: allAmounts,
          investmentDates: allDates,
          currentValueKrw: grandTotal,
        );
      }

      final now = DateTime.now();
      final snapshot = PortfolioSnapshot(
        id: now.millisecondsSinceEpoch,
        takenAt: now,
        totalValueKrw: grandTotal,
        totalInvested: grandInvested,
        returnRate: grandInvested == 0
            ? 0
            : (grandTotal - grandInvested) / grandInvested,
        annualizedReturnRate: grandAnnualizedReturn,
        portfolios: portfolioEntries,
      );

      await ref.read(snapshotNotifierProvider.notifier).addSnapshot(snapshot);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '스냅샷이 저장되었습니다. (${CurrencyFormatter.formatKrw(grandTotal)})'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('스냅샷 저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshots = ref.watch(snapshotNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('스냅샷 히스토리')),
      body: Column(
        children: [
          Expanded(
            child: snapshots.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '아직 스냅샷이 없습니다.\n아래 버튼으로 현재 자산 현황을 기록해보세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: snapshots.length,
                    itemBuilder: (_, i) =>
                        _SnapshotCard(snapshot: snapshots[i]),
                  ),
          ),
          // 배너 광고 (홈바 위에 표시)
          const SafeArea(top: false, child: BannerAdWidget()),
        ],
      ),
      floatingActionButton: Padding(
        // 배너 광고 높이만큼 FAB를 위로 올려 겹치지 않도록
        padding: EdgeInsets.only(
            bottom: AdSize.banner.height.toDouble()),
        child: FloatingActionButton.extended(
          onPressed: _isTaking ? null : _takeSnapshot,
          icon: _isTaking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.camera_alt),
          label: Text(_isTaking ? '저장 중...' : '스냅샷 찍기'),
        ),
      ),
    );
  }
}

class _SnapshotCard extends ConsumerWidget {
  final PortfolioSnapshot snapshot;
  const _SnapshotCard({required this.snapshot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr =
        DateFormat('yyyy년 M월 d일 HH:mm').format(snapshot.takenAt);
    final returnColor =
        snapshot.returnRate >= 0 ? AppColors.positive : AppColors.negative;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/snapshots/${snapshot.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.camera_alt, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  const Spacer(),
                  if (snapshot.memo != null)
                    Flexible(
                      child: Text(
                        snapshot.memo!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                CurrencyFormatter.formatKrw(snapshot.totalValueKrw),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (snapshot.totalInvested > 0) ...[
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
                      const SizedBox(width: 12),
                      Text(
                        '연 ${CurrencyFormatter.formatSignedPercent(snapshot.annualizedReturnRate * 100)}',
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
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: snapshot.portfolios.map((p) {
                  return Chip(
                    label: Text(
                      '${p.name}  ${CurrencyFormatter.formatKrw(p.valueKrw)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
