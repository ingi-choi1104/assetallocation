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

  /// 너무 일반적이어서 **완전일치로만** 쓰는 후보들.
  ///
  /// 포함관계에 넣으면 남의 열을 집어간다 — `'코드'`는 `'국가코드'`·
  /// `'통화코드'`를, `'종목'`은 `'보유종목수량'`을 종목코드/종목명으로
  /// 잘못 잡는다.
  static const Set<String> exactOnlyCandidates = {
    '코드', '종목', '이름', '시가', '종가',
    'code', 'name', 'item', 'date', 'price', 'cost', 'qty',
  };

  /// 헤더 비교용 정규화: 공백·괄호를 지우고 소문자로.
  ///
  /// `'매입단가 (원)'` → `'매입단가원'`
  static String normalizeHeader(String raw) => raw
      .replaceAll(RegExp(r'[\s()\[\]{}]'), '')
      .toLowerCase();

  /// 증권사 파일은 맨 위에 제목·계좌번호·조회일시가 붙는다. 1행을 헤더로
  /// 가정하면 깨지므로, 첫 20행 중 사전에 걸리는 셀이 가장 많은 행을 고른다.
  /// 동점이면 위쪽. 하나도 안 걸리면 **가장 넓은 행**을 쓴다(동점이면 위쪽).
  ///
  /// 첫 비어있지 않은 행을 쓰면 안 된다 — 그건 보통 제목 한 칸짜리 행이고,
  /// 그걸 헤더로 잡으면 본문의 나머지 열이 사용자 눈에 보이지도 않게 된다.
  /// 영문·외국 증권사 파일이 바로 이 경우다.
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

    var widestIndex = 0;
    var widestWidth = -1;
    for (var i = 0; i < limit; i++) {
      final width = rows[i].where((c) => c.trim().isNotEmpty).length;
      if (width > widestWidth) {
        widestWidth = width;
        widestIndex = i;
      }
    }
    return widestIndex;
  }

  static bool _anyRoleMatches(String normalized) {
    for (final candidates in dictionary.values) {
      if (candidates.contains(normalized)) return true;
      for (final c in candidates) {
        if (exactOnlyCandidates.contains(c)) continue;
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

    // 포함관계는 **더 긴 후보가 이긴다.** 역할 순서로 먼저 온 쪽이 집어가게
    // 두면 symbol 후보 '코드'가 '국가코드'를 가져가 종목코드 열이 사라지고,
    // name 후보 '종목'이 '보유종목수량'을 가져가 수량 열이 사라진다.
    final matches = <_ContainmentMatch>[];
    for (final role in ColumnRole.values) {
      if (result.containsKey(role)) continue;
      for (var i = 0; i < norm.length; i++) {
        if (claimed.contains(i) || norm[i].isEmpty) continue;
        for (final candidate in dictionary[role]!) {
          if (exactOnlyCandidates.contains(candidate)) continue;
          if (norm[i].contains(candidate)) {
            matches.add(_ContainmentMatch(role, i, candidate.length));
          }
        }
      }
    }
    matches.sort((a, b) => b.length.compareTo(a.length));

    for (final match in matches) {
      if (result.containsKey(match.role) || claimed.contains(match.column)) {
        continue;
      }
      result[match.role] = match.column;
      claimed.add(match.column);
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
  ///
  /// 숫자가 아닌 글자는 **지우지 않고 공백으로 바꾼다**. 지우면 엑셀이 내보낸
  /// `'1.2E+5'`가 `1.25`가 되고 `'10주 (5)'`가 `105`가 된다 — 조용히 틀린
  /// 수치가 들어가는 것이 이 기능의 최대 위험이다. 숫자 덩어리가 둘 이상이면
  /// 읽기를 포기하고 그 줄을 사유와 함께 센다.
  static double? parseNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final negative = trimmed.startsWith('(') && trimmed.endsWith(')');

    // 천 단위 쉼표만 먼저 지운다(구분자가 아니라 장식이므로).
    final cleaned = trimmed
        .replaceAll(',', '')
        .replaceAll(RegExp(r'[^0-9.\-]'), ' ');

    final tokens = RegExp(r'-?\d*\.?\d+')
        .allMatches(cleaned)
        .map((m) => m.group(0)!)
        .toList();
    if (tokens.length != 1) return null;

    final value = double.tryParse(tokens.single);
    if (value == null) return null;
    return negative ? -value.abs() : value;
  }

  /// `2026-01-02`, `2026.01.02`, `2026/01/02`, `20260102`를 받는다.
  /// `25.03.04`처럼 두 자리 연도도 받아 올해 이전으로 펼친다.
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
    var year = int.tryParse(y.trim());
    final month = int.tryParse(m.trim());
    final day = int.tryParse(d.trim());
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    // 두 자리 연도(키움 등의 YY.MM.DD). 그냥 받으면 서기 25년이 되어
    // 보유기간이 2000년으로 계산되고 연평균·추이·MDD가 전부 어긋난다.
    // 취득일은 언제나 과거이므로 올해를 넘지 않는 세기로 펼친다.
    if (year < 100) {
      final thisYear = DateTime.now().year;
      final candidate = (thisYear ~/ 100) * 100 + year;
      year = candidate <= thisYear ? candidate : candidate - 100;
    }
    if (year < 1900 || year > 2100) return null;

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
    if (_krSymbol.hasMatch(s)) return AssetType.krStock;
    if (_usSymbol.hasMatch(s)) return AssetType.usStock;
    return null;
  }

  /// 한국 종목코드: 6자리. 우선주·신주인수권은 마지막 자리가 영문일 수 있다
  /// (`00088K`).
  static final RegExp _krSymbol = RegExp(r'^\d{5}[0-9A-Za-z]$');

  /// 미국 티커: 영문 1~5자, 뒤에 `.B` 같은 클래스 표기가 붙을 수 있다.
  /// 한 글자 티커(F, GM, BP)는 실재하므로 받는다.
  static final RegExp _usSymbol =
      RegExp(r'^[A-Za-z]{1,5}(\.[A-Za-z]{1,2})?$');

  /// 사용자가 유형을 **직접 고른** 경우에도 종목코드 형식은 검사한다.
  ///
  /// 검사가 없으면, 매핑이 틀려 "유형 판단 불가"가 쏟아질 때 사용자가 유형을
  /// 직접 고르는 것으로 대응하고, 그 결과 한글 이름이 `symbol`인 자산이
  /// 등록되어 평가액이 영영 0으로 남는다 — 계좌 가져오기의 이름-폴백을
  /// 설계에서 거부한 것과 같은 이유다.
  static bool matchesType(String symbol, AssetType type) {
    final s = symbol.trim();
    return switch (type) {
      AssetType.krStock => _krSymbol.hasMatch(s),
      AssetType.usStock => _usSymbol.hasMatch(s),
      // 나머지 유형은 이 화면에서 고를 수 없다.
      _ => false,
    };
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

      final symbol = _restoreKrCode(
        _cell(raw, mapping, ColumnRole.symbol),
        forcedType,
      );
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
      // 유형을 직접 고른 경우에도 형식은 검사한다 ([matchesType] 참조).
      if (!matchesType(symbol, type)) {
        skipped.add(SkippedRow(rowIndex: i, reason: SkipReason.invalidSymbol));
        continue;
      }

      // 미국 티커는 대문자로 맞춘다 — 소문자로 들어오면 같은 종목이
      // 'aapl'과 'AAPL'로 두 번 등록되고 보유 중 판정도 빗나간다.
      final normalizedSymbol =
          type == AssetType.usStock ? symbol.toUpperCase() : symbol;

      final key = '$normalizedSymbol|${type.value}';
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
      // 미래 날짜는 파싱 사고로 본다 — 취득일은 언제나 과거이고, 미래
      // 날짜가 들어가면 보유기간이 음수가 되어 연평균이 뒤집힌다.
      final parsedDate = parseDate(_cell(raw, mapping, ColumnRole.buyDate));
      final today = DateTime.now();
      final buyDate = (parsedDate == null || parsedDate.isAfter(today))
          ? fallbackDate
          : parsedDate;

      rows.add(ImportRow(
        rowIndex: i,
        symbol: normalizedSymbol,
        name: name.isNotEmpty ? name : symbol,
        quantity: quantity,
        avgPrice: (avgPrice != null && avgPrice > 0) ? avgPrice : null,
        currentPrice: (currentPrice != null && currentPrice > 0)
            ? currentPrice
            : null,
        buyDate: buyDate,
        assetType: type,
      ));
    }

    final counts = <SkipReason, int>{};
    for (final s in skipped) {
      counts[s.reason] = (counts[s.reason] ?? 0) + 1;
    }

    return ImportPreview(rows: rows, skipped: skipped, skipCounts: counts);
  }

  /// 엑셀이 종목코드를 **숫자 셀**로 저장하면 앞의 0이 날아간다
  /// (`'005930'` → `5930`). 그러면 [inferType]이 한국 종목으로 못 알아보고
  /// 파일 전체가 "유형 판단 불가"로 버려진다.
  ///
  /// 한국 종목코드는 정확히 6자리이고 미국 티커는 숫자가 아니므로, 숫자만으로
  /// 된 5자리 이하 코드는 6자리로 채운다. 사용자가 유형을 미국으로 **직접
  /// 고른** 경우에는 건드리지 않는다.
  static String _restoreKrCode(String symbol, AssetType? forcedType) {
    if (forcedType != null && forcedType != AssetType.krStock) return symbol;
    if (!RegExp(r'^\d{1,5}$').hasMatch(symbol)) return symbol;
    return symbol.padLeft(6, '0');
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

/// 포함관계 매칭 후보 하나. 더 긴 후보가 이기게 정렬하는 데만 쓴다.
class _ContainmentMatch {
  final ColumnRole role;
  final int column;
  final int length;

  const _ContainmentMatch(this.role, this.column, this.length);
}
