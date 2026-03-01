import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/entities/portfolio.dart';
import '../../providers/portfolio_providers.dart';
import '../../providers/database_providers.dart';
import '../../../services/notification_service.dart';

class PortfolioFormScreen extends ConsumerStatefulWidget {
  final int? portfolioId;

  const PortfolioFormScreen({super.key, this.portfolioId});

  @override
  ConsumerState<PortfolioFormScreen> createState() =>
      _PortfolioFormScreenState();
}

class _PortfolioFormScreenState
    extends ConsumerState<PortfolioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _deviationCtrl = TextEditingController(text: '5.0');

  String _baseCurrency = 'KRW';
  String? _rebalancePeriod;
  DateTime? _nextRebalanceDate;
  bool _loading = false;

  bool get _isEditing => widget.portfolioId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final portfolio = await ref
        .read(portfolioRepositoryProvider)
        .getPortfolioById(widget.portfolioId!);
    if (portfolio != null && mounted) {
      _nameCtrl.text = portfolio.name;
      _descCtrl.text = portfolio.description ?? '';
      _deviationCtrl.text =
          portfolio.deviationThreshold.toStringAsFixed(1);
      setState(() {
        _baseCurrency = portfolio.baseCurrency;
        _rebalancePeriod = portfolio.rebalancePeriod;
        _nextRebalanceDate = portfolio.nextRebalanceDate;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _deviationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '포트폴리오 수정' : '포트폴리오 생성'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '포트폴리오 이름 *',
                hintText: '예: 글로벌 분산 투자',
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? '이름을 입력하세요' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
                hintText: '포트폴리오 설명',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_baseCurrency),
              initialValue: _baseCurrency,
              decoration: const InputDecoration(labelText: '기준 통화'),
              items: const [
                DropdownMenuItem(value: 'KRW', child: Text('KRW (원)')),
                DropdownMenuItem(value: 'USD', child: Text('USD (달러)')),
              ],
              onChanged: (v) => setState(() => _baseCurrency = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _deviationCtrl,
              decoration: const InputDecoration(
                labelText: '비중 이탈 임계값 (%)',
                hintText: '예: 5.0',
                suffixText: '%',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return '임계값을 입력하세요';
                final d = double.tryParse(v);
                if (d == null || d < 0 || d > 100) {
                  return '0~100 사이 값을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              key: ValueKey(_rebalancePeriod),
              initialValue: _rebalancePeriod,
              decoration: const InputDecoration(labelText: '리밸런싱 주기'),
              items: const [
                DropdownMenuItem(value: null, child: Text('없음')),
                DropdownMenuItem(
                    value: 'monthly', child: Text('매월')),
                DropdownMenuItem(
                    value: 'quarterly', child: Text('분기')),
                DropdownMenuItem(
                    value: 'yearly', child: Text('매년')),
              ],
              onChanged: (v) => setState(() => _rebalancePeriod = v),
            ),
            if (_rebalancePeriod != null) ...[
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('다음 리밸런싱 날짜'),
                subtitle: Text(_nextRebalanceDate != null
                    ? '${_nextRebalanceDate!.year}-${_nextRebalanceDate!.month.toString().padLeft(2, '0')}-${_nextRebalanceDate!.day.toString().padLeft(2, '0')}'
                    : '날짜 선택'),
                trailing: const Icon(Icons.calendar_today),
                shape: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _nextRebalanceDate ??
                        DateTime.now()
                            .add(const Duration(days: 90)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365 * 5)),
                  );
                  if (date != null) {
                    setState(() => _nextRebalanceDate = date);
                  }
                },
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isEditing ? '저장' : '생성'),
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
      final portfolio = Portfolio(
        id: widget.portfolioId ?? 0,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        baseCurrency: _baseCurrency,
        rebalancePeriod: _rebalancePeriod,
        nextRebalanceDate: _nextRebalanceDate,
        deviationThreshold: double.parse(_deviationCtrl.text),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final actions = ref.read(portfolioActionsProvider);

      if (_isEditing) {
        await actions.update(portfolio);
      } else {
        final newId = await actions.create(portfolio);

        if (_nextRebalanceDate != null) {
          await NotificationService.instance.scheduleRebalanceReminder(
            portfolioId: newId,
            portfolioName: portfolio.name,
            scheduledDate: _nextRebalanceDate!,
          );
        }
      }

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
