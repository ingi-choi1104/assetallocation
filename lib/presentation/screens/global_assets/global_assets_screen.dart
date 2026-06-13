import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/enums/asset_type.dart';
import '../../providers/metrics_providers.dart';
import '../../providers/price_providers.dart';

class GlobalAssetsScreen extends ConsumerWidget {
  const GlobalAssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(globalAssetsProvider);
    final showKrw = ref.watch(showKrwProvider);
    final rate = ref.watch(usdKrwRateSyncProvider);
    final fxRates = ref.watch(fxRatesSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('전체 보유 종목'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('KRW'),
              selected: showKrw,
              onSelected: (v) =>
                  ref.read(showKrwProvider.notifier).toggle(v),
            ),
          ),
        ],
      ),
      body: assetsAsync.when(
        data: (assets) {
          if (assets.isEmpty) {
            return const Center(
              child: Text('보유 종목이 없습니다',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          final totalKrw =
              assets.fold(0.0, (sum, a) => sum + a.totalValueKrw);

          final grouped = <AssetType, List<GlobalAssetSummary>>{};
          for (final a in assets) {
            grouped.putIfAbsent(a.assetType, () => []).add(a);
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _TotalHeader(
                  totalKrw: totalKrw, showKrw: showKrw, rate: rate),
              for (final type in AssetType.values)
                if (grouped.containsKey(type)) ...[
                  _TypeHeader(assetType: type),
                  for (final asset in grouped[type]!)
                    _AssetTile(
                      asset: asset,
                      showKrw: showKrw,
                      rate: rate,
                      fxRates: fxRates,
                    ),
                ],
              const SizedBox(height: 16),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('오류: $e', textAlign: TextAlign.center)),
      ),
    );
  }
}

// ── Total value header ────────────────────────────────────────────────────────

class _TotalHeader extends StatelessWidget {
  final double totalKrw;
  final bool showKrw;
  final double rate;

  const _TotalHeader(
      {required this.totalKrw, required this.showKrw, required this.rate});

  @override
  Widget build(BuildContext context) {
    final valueStr = showKrw
        ? CurrencyFormatter.formatKrw(totalKrw)
        : CurrencyFormatter.formatUsd(totalKrw / rate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('전체 평가금액',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(valueStr,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ── Section header per asset type ─────────────────────────────────────────────

class _TypeHeader extends StatelessWidget {
  final AssetType assetType;

  const _TypeHeader({required this.assetType});

  static String _label(AssetType t) {
    switch (t) {
      case AssetType.usStock:
        return '미국 주식/ETF';
      case AssetType.krStock:
        return '한국 주식/ETF';
      case AssetType.crypto:
        return '암호화폐';
      case AssetType.krFund:
        return '한국 펀드';
      case AssetType.gold:
        return '금 현물';
      case AssetType.cash:
        return '현금';
    }
  }

  static IconData _icon(AssetType t) {
    switch (t) {
      case AssetType.usStock:
        return Icons.bar_chart;
      case AssetType.krStock:
        return Icons.bar_chart_outlined;
      case AssetType.crypto:
        return Icons.currency_bitcoin;
      case AssetType.krFund:
        return Icons.account_balance;
      case AssetType.gold:
        return Icons.diamond_outlined;
      case AssetType.cash:
        return Icons.account_balance_wallet_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
      child: Row(
        children: [
          Icon(_icon(assetType), size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            _label(assetType),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual asset tile ─────────────────────────────────────────────────────

class _AssetTile extends StatelessWidget {
  final GlobalAssetSummary asset;
  final bool showKrw;
  final double rate;
  final Map<String, double> fxRates;

  static final _compact = NumberFormat('#,##0.####');

  const _AssetTile({
    required this.asset,
    required this.showKrw,
    required this.rate,
    required this.fxRates,
  });

  String _holdingsText() {
    final isCash = asset.assetType == AssetType.cash;
    if (isCash) {
      final ccy = asset.currency.toUpperCase();
      switch (ccy) {
        case 'KRW':
          return CurrencyFormatter.formatKrw(asset.totalHoldings);
        case 'USD':
          return CurrencyFormatter.formatUsd(asset.totalHoldings);
        case 'EUR':
          return '€${_compact.format(asset.totalHoldings)}';
        case 'JPY':
          return '¥${_compact.format(asset.totalHoldings)}';
        case 'CNY':
          return '¥${_compact.format(asset.totalHoldings)} CNY';
        default:
          return '${_compact.format(asset.totalHoldings)} $ccy';
      }
    }
    return '${_compact.format(asset.totalHoldings)} 주';
  }

  String _valueText() {
    return showKrw
        ? CurrencyFormatter.formatKrw(asset.totalValueKrw)
        : CurrencyFormatter.formatUsd(asset.totalValueKrw / rate);
  }

  String _weightText() =>
      '${(asset.weight * 100).toStringAsFixed(1)}%';

  String _priceText() {
    if (asset.assetType == AssetType.cash) return '';
    final ccy = asset.currency.toUpperCase();
    return CurrencyFormatter.format(asset.currentPrice, ccy);
  }

  @override
  Widget build(BuildContext context) {
    final isKr = asset.assetType == AssetType.krStock;
    final titleText =
        isKr ? asset.name : asset.symbol;
    final subtitleText =
        isKr ? asset.symbol : (asset.name.isNotEmpty ? asset.name : null);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      title: Text(
        titleText,
        style:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitleText != null)
            Text(subtitleText,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Row(
            children: [
              Text(_holdingsText(),
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade700)),
              if (_priceText().isNotEmpty) ...[
                const SizedBox(width: 6),
                Text('@ ${_priceText()}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ],
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _valueText(),
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            _weightText(),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
