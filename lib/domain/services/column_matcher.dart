import '../entities/import_table.dart';
import '../enums/asset_type.dart';

/// 표의 열을 역할에 맞추고, 셀 값을 숫자·날짜로 정규화하고, 각 줄이 가져올
/// 수 있는지 판정한다.
///
/// 순수 Dart다 — 파일 포맷도, DB도, 화면도 모른다. 증권사마다 파일 형식이
/// 전부 다르다는 것이 이 기능의 핵심 제약이므로, 사전은 "편의"이지
/// "정확성의 근거"가 아니다. 부족해도 사용자가 화면에서 고치면 기억된다.
class ColumnMatcher {
  ColumnMatcher._();

  /// 열 이름 사전. 실제 증권사 파일을 받는 대로 보강한다.
  /// 비교는 [normalizeHeader]를 거친 값으로 한다.
  static const Map<ColumnRole, List<String>> dictionary = {
    ColumnRole.symbol: [
      '종목코드', '단축코드', '종목번호', '코드', '티커',
      'symbol', 'ticker', 'code',
    ],
    ColumnRole.name: [
      '종목명', '상품명', '종목', '주식명', '자산명', '이름',
      'name', 'item',
    ],
    ColumnRole.quantity: [
      '수량', '보유수량', '잔고수량', '주식수', '보유주수', '결제수량',
      'qty', 'quantity', 'shares',
    ],
    ColumnRole.avgPrice: [
      '평균단가', '매입단가', '평단가', '매입평균단가', '취득단가',
      'avgprice', 'cost',
    ],
    ColumnRole.currentPrice: [
      '현재가', '종가', '평가단가', '시가', 'price',
    ],
    ColumnRole.buyDate: [
      '매수일', '매수일자', '거래일', '체결일', '취득일', 'date',
    ],
  };

  /// 헤더 비교용 정규화: 공백·괄호를 지우고 소문자로.
  ///
  /// `'매입단가 (원)'` → `'매입단가원'`
  static String normalizeHeader(String raw) => raw
      .replaceAll(RegExp(r'[\s()\[\]{}]'), '')
      .toLowerCase();

  /// 증권사 파일은 맨 위에 제목·계좌번호·조회일시가 붙는다. 1행을 헤더로
  /// 가정하면 깨지므로, 첫 20행 중 사전에 걸리는 셀이 가장 많은 행을 고른다.
  /// 동점이면 위쪽. 하나도 안 걸리면 첫 비어있지 않은 행.
  static int findHeaderRow(List<List<String>> rows) {
    if (rows.isEmpty) return 0;

    var bestIndex = -1;
    var bestScore = 0;
    final limit = rows.length < 20 ? rows.length : 20;

    for (var i = 0; i < limit; i++) {
      var score = 0;
      for (final cell in rows[i]) {
        final n = normalizeHeader(cell);
        if (n.isEmpty) continue;
        if (_anyRoleMatches(n)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    if (bestIndex >= 0) return bestIndex;

    for (var i = 0; i < rows.length; i++) {
      if (rows[i].any((c) => c.trim().isNotEmpty)) return i;
    }
    return 0;
  }

  static bool _anyRoleMatches(String normalized) {
    for (final candidates in dictionary.values) {
      if (candidates.contains(normalized)) return true;
      for (final c in candidates) {
        if (normalized.contains(c)) return true;
      }
    }
    return false;
  }

  /// 사전으로 역할 → 열 인덱스를 추측한다.
  ///
  /// 완전일치를 먼저 모두 배정하고, 남은 역할만 포함관계로 채운다. 한 열이
  /// 두 역할을 겸하지 않는다 — `'종목코드'`는 `name` 후보 `'종목'`을
  /// 포함하지만 `symbol`이 먼저 가져간다.
  static Map<ColumnRole, int> guessMapping(List<String> header) {
    final norm = header.map(normalizeHeader).toList();
    final result = <ColumnRole, int>{};
    final claimed = <int>{};

    for (final role in ColumnRole.values) {
      final candidates = dictionary[role]!;
      for (var i = 0; i < norm.length; i++) {
        if (claimed.contains(i) || norm[i].isEmpty) continue;
        if (candidates.contains(norm[i])) {
          result[role] = i;
          claimed.add(i);
          break;
        }
      }
    }

    for (final role in ColumnRole.values) {
      if (result.containsKey(role)) continue;
      final candidates = dictionary[role]!;
      for (var i = 0; i < norm.length; i++) {
        if (claimed.contains(i) || norm[i].isEmpty) continue;
        if (candidates.any((c) => norm[i].contains(c))) {
          result[role] = i;
          claimed.add(i);
          break;
        }
      }
    }

    return result;
  }

  /// 기억된 매핑(역할 → 열 **이름**)을 인덱스로 바꾸고, 거기서 빈 역할만
  /// [guessMapping]으로 채운다. **기억된 쪽이 이긴다.** 기억된 이름이 이
  /// 파일에 없으면 그 역할은 자동 매핑으로 떨어진다.
  static Map<ColumnRole, int> resolveMapping({
    required List<String> header,
    Map<ColumnRole, String>? remembered,
  }) {
    final auto = guessMapping(header);
    if (remembered == null || remembered.isEmpty) return auto;

    final norm = header.map(normalizeHeader).toList();
    final result = <ColumnRole, int>{};
    final claimed = <int>{};

    remembered.forEach((role, columnName) {
      final i = norm.indexOf(normalizeHeader(columnName));
      if (i >= 0 && !claimed.contains(i)) {
        result[role] = i;
        claimed.add(i);
      }
    });

    auto.forEach((role, i) {
      if (result.containsKey(role) || claimed.contains(i)) return;
      result[role] = i;
      claimed.add(i);
    });

    return result;
  }

  /// 천 단위 쉼표, 단위 표기(원·주·달러·%), 따옴표, 앞뒤 공백을 걷어낸다.
  /// 괄호로 둘러싼 값은 음수. 빈 칸과 붙임표는 없는 값(null).
  static double? parseNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final negative = trimmed.startsWith('(') && trimmed.endsWith(')');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (digits.isEmpty || digits == '-' || digits == '.') return null;

    final value = double.tryParse(digits);
    if (value == null) return null;
    return negative ? -value.abs() : value;
  }

  /// `2026-01-02`, `2026.01.02`, `2026/01/02`, `20260102`를 받는다.
  static DateTime? parseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    if (RegExp(r'^\d{8}$').hasMatch(s)) {
      return _ymd(s.substring(0, 4), s.substring(4, 6), s.substring(6, 8));
    }

    final parts = s.split(RegExp(r'[-./]'));
    if (parts.length == 3) return _ymd(parts[0], parts[1], parts[2]);

    return null;
  }

  static DateTime? _ymd(String y, String m, String d) {
    final year = int.tryParse(y.trim());
    final month = int.tryParse(m.trim());
    final day = int.tryParse(d.trim());
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final date = DateTime(year, month, day);
    // DateTime은 2월 30일을 3월 2일로 넘겨 버린다 — 조용히 틀린 날짜가
    // 들어가지 않게 되돌려 확인한다.
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  /// 6자리 숫자 코드 → 한국, 영문 티커 → 미국. 판단 불가면 null.
  ///
  /// 펀드·암호화폐·금·현금은 추측하지 않는다 — 각각 `fundCode`,
  /// CoinGecko id가 따로 필요하거나 symbol이 의미가 없어서, 그 유형으로
  /// 등록하면 시세가 영영 안 붙는 자산이 생긴다.
  static AssetType? inferType(String symbol) {
    final s = symbol.trim();
    if (s.isEmpty) return null;
    if (RegExp(r'^\d{6}$').hasMatch(s)) return AssetType.krStock;
    if (RegExp(r'^[A-Za-z]{1,5}(\.[A-Za-z]{1,2})?$').hasMatch(s)) {
      return AssetType.usStock;
    }
    return null;
  }

  /// 표를 훑어 가져올 줄과 빠진 줄로 나눈다.
  ///
  /// 통과 조건: `symbol` 있음 **그리고** `quantity`가 양수 **그리고** 유형이
  /// 정해짐 **그리고** 파일 내 중복 아님 **그리고** [alreadyHeldKeys]에 없음.
  /// 떨어진 줄은 **첫 실패 사유 하나로만** 센다.
  ///
  /// [alreadyHeldKeys]의 원소는 `ImportRow.key`와 같은 형식
  /// (`symbol` + `'|'` + `assetType.value`).
  static ImportPreview buildPreview({
    required ImportTable table,
    required Map<ColumnRole, int> mapping,
    required AssetType? forcedType,
    required DateTime fallbackDate,
    required Set<String> alreadyHeldKeys,
  }) {
    final rows = <ImportRow>[];
    final skipped = <SkippedRow>[];
    final seen = <String>{};

    for (var i = 0; i < table.rows.length; i++) {
      final raw = table.rows[i];

      final symbol = _cell(raw, mapping, ColumnRole.symbol);
      if (symbol.isEmpty) {
        skipped.add(SkippedRow(rowIndex: i, reason: SkipReason.noSymbol));
        continue;
      }

      final quantity = parseNumber(_cell(raw, mapping, ColumnRole.quantity));
      if (quantity == null || quantity <= 0) {
        skipped.add(SkippedRow(rowIndex: i, reason: SkipReason.badQuantity));
        continue;
      }

      final type = forcedType ?? inferType(symbol);
      if (type == null) {
        skipped.add(SkippedRow(rowIndex: i, reason: SkipReason.unknownType));
        continue;
      }

      final key = '$symbol|${type.value}';
      if (!seen.add(key)) {
        skipped
            .add(SkippedRow(rowIndex: i, reason: SkipReason.duplicateInFile));
        continue;
      }
      if (alreadyHeldKeys.contains(key)) {
        skipped.add(SkippedRow(rowIndex: i, reason: SkipReason.alreadyHeld));
        continue;
      }

      final name = _cell(raw, mapping, ColumnRole.name);
      final avgPrice = parseNumber(_cell(raw, mapping, ColumnRole.avgPrice));
      final currentPrice =
          parseNumber(_cell(raw, mapping, ColumnRole.currentPrice));
      final buyDate = parseDate(_cell(raw, mapping, ColumnRole.buyDate));

      rows.add(ImportRow(
        rowIndex: i,
        symbol: symbol,
        name: name.isNotEmpty ? name : symbol,
        quantity: quantity,
        avgPrice: (avgPrice != null && avgPrice > 0) ? avgPrice : null,
        currentPrice: (currentPrice != null && currentPrice > 0)
            ? currentPrice
            : null,
        buyDate: buyDate ?? fallbackDate,
        assetType: type,
      ));
    }

    final counts = <SkipReason, int>{};
    for (final s in skipped) {
      counts[s.reason] = (counts[s.reason] ?? 0) + 1;
    }

    return ImportPreview(rows: rows, skipped: skipped, skipCounts: counts);
  }

  static String _cell(
    List<String> row,
    Map<ColumnRole, int> mapping,
    ColumnRole role,
  ) {
    final i = mapping[role];
    if (i == null || i < 0 || i >= row.length) return '';
    return row[i].trim();
  }
}
