import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/enums/asset_type.dart';
import '../../../domain/enums/transaction_type.dart';
import '../../providers/asset_providers.dart';
import '../../providers/transaction_providers.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final int portfolioAssetId;
  final int portfolioId;

  const TransactionFormScreen({
    super.key,
    required this.portfolioAssetId,
    required this.portfolioId,
  });

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState
    extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  TransactionType _type = TransactionType.buy;
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetsAsync =
        ref.watch(portfolioAssetsStreamProvider(widget.portfolioId));
    final pa = assetsAsync.value
        ?.where((a) => a.id == widget.portfolioAssetId)
        .firstOrNull;
    final isGold = pa?.asset?.assetType == AssetType.gold;
    final isCash = pa?.asset?.assetType == AssetType.cash;

    return Scaffold(
      appBar: AppBar(title: const Text('거래 입력')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Buy / Sell toggle
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.buy,
                  label: Text('매수'),
                  icon: Icon(Icons.trending_up),
                ),
                ButtonSegment(
                  value: TransactionType.sell,
                  label: Text('매도'),
                  icon: Icon(Icons.trending_down),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) =>
                  setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),

            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('거래 날짜'),
              subtitle: Text(
                  '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today),
              shape: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 16),

            // Quantity / Amount
            TextFormField(
              controller: _quantityCtrl,
              decoration: InputDecoration(
                labelText: isCash ? '금액 *' : '수량 *',
                hintText: isCash
                    ? '예: 1000000'
                    : isGold
                        ? '예: 3.75'
                        : '예: 10.5',
                suffixText: isGold ? 'g' : null,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return isCash ? '금액을 입력하세요' : '수량을 입력하세요';
                }
                final n = double.tryParse(v);
                if (n == null || n <= 0) {
                  return isCash ? '유효한 금액을 입력하세요' : '유효한 수량을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Memo
            TextFormField(
              controller: _memoCtrl,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final tx = Transaction(
        id: 0,
        portfolioAssetId: widget.portfolioAssetId,
        type: _type,
        quantity: double.parse(_quantityCtrl.text),
        price: 0,
        exchangeRate: 1.0,
        fee: 0,
        transactionDate: _date,
        memo: _memoCtrl.text.isEmpty ? null : _memoCtrl.text,
        createdAt: DateTime.now(),
      );

      await ref.read(transactionActionsProvider).addTransaction(tx);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
