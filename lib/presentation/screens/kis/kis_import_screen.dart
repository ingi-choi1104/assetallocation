import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../domain/enums/asset_type.dart';
import '../../../services/kis_service.dart';
import '../../providers/database_providers.dart';

enum _Step { form, loading, preview, importing, done }

class KisImportScreen extends ConsumerStatefulWidget {
  const KisImportScreen({super.key});

  @override
  ConsumerState<KisImportScreen> createState() => _KisImportScreenState();
}

class _KisImportScreenState extends ConsumerState<KisImportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _appKeyCtrl = TextEditingController();
  final _appSecretCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();  // 앞 8자리
  final _productCodeCtrl = TextEditingController(); // 뒤 2자리

  bool _appSecretVisible = false;
  bool _credentialsSaved = false;

  _Step _step = _Step.form;
  String _loadingMsg = '';
  String? _errorMsg;

  List<KisHolding> _holdings = [];
  List<PortfolioRecord> _portfolios = [];
  PortfolioRecord? _selectedPortfolio;
  bool _createNew = false;

  /// 샘플(체험) 모드로 들어왔는지. API 키 없이 가져오기 흐름만 보여준다.
  bool _isSample = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final creds = await KisService.loadCredentials();
    if (mounted) {
      setState(() {
        _appKeyCtrl.text = creds.appKey;
        _appSecretCtrl.text = creds.appSecret;
        _credentialsSaved = creds.appKey.isNotEmpty;
      });
    }
    final db = ref.read(appDatabaseProvider);
    final list = await db.portfolioDao.getAll();
    if (mounted) {
      setState(() {
        _portfolios = list;
        _selectedPortfolio = list.isNotEmpty ? list.first : null;
      });
    }
  }

  @override
  void dispose() {
    _appKeyCtrl.dispose();
    _appSecretCtrl.dispose();
    _accountCtrl.dispose();
    _productCodeCtrl.dispose();
    super.dispose();
  }

  /// API 키 없이 가져오기 화면을 둘러볼 수 있는 체험 모드.
  /// 실제 조회 없이 예시 종목으로 미리보기 단계까지 진행한다.
  void _loadSample() {
    setState(() {
      _isSample = true;
      _errorMsg = null;
      _holdings = [
        KisHolding(
          stockName: '삼성전자',
          stockCode: '005930',
          quantity: 10,
          avgPurchasePrice: 71000,
          currentPrice: 74500,
          evaluationAmount: 745000,
        ),
        KisHolding(
          stockName: 'KODEX 200',
          stockCode: '069500',
          quantity: 25,
          avgPurchasePrice: 38000,
          currentPrice: 39200,
          evaluationAmount: 980000,
        ),
        KisHolding(
          stockName: 'TIGER 미국S&P500',
          stockCode: '360750',
          quantity: 40,
          avgPurchasePrice: 17500,
          currentPrice: 19100,
          evaluationAmount: 764000,
        ),
      ];
      _step = _Step.preview;
    });
  }

  /// 샘플 종목은 실제로 저장하지 않는다.
  void _warnSampleImport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '샘플 데이터는 저장되지 않습니다. 실제로 가져오려면 '
          'API 키와 계좌번호를 입력해 주세요.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _fetchHoldings() async {
    if (!_formKey.currentState!.validate()) return;
    _isSample = false;

    await KisService.saveCredentials(
      appKey: _appKeyCtrl.text.trim(),
      appSecret: _appSecretCtrl.text.trim(),
    );

    setState(() {
      _step = _Step.loading;
      _loadingMsg = '한국투자증권 잔고 조회 중...';
      _errorMsg = null;
    });
    try {
      final kis = KisService(
        appKey: _appKeyCtrl.text.trim(),
        appSecret: _appSecretCtrl.text.trim(),
      );
      final holdings = await kis.getHoldings(
        cano: _accountCtrl.text.trim(),
        acntPrdtCd: _productCodeCtrl.text.trim().isEmpty
            ? '01'
            : _productCodeCtrl.text.trim(),
      );
      setState(() {
        _holdings = holdings;
        _step = _Step.preview;
        _errorMsg = holdings.isEmpty ? '보유 종목이 없습니다.' : null;
      });
    } catch (e) {
      setState(() {
        _step = _Step.preview;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
        _holdings = [];
      });
    }
  }

  Future<void> _importHoldings() async {
    setState(() {
      _step = _Step.importing;
      _loadingMsg = '가져오는 중...';
    });
    try {
      final db = ref.read(appDatabaseProvider);
      int portfolioId;
      if (_createNew || _selectedPortfolio == null) {
        portfolioId = await db.portfolioDao.insert(
          PortfoliosCompanion.insert(name: '한국투자증권 계좌'),
        );
      } else {
        portfolioId = _selectedPortfolio!.id;
      }

      int imported = 0;
      for (final h in _holdings) {
        final symbol = h.stockCode.isNotEmpty ? h.stockCode : h.stockName;
        if (symbol.isEmpty) continue;

        // {symbol, assetType}로 먼저 조회한다. insertOnConflictUpdate의
        // ON CONFLICT 타깃은 PK라 이 UNIQUE 충돌을 막아주지 못하고, 이미
        // 보유한 종목 하나가 가져오기 전체를 실패시킨다.
        const krStock = AssetType.krStock;
        final existing = await db.assetDao
            .getBySymbolAndType(symbol, krStock.value);
        final assetId = existing?.id ??
            await db.assetDao.upsert(
              AssetsCompanion.insert(
                symbol: symbol,
                name: h.stockName.isNotEmpty ? h.stockName : symbol,
                assetType: krStock.value,
                currency: krStock.currency,
                lastPrice: Value(h.currentPrice > 0 ? h.currentPrice : null),
              ),
            );

        try {
          await db.portfolioAssetDao.insert(
            PortfolioAssetsCompanion.insert(
              portfolioId: portfolioId,
              assetId: assetId,
              targetWeight: 0,
            ),
          );
        } catch (_) {}

        final paList = await db.portfolioAssetDao.getByPortfolio(portfolioId);
        final paMatches =
            paList.where((p) => p.asset.id == assetId).toList();
        if (paMatches.isEmpty) continue;

        if (h.quantity > 0 && h.avgPurchasePrice > 0) {
          await db.transactionDao.insert(
            TransactionsCompanion.insert(
              portfolioAssetId: paMatches.first.portfolioAsset.id,
              type: 'buy',
              quantity: h.quantity,
              price: h.avgPurchasePrice,
              transactionDate: DateTime.now(),
              memo: const Value('한국투자증권 계좌 가져오기'),
            ),
          );
        }
        imported++;
      }

      setState(() {
        _step = _Step.done;
        _loadingMsg = '$imported개 종목을 가져왔습니다.';
      });
    } catch (e) {
      setState(() {
        _step = _Step.preview;
        _errorMsg = '가져오기 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('계좌 가져오기'),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Beta',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      body: switch (_step) {
        _Step.form => _buildForm(),
        _Step.loading => _buildLoading(_loadingMsg),
        _Step.preview => _buildPreview(),
        _Step.importing => _buildLoading(_loadingMsg),
        _Step.done => _buildDone(),
      },
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API 키 섹션
            const Text('한국투자증권 Open API 키',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '한국투자증권 앱 → 모바일/인터넷 → Open API 서비스 신청에서 발급',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            if (_credentialsSaved) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('저장된 키 불러옴',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.green)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _appKeyCtrl,
              decoration: const InputDecoration(
                labelText: 'App Key',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'App Key를 입력하세요' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _appSecretCtrl,
              obscureText: !_appSecretVisible,
              decoration: InputDecoration(
                labelText: 'App Secret',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_appSecretVisible
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _appSecretVisible = !_appSecretVisible),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'App Secret을 입력하세요' : null,
            ),
            const SizedBox(height: 24),
            // 계좌번호 섹션
            const Text('계좌번호',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '10자리 입력 (예: 5012345601) — 앞 8자리 + 상품코드 2자리',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _accountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '계좌번호 (10자리)',
                border: OutlineInputBorder(),
                hintText: '5012345601',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '계좌번호를 입력하세요';
                final digits =
                    v.trim().replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length != 8 && digits.length != 10) {
                  return '8자리 또는 10자리로 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchHoldings,
              icon: const Icon(Icons.download),
              label: const Text('보유 종목 조회'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            // API 키가 없어도 가져오기 과정을 확인할 수 있는 체험 경로.
            OutlinedButton.icon(
              onPressed: _loadSample,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('샘플로 둘러보기 (API 키 없이)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '예시 종목으로 가져오기 과정을 미리 볼 수 있습니다. '
              '실제 계좌와 연결되지 않습니다.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// 샘플 모드임을 명확히 알리는 배너. 실제 잔고로 오해하지 않게 한다.
  Widget _sampleBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '샘플 데이터입니다. 실제 계좌 잔고가 아닙니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        if (_isSample) _sampleBanner(),
        if (_errorMsg != null)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(_errorMsg!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _step = _Step.form),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('조회된 종목 ${_holdings.length}개',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('가져올 포트폴리오'),
                const SizedBox(height: 4),
                if (!_createNew && _portfolios.isNotEmpty)
                  DropdownButton<PortfolioRecord>(
                    isExpanded: true,
                    value: _selectedPortfolio,
                    items: _portfolios
                        .map((p) => DropdownMenuItem(
                            value: p, child: Text(p.name)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedPortfolio = v),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('새 포트폴리오 "한국투자증권 계좌" 생성'),
                  value: _createNew,
                  onChanged: (v) =>
                      setState(() => _createNew = v ?? false),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _holdings.length,
              itemBuilder: (ctx, i) {
                final h = _holdings[i];
                return ListTile(
                  title: Text(
                      h.stockName.isNotEmpty ? h.stockName : h.stockCode),
                  subtitle: Text(h.stockCode),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${h.quantity.toStringAsFixed(0)}주'),
                      Text(
                        '평균 ${h.avgPurchasePrice > 0 ? h.avgPurchasePrice.toStringAsFixed(0) : "-"}원',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step = _Step.form),
                    child: const Text('다시 입력'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    // 샘플 종목이 실제 포트폴리오에 들어가면 안 된다.
                    onPressed: _holdings.isEmpty
                        ? null
                        : (_isSample ? _warnSampleImport : _importHoldings),
                    child: const Text('가져오기'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoading(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(msg),
        ],
      ),
    );
  }

  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 16),
            Text(
              _loadingMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('완료'),
            ),
          ],
        ),
      ),
    );
  }
}
