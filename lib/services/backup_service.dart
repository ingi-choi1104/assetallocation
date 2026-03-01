import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/app_database.dart';

/// Exports and imports all portfolio data as a single JSON file.
///
/// DB tables (in dependency order):
///   assets → portfolios → portfolio_assets → transactions + investments
///
/// SharedPreferences keys preserved:
///   portfolio_bundles_v1, portfolio_strategies_v1,
///   fss_api_key, home_item_order_v1,
///   excluded_portfolios_v1, excluded_bundles_v1
class BackupService {
  static const int _backupVersion = 1;

  final AppDatabase _db;
  final SharedPreferences _prefs;

  // SharedPreferences keys we care about
  static const _prefKeys = [
    'portfolio_bundles_v1',
    'portfolio_strategies_v1',
    'fss_api_key',
    'home_item_order_v1',
    'excluded_portfolios_v1',
    'excluded_bundles_v1',
    'notifications_enabled',
    'show_krw',
  ];

  BackupService(this._db, this._prefs);

  // ── Export ──────────────────────────────────────────────────────────────────

  /// Builds the complete backup map.
  Future<Map<String, dynamic>> _buildBackup() async {
    final allPortfolios   = await _db.select(_db.portfolios).get();
    final allAssets       = await _db.select(_db.assets).get();
    final allPAs          = await _db.select(_db.portfolioAssets).get();
    final allTxns         = await _db.select(_db.transactions).get();
    final allInvestments  = await _db.select(_db.investments).get();

    final prefsMap = <String, dynamic>{};
    for (final key in _prefKeys) {
      final v = _prefs.get(key);
      if (v != null) prefsMap[key] = v;
    }

    return {
      'version': _backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'portfolios': allPortfolios.map(_portfolioToJson).toList(),
      'assets': allAssets.map(_assetToJson).toList(),
      'portfolioAssets': allPAs.map(_paToJson).toList(),
      'transactions': allTxns.map(_txToJson).toList(),
      'investments': allInvestments.map(_investToJson).toList(),
      'prefs': prefsMap,
    };
  }

  /// Exports all data and shares the resulting JSON file.
  Future<void> exportAndShare() async {
    final backup = await _buildBackup();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName =
        'assetallocation_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonStr, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: '자산배분 헬퍼 백업 파일',
    );
  }

  // ── Import ──────────────────────────────────────────────────────────────────

  /// Validates and parses the JSON string; returns the backup map.
  /// Throws [FormatException] if the format is invalid.
  Map<String, dynamic> parseBackup(String jsonStr) {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('올바른 백업 파일이 아닙니다');
    }
    if ((decoded['version'] as int?) != _backupVersion) {
      throw FormatException(
          '지원하지 않는 백업 버전입니다 (version=${decoded['version']})');
    }
    return decoded;
  }

  /// Returns a short summary for the confirmation dialog.
  static String backupSummary(Map<String, dynamic> backup) {
    final exported = backup['exportedAt'] as String? ?? '';
    final portfolios = (backup['portfolios'] as List?)?.length ?? 0;
    final txns = (backup['transactions'] as List?)?.length ?? 0;
    final investments = (backup['investments'] as List?)?.length ?? 0;
    final dt = DateTime.tryParse(exported);
    final dateStr = dt != null
        ? '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}'
        : exported;
    return '백업 날짜: $dateStr\n'
        '포트폴리오: $portfolios개  거래: $txns건  투자: $investments건';
  }

  /// Restores all data from a parsed backup map.
  /// Clears the current database first (irreversible).
  Future<void> restore(Map<String, dynamic> backup) async {
    // ── 1. Clear DB in reverse-dependency order ──────────────────────────────
    await _db.delete(_db.transactions).go();
    await _db.delete(_db.investments).go();
    await _db.delete(_db.portfolioAssets).go();
    await _db.delete(_db.portfolios).go();
    await _db.delete(_db.assets).go();

    // ── 2. Insert assets ─────────────────────────────────────────────────────
    final assetsJson =
        (backup['assets'] as List).cast<Map<String, dynamic>>();
    for (final a in assetsJson) {
      await _db.into(_db.assets).insert(AssetsCompanion(
        id:                 Value(a['id'] as int),
        symbol:             Value(a['symbol'] as String),
        name:               Value(a['name'] as String),
        assetType:          Value(a['assetType'] as String),
        currency:           Value(a['currency'] as String),
        fundCode:           Value(a['fundCode'] as String?),
        lastPrice:          Value((a['lastPrice'] as num?)?.toDouble()),
        lastPriceUpdatedAt: Value(_parseDate(a['lastPriceUpdatedAt'])),
        createdAt:          Value(_parseDate(a['createdAt']) ?? DateTime.now()),
      ));
    }

    // ── 3. Insert portfolios ─────────────────────────────────────────────────
    final portfoliosJson =
        (backup['portfolios'] as List).cast<Map<String, dynamic>>();
    for (final p in portfoliosJson) {
      await _db.into(_db.portfolios).insert(PortfoliosCompanion(
        id:                  Value(p['id'] as int),
        name:                Value(p['name'] as String),
        description:         Value(p['description'] as String?),
        baseCurrency:        Value(p['baseCurrency'] as String? ?? 'KRW'),
        rebalancePeriod:     Value(p['rebalancePeriod'] as String?),
        nextRebalanceDate:   Value(_parseDate(p['nextRebalanceDate'])),
        deviationThreshold:  Value((p['deviationThreshold'] as num?)?.toDouble() ?? 5.0),
        createdAt:           Value(_parseDate(p['createdAt']) ?? DateTime.now()),
        updatedAt:           Value(_parseDate(p['updatedAt']) ?? DateTime.now()),
      ));
    }

    // ── 4. Insert portfolio_assets ───────────────────────────────────────────
    final pasJson =
        (backup['portfolioAssets'] as List).cast<Map<String, dynamic>>();
    for (final pa in pasJson) {
      await _db.into(_db.portfolioAssets).insert(PortfolioAssetsCompanion(
        id:           Value(pa['id'] as int),
        portfolioId:  Value(pa['portfolioId'] as int),
        assetId:      Value(pa['assetId'] as int),
        targetWeight: Value((pa['targetWeight'] as num).toDouble()),
        sortOrder:    Value(pa['sortOrder'] as int? ?? 0),
        addedAt:      Value(_parseDate(pa['addedAt']) ?? DateTime.now()),
      ));
    }

    // ── 5. Insert transactions ───────────────────────────────────────────────
    final txnsJson =
        (backup['transactions'] as List).cast<Map<String, dynamic>>();
    for (final t in txnsJson) {
      await _db.into(_db.transactions).insert(TransactionsCompanion(
        id:                Value(t['id'] as int),
        portfolioAssetId:  Value(t['portfolioAssetId'] as int),
        type:              Value(t['type'] as String),
        quantity:          Value((t['quantity'] as num).toDouble()),
        price:             Value((t['price'] as num).toDouble()),
        exchangeRate:      Value((t['exchangeRate'] as num?)?.toDouble() ?? 1.0),
        fee:               Value((t['fee'] as num?)?.toDouble() ?? 0.0),
        transactionDate:   Value(_parseDate(t['transactionDate'])!),
        memo:              Value(t['memo'] as String?),
        createdAt:         Value(_parseDate(t['createdAt']) ?? DateTime.now()),
      ));
    }

    // ── 6. Insert investments ────────────────────────────────────────────────
    final investsJson =
        (backup['investments'] as List).cast<Map<String, dynamic>>();
    for (final i in investsJson) {
      await _db.into(_db.investments).insert(InvestmentsCompanion(
        id:             Value(i['id'] as int),
        portfolioId:    Value(i['portfolioId'] as int),
        amount:         Value((i['amount'] as num).toDouble()),
        investmentDate: Value(_parseDate(i['investmentDate'])!),
        memo:           Value(i['memo'] as String?),
        createdAt:      Value(_parseDate(i['createdAt']) ?? DateTime.now()),
      ));
    }

    // ── 7. Restore SharedPreferences ─────────────────────────────────────────
    final prefsMap = backup['prefs'] as Map<String, dynamic>? ?? {};
    for (final key in _prefKeys) {
      final v = prefsMap[key];
      if (v == null) continue;
      if (v is String)  await _prefs.setString(key, v);
      if (v is bool)    await _prefs.setBool(key, v);
      if (v is int)     await _prefs.setInt(key, v);
      if (v is double)  await _prefs.setDouble(key, v);
    }
  }

  // ── Serialization helpers ───────────────────────────────────────────────────

  static DateTime? _parseDate(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;

  static Map<String, dynamic> _portfolioToJson(PortfolioRecord p) => {
        'id':                 p.id,
        'name':               p.name,
        'description':        p.description,
        'baseCurrency':       p.baseCurrency,
        'rebalancePeriod':    p.rebalancePeriod,
        'nextRebalanceDate':  p.nextRebalanceDate?.toIso8601String(),
        'deviationThreshold': p.deviationThreshold,
        'createdAt':          p.createdAt.toIso8601String(),
        'updatedAt':          p.updatedAt.toIso8601String(),
      };

  static Map<String, dynamic> _assetToJson(AssetRecord a) => {
        'id':                 a.id,
        'symbol':             a.symbol,
        'name':               a.name,
        'assetType':          a.assetType,
        'currency':           a.currency,
        'fundCode':           a.fundCode,
        'lastPrice':          a.lastPrice,
        'lastPriceUpdatedAt': a.lastPriceUpdatedAt?.toIso8601String(),
        'createdAt':          a.createdAt.toIso8601String(),
      };

  static Map<String, dynamic> _paToJson(PortfolioAssetRecord pa) => {
        'id':           pa.id,
        'portfolioId':  pa.portfolioId,
        'assetId':      pa.assetId,
        'targetWeight': pa.targetWeight,
        'sortOrder':    pa.sortOrder,
        'addedAt':      pa.addedAt.toIso8601String(),
      };

  static Map<String, dynamic> _txToJson(TransactionRecord t) => {
        'id':               t.id,
        'portfolioAssetId': t.portfolioAssetId,
        'type':             t.type,
        'quantity':         t.quantity,
        'price':            t.price,
        'exchangeRate':     t.exchangeRate,
        'fee':              t.fee,
        'transactionDate':  t.transactionDate.toIso8601String(),
        'memo':             t.memo,
        'createdAt':        t.createdAt.toIso8601String(),
      };

  static Map<String, dynamic> _investToJson(InvestmentRecord i) => {
        'id':             i.id,
        'portfolioId':    i.portfolioId,
        'amount':         i.amount,
        'investmentDate': i.investmentDate.toIso8601String(),
        'memo':           i.memo,
        'createdAt':      i.createdAt.toIso8601String(),
      };
}
