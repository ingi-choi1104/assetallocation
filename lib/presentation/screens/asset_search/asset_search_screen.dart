import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/entities/asset.dart';
import '../../../domain/enums/asset_type.dart';
import '../../providers/asset_providers.dart';
import '../../providers/database_providers.dart';

class AssetSearchScreen extends ConsumerStatefulWidget {
  final int portfolioId;

  const AssetSearchScreen({super.key, required this.portfolioId});

  @override
  ConsumerState<AssetSearchScreen> createState() =>
      _AssetSearchScreenState();
}

class _AssetSearchScreenState
    extends ConsumerState<AssetSearchScreen> {
  final _searchCtrl = TextEditingController();
  AssetType? _selectedType;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(assetSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('자산 검색')),
      body: Column(
        children: [
          // Search input
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '심볼 또는 이름 검색 (예: SPY, AAPL, bitcoin)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(assetSearchProvider.notifier).clear();
                        },
                      )
                    : null,
              ),
              onChanged: (q) {
                setState(() {});
                ref
                    .read(assetSearchProvider.notifier)
                    .search(q, type: _selectedType);
              },
            ),
          ),

          // Type filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('전체'),
                  selected: _selectedType == null,
                  onSelected: (_) {
                    setState(() => _selectedType = null);
                    ref.read(assetSearchProvider.notifier).search(
                          _searchCtrl.text,
                          type: null,
                        );
                  },
                ),
                const SizedBox(width: 8),
                ...AssetType.values.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(t.label),
                      selected: _selectedType == t,
                      onSelected: (_) {
                        setState(() => _selectedType = t);
                        ref.read(assetSearchProvider.notifier).search(
                              _searchCtrl.text,
                              type: t,
                            );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Results
          Expanded(
            child: searchState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : searchState.error != null
                    ? Center(child: Text('오류: ${searchState.error}'))
                    : searchState.results.isEmpty
                        ? Center(
                            child: Text(
                              _searchCtrl.text.isEmpty
                                  ? '위에서 자산을 검색하세요'
                                  : '검색 결과가 없습니다',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: searchState.results.length,
                            itemBuilder: (ctx, i) => _AssetResultTile(
                              asset: searchState.results[i],
                              portfolioId: widget.portfolioId,
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _AssetResultTile extends ConsumerWidget {
  final Asset asset;
  final int portfolioId;

  const _AssetResultTile({
    required this.asset,
    required this.portfolioId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _typeColor(asset.assetType).withValues(alpha: 0.1),
        child: Text(
          asset.assetType.value.substring(0, 2).toUpperCase(),
          style: TextStyle(
            color: _typeColor(asset.assetType),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(asset.symbol),
      subtitle: Text(asset.name),
      trailing: Text(
        asset.assetType.label,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      onTap: () => _addAsset(context, ref, asset),
    );
  }

  Color _typeColor(AssetType type) {
    switch (type) {
      case AssetType.usStock:
        return Colors.blue;
      case AssetType.krStock:
        return Colors.red;
      case AssetType.crypto:
        return Colors.orange;
      case AssetType.krFund:
        return Colors.green;
      case AssetType.gold:
        return Colors.amber;
      case AssetType.cash:
        return Colors.teal;
    }
  }

  Future<void> _addAsset(
      BuildContext context, WidgetRef ref, Asset asset) async {
    // 중복 체크: 이미 포트폴리오에 같은 심볼이 있으면 팝업 표시
    final existing =
        ref.read(portfolioAssetsStreamProvider(portfolioId)).value ?? [];
    final isDuplicate = existing.any(
      (pa) =>
          pa.asset?.symbol.toUpperCase() == asset.symbol.toUpperCase(),
    );
    if (isDuplicate) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('이미 추가된 자산'),
            content:
                Text('${asset.symbol}은(는) 이미 포트폴리오에 추가된 자산입니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Show weight dialog
    final weight = await _showWeightDialog(context);
    if (weight == null) return;

    try {
      // Upsert asset
      final assetId =
          await ref.read(assetActionsProvider).upsertAsset(asset);

      // Get current sort order
      final existingAssets = await ref
          .read(assetRepositoryProvider)
          .getPortfolioAssets(portfolioId);

      await ref.read(assetActionsProvider).addToPortfolio(
            portfolioId: portfolioId,
            assetId: assetId,
            targetWeight: weight,
            sortOrder: existingAssets.length,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${asset.name}이(가) 추가되었습니다')),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  Future<double?> _showWeightDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: '10.0');
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${asset.symbol} 목표 비중 설정'),
        content: TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '목표 비중 (%)',
            suffixText: '%',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              Navigator.pop(ctx, v);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}
