import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/asset_trend.dart';

/// 추이 메뉴가 받아온 과거 시세를 담아두는 파일 캐시.
///
/// 앱 문서 폴더의 JSON 파일 하나만 쓴다 — 기존 `price_history` 테이블이나
/// SharedPreferences를 건드리지 않으므로 다른 메뉴에 영향이 없다.
/// 파일이 깨지거나 없으면 그냥 캐시 미스로 처리한다.
class TrendCacheLocalDataSource {
  static const _fileName = 'trend_price_cache_v1.json';

  /// 캐시 한 칸: 어느 구간을 받아왔는지와 일별 종가.
  /// {"from": epochDay, "bars": {"epochDay": close, ...}}
  Map<String, dynamic>? _cache;
  File? _file;

  Future<File> _resolveFile() async {
    final cached = _file;
    if (cached != null) return cached;
    final dir = await getApplicationDocumentsDirectory();
    return _file = File('${dir.path}/$_fileName');
  }

  Future<Map<String, dynamic>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final file = await _resolveFile();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) return _cache = decoded;
      }
    } catch (_) {
      // 깨진 캐시는 버리고 새로 받는다.
    }
    return _cache = <String, dynamic>{};
  }

  // UTC 기준으로 날짜 번호를 만든다. 로컬 자정(KST)은 UTC로 전날 15시라,
  // 로컬 기준으로 나누면 저장·복원 때 하루씩 밀린다.
  static int _epochDay(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  static DateTime _fromEpochDay(int v) {
    final utc = DateTime.fromMillisecondsSinceEpoch(v * 86400000, isUtc: true);
    return DateTime(utc.year, utc.month, utc.day);
  }

  /// [key]로 저장된 시세 중 [start] 이후 구간. 캐시가 [start]까지 닿지
  /// 않거나 오늘 기준으로 너무 오래됐으면 null.
  Future<List<TrendBar>?> read(String key, DateTime start) async {
    final store = await _load();
    final entry = store[key];
    if (entry is! Map) return null;

    final from = entry['from'];
    final bars = entry['bars'];
    if (from is! int || bars is! Map) return null;

    // 요청 구간이 캐시보다 과거까지 필요하면 다시 받아야 한다.
    if (from > _epochDay(start) + 10) return null;

    final out = <TrendBar>[];
    final minDay = _epochDay(start);
    var newest = 0;
    for (final e in bars.entries) {
      final day = int.tryParse(e.key.toString());
      final close = (e.value as num?)?.toDouble();
      if (day == null || close == null) continue;
      if (day > newest) newest = day;
      if (day < minDay) continue;
      out.add(TrendBar(date: _fromEpochDay(day), close: close));
    }
    if (out.length < 2) return null;

    // 최신 종가가 사흘 넘게 밀렸으면 새로 받는다.
    if (_epochDay(DateTime.now()) - newest > 3) return null;

    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// [key]의 시세를 저장한다. 기존 값과 합쳐 더 긴 구간을 유지한다.
  Future<void> write(String key, DateTime from, List<TrendBar> bars) async {
    if (bars.isEmpty) return;
    final store = await _load();

    final existing = store[key];
    final merged = <String, dynamic>{};
    if (existing is Map && existing['bars'] is Map) {
      merged.addAll(Map<String, dynamic>.from(existing['bars'] as Map));
    }
    for (final bar in bars) {
      merged['${_epochDay(bar.date)}'] = bar.close;
    }

    var fromDay = _epochDay(from);
    if (existing is Map && existing['from'] is int) {
      final prev = existing['from'] as int;
      if (prev < fromDay) fromDay = prev;
    }

    store[key] = {'from': fromDay, 'bars': merged};
    await _flush(store);
  }

  Future<void> _flush(Map<String, dynamic> store) async {
    try {
      final file = await _resolveFile();
      await file.writeAsString(jsonEncode(store));
    } catch (_) {
      // 저장 실패는 조용히 넘어간다 — 다음 실행 때 다시 받으면 된다.
    }
  }

  /// 캐시 전체 삭제 (추이 화면의 '시세 다시 받기').
  Future<void> clear() async {
    _cache = <String, dynamic>{};
    try {
      final file = await _resolveFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
