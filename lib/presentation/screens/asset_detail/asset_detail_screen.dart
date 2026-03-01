import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../domain/entities/portfolio_asset.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/enums/asset_type.dart';
import '../../../domain/enums/transaction_type.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../providers/asset_providers.dart';
import '../../providers/price_providers.dart';
import '../../providers/transaction_providers.dart';

class AssetDetailScreen extends ConsumerWidget {
  final int portfolioAssetId;
  final int portfolioId;

  const AssetDetailScreen({
    super.key,
    required this.portfolioAssetId,
    required this.portfolioId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync =
        ref.watch(portfolioAssetsStreamProvider(portfolioId));
    final txAsync =
        ref.watch(transactionsStreamProvider(portfolioAssetId));

    return assetsAsync.when(
      data: (assets) {
        final pa =
            assets.where((a) => a.id == portfolioAssetId).firstOrNull;
        if (pa == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('자산')),
            body: const Center(child: Text('자산을 찾을 수 없습니다')),
          );
        }
        return _AssetDetailView(
          portfolioAsset: pa,
          portfolioId: portfolioId,
          txAsync: txAsync,
        );
      },
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AssetDetailView extends ConsumerWidget {
  final PortfolioAsset portfolioAsset;
  final int portfolioId;
  final AsyncValue<List<Transaction>> txAsync;

  const _AssetDetailView({
    required this.portfolioAsset,
    required this.portfolioId,
    required this.txAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = portfolioAsset.asset;

    return Scaffold(
      appBar: AppBar(
        title: Text(asset?.symbol ?? 'Unknown'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'remove') {
                final confirm = await _confirmRemove(context);
                if (confirm == true && context.mounted) {
                  await ref
                      .read(assetActionsProvider)
                      .removeFromPortfolio(portfolioAsset.id);
                  if (context.mounted) context.pop();
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'remove',
                child: Text('포트폴리오에서 제거',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AssetHeader(portfolioAsset: portfolioAsset),

                  txAsync.when(
                    data: (txs) => _HoldingsSummary(
                      portfolioAsset: portfolioAsset,
                      transactions: txs,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Text(
                      '거래 내역',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  txAsync.when(
                    data: (txs) => txs.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('거래 내역이 없습니다'),
                            ),
                          )
                        : Column(
                            children: txs
                                .map((tx) => _TransactionTile(
                                      tx: tx,
                                      assetType: asset?.assetType,
                                    ))
                                .toList(),
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          // 배너 광고 (홈바 위에 표시)
          const SafeArea(top: false, child: BannerAdWidget()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
            '/portfolio/$portfolioId/asset/${portfolioAsset.id}/transaction'),
        icon: const Icon(Icons.add),
        label: const Text('거래 추가'),
      ),
    );
  }

  Future<bool?> _confirmRemove(BuildContext context) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('자산 제거'),
          content: Text(
              '${portfolioAsset.asset?.name ?? "이 자산"}을(를) 포트폴리오에서 제거하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('제거'),
            ),
          ],
        ),
      );
}

class _AssetHeader extends StatelessWidget {
  final PortfolioAsset portfolioAsset;

  const _AssetHeader({required this.portfolioAsset});

  @override
  Widget build(BuildContext context) {
    final asset = portfolioAsset.asset;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset?.name ?? '',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    asset?.assetType.label ?? '',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (asset?.lastPrice != null)
              Text(
                CurrencyFormatter.format(
                    asset!.lastPrice!, asset.currency),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}

class _HoldingsSummary extends ConsumerWidget {
  final PortfolioAsset portfolioAsset;
  final List<Transaction> transactions;

  const _HoldingsSummary({
    required this.portfolioAsset,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = portfolioAsset.asset;
    final currency = asset?.currency ?? 'KRW';

    // Cash is always 1.0 — skip API call entirely
    final isCash = asset?.assetType == AssetType.cash;
    final livePriceAsync = (asset != null && !isCash)
        ? ref.watch(livePriceProvider(asset.id))
        : const AsyncValue<double?>.data(null);
    final currentPrice = isCash
        ? 1.0
        : livePriceAsync.when(
            data: (p) => p ?? asset?.lastPrice ?? 0,
            loading: () => asset?.lastPrice ?? 0,
            error: (_, __) => asset?.lastPrice ?? 0,
          );

    final holdings = FinancialCalculator.calculateHoldings(
      transactions: transactions,
    );

    final currentValue = holdings * currentPrice;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('보유 현황',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if (livePriceAsync.isLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _Row(
              asset?.assetType == AssetType.cash ? '보유 금액' : '보유 수량',
              asset?.assetType == AssetType.cash
                  ? CurrencyFormatter.format(holdings, currency)
                  : asset?.assetType == AssetType.gold
                      ? '${holdings.toStringAsFixed(holdings < 1 ? 4 : 2)} g'
                      : holdings.toStringAsFixed(holdings < 1 ? 6 : 2),
            ),
            if (asset?.assetType != AssetType.cash)
              _Row('현재 평가금액',
                  CurrencyFormatter.format(currentValue, currency)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final Transaction tx;
  final AssetType? assetType;

  const _TransactionTile({required this.tx, this.assetType});

  String _fmtQty(double qty) {
    if (assetType == AssetType.cash) {
      return CurrencyFormatter.formatKrw(qty);
    }
    return qty.toStringAsFixed(qty < 1 ? 6 : 2);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBuy = tx.type == TransactionType.buy;
    final dateStr =
        '${tx.transactionDate.year}-'
        '${tx.transactionDate.month.toString().padLeft(2, '0')}-'
        '${tx.transactionDate.day.toString().padLeft(2, '0')}';

    // 단가 미입력 거래는 수량(금액)만 표시
    final priceStr = tx.price > 0
        ? '${_fmtQty(tx.quantity)} × ${tx.price}'
        : _fmtQty(tx.quantity);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isBuy
            ? AppColors.positive.withValues(alpha: 0.1)
            : AppColors.negative.withValues(alpha: 0.1),
        child: Icon(
          isBuy ? Icons.trending_up : Icons.trending_down,
          color: isBuy ? AppColors.positive : AppColors.negative,
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(isBuy ? '매수' : '매도'),
          Text(priceStr, style: const TextStyle(fontSize: 13)),
        ],
      ),
      subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline,
            color: Colors.red.withValues(alpha: 0.7), size: 20),
        tooltip: '거래 삭제',
        onPressed: () => _confirmDelete(context, ref),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('거래 삭제'),
        content: const Text('이 거래 내역을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref
          .read(transactionActionsProvider)
          .deleteTransaction(tx.id);
    }
  }
}
