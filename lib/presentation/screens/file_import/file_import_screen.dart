import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/database/app_database.dart';
import '../../../data/datasources/local/import_mapping_local_ds.dart';
import '../../../data/datasources/local/table_file_parser.dart';
import '../../../data/repositories/import_writer.dart';
import '../../../domain/entities/import_table.dart';
import '../../../domain/entities/portfolio.dart';
import '../../../domain/enums/asset_type.dart';
import '../../../domain/services/column_matcher.dart';
import '../../providers/database_providers.dart';
import '../../providers/file_import_providers.dart';
import '../../providers/portfolio_providers.dart';
import '../../providers/price_providers.dart';

/// CSV·엑셀 표 파일을 올려 보유 종목을 한 번에 등록하는 화면.
///
/// 로직은 전부 모듈에 있다 — 이 화면은 조립만 한다:
/// [TableFileParser]가 바이트를 표로, [ColumnMatcher]가 표를 매핑·미리보기로,
/// [ImportMappingLocalDataSource]가 매핑을 기억하고, [ImportWriter]가 쓴다.
class FileImportScreen extends ConsumerStatefulWidget {
  const FileImportScreen({super.key});

  @override
  ConsumerState<FileImportScreen> createState() => _FileImportScreenState();
}

class _FileImportScreenState extends ConsumerState<FileImportScreen> {
  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _numberFormat = NumberFormat('#,###');

  ImportTable? _table;
  String _fileName = '';
  Map<ColumnRole, int> _mapping = {};
  AssetType? _forcedType;
  DateTime _acquiredDate = DateTime.now();

  Portfolio? _selectedPortfolio;
  bool _createNew = false;
  final _newNameCtrl = TextEditingController();

  Set<String> _alreadyHeldKeys = {};
  ImportPreview? _preview;

  bool _busy = false;

  @override
  void dispose() {
    _newNameCtrl.dispose();
    super.dispose();
  }

  // ── 파일 선택 ──────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) {
      _showMessage('파일을 읽을 수 없습니다');
      return;
    }

    _loadTable(bytes, picked.name);
  }

  void _loadTable(Uint8List bytes, String fileName) {
    final ImportTable table;
    try {
      table = TableFileParser.parse(bytes, fileName);
    } on TableParseException catch (e) {
      _showError(e.message);
      return;
    } catch (_) {
      _showError('파일을 읽지 못했습니다. CSV 또는 .xlsx 파일인지 확인해 주세요.');
      return;
    }

    // 기억된 매핑이 자동 매핑을 덮어쓴다.
    final signature = ImportMappingLocalDataSource.signatureOf(table.header);
    final remembered = ref.read(importMappingDsProvider).load(signature);

    setState(() {
      _table = table;
      _fileName = fileName;
      _mapping = ColumnMatcher.resolveMapping(
        header: table.header,
        remembered: remembered,
      );
      _newNameCtrl.text = _defaultPortfolioName(fileName);
    });

    _recompute();
  }

  static String _defaultPortfolioName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  // ── 미리보기 재계산 ────────────────────────────────────────────────────────

  Future<void> _reloadAlreadyHeld() async {
    final portfolio = _selectedPortfolio;
    if (_createNew || portfolio == null) {
      _alreadyHeldKeys = {};
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final rows = await db.portfolioAssetDao.getByPortfolio(portfolio.id);
    _alreadyHeldKeys = {
      for (final row in rows) '${row.asset.symbol}|${row.asset.assetType}',
    };
  }

  Future<void> _recompute() async {
    final table = _table;
    if (table == null) return;

    await _reloadAlreadyHeld();
    if (!mounted) return;

    setState(() {
      _preview = ColumnMatcher.buildPreview(
        table: table,
        mapping: _mapping,
        forcedType: _forcedType,
        fallbackDate: _acquiredDate,
        alreadyHeldKeys: _alreadyHeldKeys,
      );
    });
  }

  // ── 가져오기 ───────────────────────────────────────────────────────────────

  Future<void> _import() async {
    final table = _table;
    final preview = _preview;
    if (table == null || preview == null || preview.rows.isEmpty) return;

    if (_createNew && _newNameCtrl.text.trim().isEmpty) {
      _showMessage('새 포트폴리오 이름을 입력해 주세요');
      return;
    }
    if (!_createNew && _selectedPortfolio == null) {
      _showMessage('포트폴리오를 선택해 주세요');
      return;
    }

    setState(() => _busy = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final rate = await ref.read(usdKrwRateProvider.future);

      final portfolioId = _createNew
          ? await db.portfolioDao.insert(
              PortfoliosCompanion.insert(name: _newNameCtrl.text.trim()),
            )
          : _selectedPortfolio!.id;

      final count = await ref.read(importWriterProvider).write(
            portfolioId: portfolioId,
            rows: preview.rows,
            fileName: _fileName,
            usdKrwRate: rate,
          );

      // 사용자가 고친 매핑을 파일 모양으로 기억한다.
      await ref.read(importMappingDsProvider).save(
            ImportMappingLocalDataSource.signatureOf(table.header),
            {
              for (final e in _mapping.entries)
                if (e.value >= 0 && e.value < table.header.length)
                  e.key: table.header[e.value],
            },
          );

      if (!mounted) return;
      _showMessage('$count개 종목을 가져왔습니다');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError('가져오기에 실패했습니다.\n$e');
    }
  }

  // ── 안내 ───────────────────────────────────────────────────────────────────

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('파일을 읽지 못했습니다'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // ── 빌드 ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('파일에서 가져오기')),
      body: _table == null ? _buildIntro() : _buildForm(),
    );
  }

  Widget _buildIntro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              '증권사에서 받은 표 파일을 올리면\n보유 종목을 한 번에 등록합니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'CSV, 엑셀(.xlsx) · 열 이름은 자동으로 맞춥니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('파일 선택'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final table = _table!;
    final preview = _preview;
    final canImport =
        !_busy && preview != null && preview.rows.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFileHeader(table),
              const SizedBox(height: 16),
              ...ColumnRole.values.map((role) => _buildRoleDropdown(role, table)),
              const Divider(height: 32),
              _buildTypeDropdown(),
              _buildDatePicker(),
              const Divider(height: 32),
              _buildPortfolioPicker(),
              const Divider(height: 32),
              if (preview != null) _buildPreview(preview),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canImport ? _import : null,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        preview == null || preview.rows.isEmpty
                            ? '가져올 종목이 없습니다'
                            : '${preview.rows.length}개 종목 가져오기',
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileHeader(ImportTable table) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(_fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          table.sheetName == _fileName
              ? '${table.rows.length}행 인식'
              : '시트 "${table.sheetName}" · ${table.rows.length}행 인식',
        ),
        trailing: TextButton(
          onPressed: _pickFile,
          child: const Text('변경'),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown(ColumnRole role, ImportTable table) {
    final required = role == ColumnRole.symbol || role == ColumnRole.quantity;
    final value = _mapping[role];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        key: ValueKey('$role-$value'),
        initialValue: value,
        decoration: InputDecoration(
          labelText: required ? '${role.label} *' : role.label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<int>(value: null, child: Text('없음')),
          for (var i = 0; i < table.header.length; i++)
            DropdownMenuItem<int>(
              value: i,
              child: Text(
                table.header[i].isEmpty ? '(${i + 1}번째 열)' : table.header[i],
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (next) {
          setState(() {
            if (next == null) {
              _mapping.remove(role);
            } else {
              // 한 열이 두 역할을 겸하지 않게 다른 역할에서 떼어 온다.
              _mapping.removeWhere((_, index) => index == next);
              _mapping[role] = next;
            }
          });
          _recompute();
        },
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<AssetType>(
        key: ValueKey('type-$_forcedType'),
        initialValue: _forcedType,
        decoration: const InputDecoration(
          labelText: '자산 유형',
          helperText: '자동: 6자리 숫자는 한국, 영문 티커는 미국',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: const [
          DropdownMenuItem<AssetType>(value: null, child: Text('자동')),
          DropdownMenuItem<AssetType>(
            value: AssetType.krStock,
            child: Text('한국 주식·ETF'),
          ),
          DropdownMenuItem<AssetType>(
            value: AssetType.usStock,
            child: Text('미국 주식·ETF'),
          ),
        ],
        onChanged: (next) {
          setState(() => _forcedType = next);
          _recompute();
        },
      ),
    );
  }

  Widget _buildDatePicker() {
    final hasBuyDateColumn = _mapping.containsKey(ColumnRole.buyDate);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_outlined),
        title: const Text('취득일'),
        subtitle: Text(
          hasBuyDateColumn
              ? '매수일 열이 없는 줄에 이 날짜를 씁니다'
              : '매수일 열이 없어 모든 줄에 이 날짜를 씁니다',
        ),
        trailing: Text(
          _dateFormat.format(_acquiredDate),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _acquiredDate,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (picked == null) return;
          setState(() => _acquiredDate = picked);
          _recompute();
        },
      ),
    );
  }

  Widget _buildPortfolioPicker() {
    final portfoliosAsync = ref.watch(portfoliosStreamProvider);

    return portfoliosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('포트폴리오를 불러오지 못했습니다: $e'),
      data: (portfolios) {
        // 포트폴리오가 없으면 새로 만드는 수밖에 없다.
        if (portfolios.isEmpty && !_createNew) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _createNew = true);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '어디에 넣을까요',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (portfolios.isNotEmpty) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('기존에 추가'),
                    icon: Icon(Icons.folder_outlined),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('새로 만들기'),
                    icon: Icon(Icons.create_new_folder_outlined),
                  ),
                ],
                selected: {_createNew},
                onSelectionChanged: (selection) {
                  setState(() => _createNew = selection.first);
                  _recompute();
                },
              ),
              const SizedBox(height: 12),
            ],
            if (portfolios.isNotEmpty && !_createNew)
              DropdownButtonFormField<int>(
                key: ValueKey('portfolio-${_selectedPortfolio?.id}'),
                initialValue: _selectedPortfolio?.id,
                decoration: const InputDecoration(
                  labelText: '포트폴리오',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final p in portfolios)
                    DropdownMenuItem<int>(value: p.id, child: Text(p.name)),
                ],
                onChanged: (id) {
                  setState(() {
                    _selectedPortfolio = id == null
                        ? null
                        : portfolios.where((p) => p.id == id).first;
                  });
                  _recompute();
                },
              ),
            if (_createNew)
              TextField(
                controller: _newNameCtrl,
                decoration: const InputDecoration(
                  labelText: '새 포트폴리오 이름',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPreview(ImportPreview preview) {
    final total = ImportWriter.totalInvestmentKrw(preview.rows, 1);
    final hasUsd =
        preview.rows.any((r) => r.assetType.currency == 'USD');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('미리보기', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (preview.rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('가져올 수 있는 줄이 없습니다. 아래 사유를 확인해 주세요.'),
          ),
        for (final row in preview.rows.take(50)) _buildPreviewRow(row),
        if (preview.rows.length > 50)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '… 외 ${preview.rows.length - 50}종목',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
        if (total > 0) ...[
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('합계 투자원금'),
              Text(
                hasUsd
                    ? '원화 ${_numberFormat.format(total)} + 외화 환산'
                    : '${_numberFormat.format(total)}원',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
        for (final reason in SkipReason.values)
          if ((preview.skipCounts[reason] ?? 0) > 0)
            _buildSkipWarning(reason, preview.skipCounts[reason]!),
      ],
    );
  }

  Widget _buildPreviewRow(ImportRow row) {
    final price = row.avgPrice;
    final unit = row.assetType.currency == 'USD' ? r'$' : '원';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _trimQuantity(row.quantity),
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              price == null
                  ? '평균단가 없음'
                  : '${_numberFormat.format(price)}$unit',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: price == null ? Theme.of(context).hintColor : null,
                fontSize: price == null ? 12 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _trimQuantity(double quantity) =>
      quantity == quantity.roundToDouble()
          ? quantity.toInt().toString()
          : quantity.toString();

  Widget _buildSkipWarning(SkipReason reason, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${reason.label} — $count줄 건너뜁니다',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
