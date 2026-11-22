import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/import_table.dart';
import '../../../domain/services/column_matcher.dart';

/// 파일 모양별로 사용자가 고친 열 매핑을 기억한다. 같은 증권사 파일은
/// 다음부터 확인 화면에서 그냥 통과한다.
///
/// 역할 → 열 **이름**으로 저장한다(인덱스가 아니다). 같은 증권사가 열 순서를
/// 바꿔도 살아남는다. 이름을 인덱스로 바꾸는 것은
/// [ColumnMatcher.resolveMapping]이 한다.
class ImportMappingLocalDataSource {
  static const prefsKey = 'import_column_mappings_v1';

  final SharedPreferences _prefs;

  ImportMappingLocalDataSource(this._prefs);

  /// 파일 모양 서명. 헤더 셀을 정규화·정렬해 이어붙인 뒤 해시한다.
  ///
  /// `String.hashCode`는 Dart 버전 간 안정성이 보장되지 않아 저장용으로
  /// 쓸 수 없다(SDK가 올라가면 기억이 통째로 사라진다). 그래서 FNV-1a를
  /// 직접 돌린다 — 의존성 없이 영구히 같은 값이 나온다.
  ///
  /// 해시 충돌이 나면 다른 증권사 파일에 남의 매핑이 적용되지만, 확인
  /// 화면에서 눈에 보이고 고치면 덮어써지므로 조용히 틀리지 않는다.
  static String signatureOf(List<String> header) {
    final normalized = header.map(ColumnMatcher.normalizeHeader).toList()
      ..sort();
    return _fnv1a(normalized.join('|')).toRadixString(16);
  }

  /// 모르는 서명이거나 쓸 수 있는 항목이 하나도 없으면 null.
  Map<ColumnRole, String>? load(String signature) {
    final entry = _readAll()[signature];
    if (entry is! Map) return null;

    final result = <ColumnRole, String>{};
    entry.forEach((key, value) {
      final role = ColumnRole.fromName(key.toString());
      // 앱 버전이 내려가 모르는 역할이 섞여 있으면 그것만 무시한다.
      if (role != null && value is String && value.isNotEmpty) {
        result[role] = value;
      }
    });

    return result.isEmpty ? null : result;
  }

  /// 빈 매핑을 저장하면 그 서명을 잊는다.
  Future<void> save(
    String signature,
    Map<ColumnRole, String> mapping,
  ) async {
    final all = _readAll();

    if (mapping.isEmpty) {
      all.remove(signature);
    } else {
      all[signature] = {
        for (final e in mapping.entries) e.key.name: e.value,
      };
    }

    await _prefs.setString(prefsKey, jsonEncode(all));
  }

  /// 깨진 JSON은 빈 맵으로 본다 — 기억을 잃는 것이 터지는 것보다 낫다.
  Map<String, dynamic> _readAll() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  static int _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash = _mix(hash, unit & 0xFF);
      hash = _mix(hash, (unit >> 8) & 0xFF);
    }
    return hash;
  }

  static int _mix(int hash, int byte) =>
      ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
}
