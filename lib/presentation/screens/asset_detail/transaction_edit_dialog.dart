import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/thousands_input_formatter.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/enums/asset_type.dart';
import '../../../domain/enums/transaction_type.dart';
import '../../providers/transaction_providers.dart';

/// 거래 내역을 눌렀을 때 뜨는 수정 팝업. 매수/매도 구분, 수량(금액),
/// 거래 날짜, 메모를 고칠 수 있다.
Future<void> showTransactionEditDialog(
  BuildContext context, {
  required Transaction transaction,
  AssetType? assetType,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TransactionEditDialog(
      transaction: transaction,
      assetType: assetType,
    ),
  );
}

class _TransactionEditDialog extends ConsumerStatefulWidget {
  final Transaction transaction;
  final AssetType? assetType;

  const _TransactionEditDialog({
    required this.transaction,
    this.assetType,
  });

  @override
  ConsumerState<_TransactionEditDialog> createState() =>
      _TransactionEditDialogState();
}

class _TransactionEditDialogState
    extends ConsumerState<_TransactionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _memoCtrl;

  late TransactionType _type;
  late DateTime _date;
  bool _saving = false;

  bool get _isCash => widget.assetType == AssetType.cash;
  bool get _isGold => widget.assetType == AssetType.gold;

  @override
  void initState() {
    super.initState();
    _quantityCtrl = TextEditingController(
      text: ThousandsInputFormatter.display(widget.transaction.quantity),
    );
    _memoCtrl = TextEditingController(text: widget.transaction.memo ?? '');
    _type = widget.transaction.type;
    _date = widget.transaction.transactionDate;
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  String get _dateLabel =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-'
      '${_date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('거래 수정'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.buy,
                    label: Text('매수'),
                    icon: Icon(Icons.trending_up, size: 18),
                  ),
                  ButtonSegment(
                    value: TransactionType.sell,
                    label: Text('매도'),
                    icon: Icon(Icons.trending_down, size: 18),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _isCash ? '금액 *' : '수량 *',
                  suffixText: _isGold ? 'g' : (_isCash ? '원' : null),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  ThousandsInputFormatter(decimalRange: _isCash ? 0 : 8),
                ],
                validator: (v) {
                  final n = ThousandsInputFormatter.parse(v);
                  if (n == null || n <= 0) {
                    return _isCash ? '유효한 금액을 입력하세요' : '유효한 수량을 입력하세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('거래 날짜', style: TextStyle(fontSize: 13)),
                subtitle: Text(_dateLabel),
                trailing: const Icon(Icons.calendar_today, size: 18),
                shape: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _memoCtrl,
                decoration: const InputDecoration(labelText: '메모 (선택)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final memo = _memoCtrl.text.trim();
      await ref.read(transactionActionsProvider).updateTransaction(
            Transaction(
              id: widget.transaction.id,
              portfolioAssetId: widget.transaction.portfolioAssetId,
              type: _type,
              quantity: ThousandsInputFormatter.parse(_quantityCtrl.text)!,
              price: widget.transaction.price,
              exchangeRate: widget.transaction.exchangeRate,
              fee: widget.transaction.fee,
              transactionDate: _date,
              memo: memo.isEmpty ? null : memo,
              createdAt: widget.transaction.createdAt,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 실패: $e')),
        );
      }
    }
  }
}
