# CSV·엑셀 표 가져오기 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 증권사에서 받은 `.csv`/`.xlsx` 표를 올려 보유 종목을 포트폴리오에 일괄 등록한다.

**Architecture:** 파싱·매핑·쓰기 로직은 Flutter에 의존하지 않는 순수 Dart 모듈 4개(`column_matcher`, `table_file_parser`, `import_mapping_local_ds`, `import_writer`)로 분리하고, 화면은 그 모듈을 조립만 한다. 기존 파일은 등록 한 줄씩만 건드린다. 선행 버그(`stock_kr`) 수정은 기능과 섞지 않고 Task 1에서 따로 끝낸다.

**Tech Stack:** Flutter / Dart, plain Riverpod 2.6.1, Drift 2.20.3, `csv`, `excel`, `charset`, 기존 `file_picker 8.1.7`

**Spec:** [2026-11-22-csv-excel-import-design.md](../specs/2026-11-22-csv-excel-import-design.md)

## Global Constraints

- `riverpod_generator` 금지 — plain `Provider` / `StateNotifierProvider`만. (`freezed_annotation ^2.4.4` 충돌)
- 새 도메인 모델은 plain Dart. `freezed`/`build_runner` 불필요. 단 Task 1은 drift 코드 생성을 돌린다.
- `AssetType` 유효 값: `usStock` `krStock` `crypto` `krFund` `gold` `cash`. 문자열 리터럴 금지, `AssetType.x.value` 사용.
- `currency`는 `AssetType.currency` getter에서 가져온다. 하드코딩 금지.
- `.withOpacity()` 금지 → `.withValues(alpha: x)`
- `DropdownButtonFormField`는 `value:` 대신 `initialValue:` + `key: ValueKey(value)`
- `firstOrNull` 사용 금지 (`collection` 패키지 미포함) → `isNotEmpty ? .first : null`
- 가져오기는 **추가만** 한다. 기존 자산·거래·투자원금을 수정·삭제하지 않는다.
- `insertOnConflictUpdate`의 ON CONFLICT 타깃은 **PK**다. `{symbol, assetType}` 중복은 `getBySymbolAndType` 선조회로 막는다.
- 모든 DB 쓰기는 **하나의 트랜잭션** 안에서. 줄마다 쓰면 joined `.watch()` 스트림이 매번 재발화한다.
- 완료 기준에 `flutter analyze` 무경고 포함.

## Review Focus

스펙이 암시하지만 어느 태스크도 자동으로 안 덮는 입력. 각 줄의 테스트는 해당 태스크에 포함시켰다.

1. **UTF-8 BOM** — 한국 엑셀이 CSV로 내보내면 첫 헤더 셀이 `﻿종목코드`가 된다. 사전에 안 걸려 첫 열이 통째로 날아간다. → Task 3
2. **파일 안에 같은 종목이 두 줄** (분할 매수가 합산 안 된 표) — `portfolio_assets`의 `{portfolioId, assetId}` UNIQUE가 터져 트랜잭션 전체가 실패한다. 합산하지 않고 **첫 줄만 쓰고 나머지는 사유별로 센다**. → Task 2
3. **소수 수량** (`0.5`, `1.234`) — 소수점 거래·해외 ETF. 정수 파싱이면 조용히 버려진다. → Task 2
4. **통과한 줄이 0개** — 전부 건너뛰기 대상인 파일. `investments`에 0원이 기록되거나 빈 포트폴리오가 생기면 안 된다. 쓰기를 아예 하지 않는다. → Task 5
5. **헤더만 있고 데이터가 없는 파일 / 완전히 빈 파일** — 예외로 떨어지지 않고 `0행 인식`으로 보여야 한다. → Task 3

---

### Task 1: `stock_kr` 정합성 수정 (선행, 가져오기와 독립)

`kis_import_screen.dart`가 `assetType: 'stock_kr'`로 저장해 왔다. `AssetType.fromValue('stock_kr')`는 `orElse`로 빠져 **`usStock`을 반환**한다. 리터럴만 고치면 기존 DB의 `stock_kr` 행은 계속 미국 주식으로 읽히고 새 `krStock` 행과 같은 종목이 중복된다.

**Files:**
- Modify: `lib/data/database/daos/asset_dao.dart` (`migrateGoldCurrencyToKrw` 아래)
- Modify: `lib/data/database/app_database.dart:45-56`
- Modify: `lib/presentation/screens/kis/kis_import_screen.dart:180-191`
- Test: `test/stock_kr_migration_test.dart` (Step 1에서 가능 여부 판정)

**Interfaces:**
- Consumes: 없음
- Produces: `AssetDao.migrateKrStockAssetType()` → `Future<void>`

- [ ] **Step 1: 테스트 환경 판정**

`flutter test`에서 drift 메모리 DB가 뜨는지 먼저 확인한다. 이 프로젝트에는 `sqlite3` dev 의존이 없어 Windows에서 안 뜰 수 있다.

```dart
// test/stock_kr_migration_test.dart (임시 판정용)
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assetallocation/data/database/app_database.dart';

void main() {
  test('in-memory drift boots', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('select 1').get();
    await db.close();
  });
}
```

Run: `flutter test test/stock_kr_migration_test.dart`
- **PASS** → Step 2로 간다 (마이그레이션 테스트를 쓴다).
- **FAIL** (sqlite3 라이브러리 못 찾음) → 이 파일을 지우고 Step 2~4를 건너뛰고 **Step 5**로 간다. 이 태스크는 `flutter analyze` + Task 7 기기 확인으로 검증한다. 테스트 하네스 추가는 이번 범위가 아니다.

- [ ] **Step 2: 실패하는 마이그레이션 테스트 작성** (Step 1이 PASS일 때만)

각 케이스는 `assets`에 직접 insert한 뒤 `migrateKrStockAssetType()`을 호출하고 결과를 읽는다.

```dart
test('stock_kr 행이 krStock/KRW로 바뀐다', () async {
  // insert symbol '005930', assetType 'stock_kr', currency 'USD'
  await db.assetDao.migrateKrStockAssetType();
  final row = await db.assetDao.getBySymbolAndType('005930', 'krStock');
  expect(row, isNotNull);
  expect(row!.currency, 'KRW');
  expect(await db.assetDao.getBySymbolAndType('005930', 'stock_kr'), isNull);
});

test('같은 symbol의 krStock 행이 이미 있으면 하나만 남는다', () async {
  // insert ('005930','krStock') AND ('005930','stock_kr')
  await db.assetDao.migrateKrStockAssetType();
  final all = await db.assetDao.getAll();
  expect(all.where((a) => a.symbol == '005930').length, 1);
});

test('중복 병합 시 portfolio_assets가 남은 행을 가리킨다', () async {
  // stock_kr 행을 참조하는 portfolio_assets를 만들어 두고 병합 후 assetId 확인
});

test('stock_kr 행이 없으면 아무 일도 없다', () async {
  // insert ('AAPL','usStock')만
  await db.assetDao.migrateKrStockAssetType();
  expect((await db.assetDao.getAll()).single.assetType, 'usStock');
});
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `flutter test test/stock_kr_migration_test.dart`
Expected: FAIL — `migrateKrStockAssetType` 미정의

- [ ] **Step 4: `AssetDao.migrateKrStockAssetType()` 구현**

`lib/data/database/daos/asset_dao.dart`. `migrateGoldCurrencyToKrw()`를 선례로 따르고 doc comment에 왜 필요한지(enum 값 불일치) 적는다.

순서가 중요하다 — 중복을 먼저 정리하고 나머지를 갱신한다. 반대로 하면 UPDATE가 `{symbol, assetType}` UNIQUE를 위반한다.

1. `stock_kr` 행 중 같은 `symbol`의 `krStock` 행이 **이미 있는** 것: 그 행을 참조하는 `portfolio_assets.assetId`를 남은 `krStock` 행의 id로 `update`한 뒤 `stock_kr` 행을 `delete`
2. 남은 `stock_kr` 행을 `assetType: 'krStock'`, `currency: 'KRW'`로 `update`

- [ ] **Step 5: `app_database.dart`에 마이그레이션 등록**

`schemaVersion` 3 → 4. `onUpgrade`에 기존 분기 뒤로 추가:

```dart
if (from < 4) {
  await assetDao.migrateKrStockAssetType();
}
```

- [ ] **Step 6: `kis_import_screen.dart` 쓰기 경로 수정**

`:187`의 `assetType: 'stock_kr'` → `AssetType.krStock.value`, `currency: 'KRW'` → `AssetType.krStock.currency`. `AssetType` import 추가.

`:183`의 `db.assetDao.upsert(...)`를 `getBySymbolAndType` 선조회로 감싼다 — 있으면 그 `id`를 쓰고, 없을 때만 `upsert`. (지금은 이미 보유한 종목 하나가 가져오기 전체를 실패시킨다.)

`:180`의 `h.stockCode.isNotEmpty ? h.stockCode : h.stockName` 폴백은 **건드리지 않는다.** 계좌 가져오기의 기존 동작이고 이번 범위가 아니다.

- [ ] **Step 7: 코드 생성 + 검증**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
```
Expected: analyze 무경고. Step 1이 PASS였다면 `flutter test`도 전체 통과.

- [ ] **Step 8: 커밋**

```bash
git add lib/data/database/ lib/presentation/screens/kis/kis_import_screen.dart test/
git commit -m "fix: stock_kr assetType을 krStock으로 통일하고 중복 자산 병합 마이그레이션 추가"
```

---

### Task 2: 열 매핑·값 정규화 (`column_matcher`)

순수 Dart. 파일 포맷도, DB도, 화면도 모른다. 2차원 문자열 표를 받아 헤더 행을 찾고, 역할을 추측하고, 각 줄을 검증해 통과/건너뛰기로 나눈다.

**Files:**
- Create: `lib/domain/entities/import_table.dart`
- Create: `lib/domain/services/column_matcher.dart`
- Test: `test/column_matcher_test.dart`

**Interfaces:**
- Consumes: `AssetType` (`lib/domain/enums/asset_type.dart`)
- Produces:
  - `enum ColumnRole { symbol, name, quantity, avgPrice, currentPrice, buyDate }`
  - `enum SkipReason { noSymbol, badQuantity, unknownType, duplicateInFile, alreadyHeld }`
  - `class ImportTable { List<String> header; List<List<String>> rows; String sheetName; }`
  - `class ImportRow { String symbol; String name; double quantity; double? avgPrice; double? currentPrice; DateTime buyDate; AssetType assetType; }`
  - `class SkippedRow { int rowIndex; SkipReason reason; }`
  - `class ImportPreview { List<ImportRow> rows; List<SkippedRow> skipped; Map<SkipReason, int> skipCounts; }`
  - `class ColumnMatcher`:
    - `static String normalizeHeader(String raw)` — 공백·괄호 제거 + 소문자
    - `static int findHeaderRow(List<List<String>> rows)` — 첫 20행 중 사전 적중 최다, 동점이면 위쪽, 전무면 첫 비어있지 않은 행
    - `static Map<ColumnRole, int> guessMapping(List<String> header)`
    - `static Map<ColumnRole, int> resolveMapping({required List<String> header, Map<ColumnRole, String>? remembered})` — 기억된 매핑(열 **이름**)을 인덱스로 바꾸고, 거기서 빈 역할만 `guessMapping`으로 채운다. 기억된 쪽이 이긴다. 기억된 이름이 이 파일에 없으면 그 역할은 `guessMapping`으로 떨어진다.
    - `static double? parseNumber(String raw)`
    - `static DateTime? parseDate(String raw)`
    - `static AssetType? inferType(String symbol)`
    - `static ImportPreview buildPreview({required ImportTable table, required Map<ColumnRole, int> mapping, required AssetType? forcedType, required DateTime fallbackDate, required Set<String> alreadyHeldKeys})` — `alreadyHeldKeys`의 원소는 `symbol` + `'|'` + `assetType.value`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
group('parseNumber', () {
  test('천 단위 쉼표와 단위 표기를 걷어낸다', () {
    expect(ColumnMatcher.parseNumber('1,284,000원'), 1284000);
    expect(ColumnMatcher.parseNumber(' 10 주 '), 10);
  });
  test('괄호는 음수', () => expect(ColumnMatcher.parseNumber('(500)'), -500));
  test('소수 수량을 유지한다', () {              // Review Focus 3
    expect(ColumnMatcher.parseNumber('0.5'), 0.5);
    expect(ColumnMatcher.parseNumber('1.234'), 1.234);
  });
  test('빈 칸과 붙임표는 null', () {
    expect(ColumnMatcher.parseNumber(''), isNull);
    expect(ColumnMatcher.parseNumber('-'), isNull);
  });
});

group('parseDate', () {
  test('네 가지 형식', () {
    for (final s in ['2026-01-02', '2026.01.02', '20260102', '2026/01/02']) {
      expect(ColumnMatcher.parseDate(s), DateTime(2026, 1, 2), reason: s);
    }
  });
  test('못 읽는 값은 null', () => expect(ColumnMatcher.parseDate('어제'), isNull));
});

group('findHeaderRow', () {
  test('상단 쓰레기 행을 건너뛰고 헤더를 찾는다', () {
    final rows = [
      ['삼성증권 잔고조회'], [''], ['계좌번호', '123-45'], [''],
      ['종목코드', '종목명', '보유수량', '매입단가'],
      ['005930', '삼성전자', '10', '71200'],
    ];
    expect(ColumnMatcher.findHeaderRow(rows), 4);
  });
  test('사전에 하나도 안 걸리면 첫 비어있지 않은 행', () {
    expect(ColumnMatcher.findHeaderRow([[''], ['가', '나'], ['1', '2']]), 1);
  });
});

group('guessMapping', () {
  test('증권사별 다른 이름을 같은 역할로 맞춘다', () {
    final m = ColumnMatcher.guessMapping(['단축코드', '상품명', '보유수량', '매입단가', '현재가']);
    expect(m[ColumnRole.symbol], 0);
    expect(m[ColumnRole.name], 1);
    expect(m[ColumnRole.quantity], 2);
    expect(m[ColumnRole.avgPrice], 3);
    expect(m[ColumnRole.currentPrice], 4);
  });
  test('완전일치가 포함관계보다 우선한다', () {
    // ['평가단가', '매입단가'] 에서 avgPrice는 '매입단가'(완전일치) 쪽
  });
});

group('resolveMapping', () {
  test('기억된 매핑이 자동 매핑을 덮어쓴다', () {
    // 자동으로는 '수량'(0)을 quantity로 찍지만, 기억된 매핑은 '결제수량'(1)을 가리킨다
    final m = ColumnMatcher.resolveMapping(
      header: ['수량', '결제수량', '종목코드'],
      remembered: {ColumnRole.quantity: '결제수량'},
    );
    expect(m[ColumnRole.quantity], 1);
    expect(m[ColumnRole.symbol], 2);   // 기억에 없는 역할은 자동으로 채워진다
  });
  test('기억된 이름이 이 파일에 없으면 그 역할은 자동 매핑으로 떨어진다', () {
    final m = ColumnMatcher.resolveMapping(
      header: ['종목코드', '수량'],
      remembered: {ColumnRole.quantity: '없는열'},
    );
    expect(m[ColumnRole.quantity], 1);
  });
  test('remembered가 null이면 guessMapping과 같다', () {
    expect(ColumnMatcher.resolveMapping(header: ['종목코드', '수량']),
        ColumnMatcher.guessMapping(['종목코드', '수량']));
  });
});

group('inferType', () {
  test('6자리 숫자는 krStock, 영문 티커는 usStock, 나머지는 null', () {
    expect(ColumnMatcher.inferType('005930'), AssetType.krStock);
    expect(ColumnMatcher.inferType('QQQ'), AssetType.usStock);
    expect(ColumnMatcher.inferType('삼성전자'), isNull);
  });
});

group('buildPreview', () {
  test('종목코드 없는 줄을 사유별로 센다', () {
    // skipCounts[SkipReason.noSymbol] == 2, rows에는 안 들어감
  });
  test('수량이 0이거나 음수면 badQuantity', () {});
  test('유형을 못 정하면 unknownType', () {});
  test('이미 보유한 종목은 alreadyHeld로 건너뛴다', () {
    // alreadyHeldKeys: {'005930|krStock'}
  });
  test('파일 안에 같은 종목이 두 줄이면 첫 줄만 통과하고 둘째는 duplicateInFile', () {
    // Review Focus 2 — portfolio_assets UNIQUE를 터뜨리지 않기 위함
  });
  test('forcedType이 있으면 파일 전체에 적용된다', () {});
  test('매수일 열이 있으면 줄마다 그 날짜를, 없으면 fallbackDate를 쓴다', () {});
  test('avgPrice가 없는 줄은 통과하되 avgPrice가 null이다', () {
    // 종목만 등록 — 수량이 조용히 사라지지 않게
  });
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/column_matcher_test.dart`
Expected: FAIL — 컴파일 에러 (타입 미정의)

- [ ] **Step 3: `import_table.dart`의 모델·enum 구현**

Interfaces 블록의 타입을 그대로. plain Dart, `const` 생성자, `final` 필드.

- [ ] **Step 4: `column_matcher.dart` 구현**

열 이름 사전은 스펙의 "열 이름 사전 (초기값)" 표를 그대로 옮긴다. `static const Map<ColumnRole, List<String>>`로 두고, 비교는 `normalizeHeader`를 거친 뒤 **완전일치 우선, 없으면 포함관계**. 한 열이 두 역할에 걸리면 완전일치가 이긴다.

`buildPreview`는 줄을 순서대로 보면서 통과 조건(`symbol` 있음 **그리고** `quantity`가 양수 **그리고** 유형 정해짐 **그리고** 파일 내 중복 아님 **그리고** `alreadyHeldKeys`에 없음)을 확인하고, 떨어진 줄은 **첫 실패 사유 하나로만** 센다.

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/column_matcher_test.dart`
Expected: PASS

- [ ] **Step 6: 커밋**

```bash
git add lib/domain/entities/import_table.dart lib/domain/services/column_matcher.dart test/column_matcher_test.dart
git commit -m "feat: 표 가져오기 열 매핑·값 정규화 모듈"
```

---

### Task 3: 파일 파싱 (`table_file_parser`)

바이트 → `ImportTable`. 파일 **선택**은 하지 않는다(화면 책임). 바이트만 받으므로 순수 Dart이고 테스트가 된다.

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/data/datasources/local/table_file_parser.dart`
- Test: `test/table_file_parser_test.dart`

**Interfaces:**
- Consumes: Task 2의 `ImportTable`, `ColumnMatcher.findHeaderRow`, `ColumnMatcher.normalizeHeader`
- Produces:
  - `class TableParseException implements Exception { final String message; }`
  - `class TableFileParser`:
    - `static ImportTable parse(Uint8List bytes, String fileName)` — 실패 시 `TableParseException`
    - `static bool isXlsx(Uint8List bytes)` — ZIP 매직바이트 `0x50 0x4B`
    - `static String decodeCsv(Uint8List bytes)` — UTF-8 엄격 → 실패 시 `eucKr`, BOM 제거

- [ ] **Step 1: 패키지 추가**

```bash
flutter pub add csv excel charset
```

`archive` 4.0.9→3.6.1, `image` 4.8.0→4.3.0 다운그레이드가 뜬다. 둘 다 `flutter_launcher_icons`(**dev** 의존)만 쓰므로 배포 앱에 영향 없다 — 그대로 둔다.

- [ ] **Step 2: 실패하는 테스트 작성**

```dart
group('decodeCsv', () {
  test('EUC-KR 한글 종목명이 깨지지 않는다', () {
    final bytes = Uint8List.fromList(eucKr.encode('종목명\n삼성전자\n'));
    expect(TableFileParser.decodeCsv(bytes), contains('삼성전자'));
  });
  test('UTF-8 BOM을 제거한다', () {                 // Review Focus 1
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('종목코드,수량\n')]);
    expect(TableFileParser.decodeCsv(bytes).startsWith('종목코드'), isTrue);
  });
  test('BOM 있는 파일의 첫 열이 symbol로 매핑된다', () {   // Review Focus 1 — 끝까지
    final t = TableFileParser.parse(
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('종목코드,수량\n005930,10\n')]),
        'a.csv');
    expect(ColumnMatcher.guessMapping(t.header)[ColumnRole.symbol], 0);
  });
});

group('isXlsx', () {
  test('확장자가 아니라 ZIP 매직바이트로 판별한다', () {
    expect(TableFileParser.isXlsx(Uint8List.fromList([0x50, 0x4B, 0x03, 0x04])), isTrue);
    expect(TableFileParser.isXlsx(Uint8List.fromList(utf8.encode('a,b\n'))), isFalse);
  });
});

group('parse — csv', () {
  test('구분자를 자동으로 고른다 (쉼표·탭·세미콜론)', () {
    for (final d in [',', '\t', ';']) {
      final t = TableFileParser.parse(_utf8('종목코드${d}수량\n005930${d}10\n'), 'a.csv');
      expect(t.header, ['종목코드', '수량'], reason: d);
      expect(t.rows.single, ['005930', '10']);
    }
  });
  test('헤더 위 쓰레기 행을 잘라낸다', () {
    final t = TableFileParser.parse(
        _utf8('삼성증권 잔고\n계좌번호,123\n종목코드,수량\n005930,10\n'), 'a.csv');
    expect(t.header, ['종목코드', '수량']);
    expect(t.rows.length, 1);
  });
  test('헤더만 있고 데이터가 없으면 rows가 비고 예외가 아니다', () {   // Review Focus 5
    expect(TableFileParser.parse(_utf8('종목코드,수량\n'), 'a.csv').rows, isEmpty);
  });
  test('완전히 빈 파일은 TableParseException', () {                  // Review Focus 5
    expect(() => TableFileParser.parse(Uint8List(0), 'a.csv'),
        throwsA(isA<TableParseException>()));
  });
  test('열 개수가 헤더보다 적은 줄은 빈 문자열로 채운다', () {
    final t = TableFileParser.parse(_utf8('종목코드,종목명,수량\n005930,삼성전자\n'), 'a.csv');
    expect(t.rows.single, ['005930', '삼성전자', '']);
  });
});

group('parse — xlsx', () {
  test('시트가 여러 개면 헤더 점수가 가장 높은 시트를 쓴다', () {
    // excel 패키지로 2시트 통합문서를 만들어 encode():
    // '설명' 시트엔 안내문만, '잔고' 시트엔 종목코드/수량 헤더
    expect(TableFileParser.parse(bytes, 'b.xlsx').sheetName, '잔고');
  });
});
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `flutter test test/table_file_parser_test.dart`
Expected: FAIL — `TableFileParser` 미정의

- [ ] **Step 4: `table_file_parser.dart` 구현**

- 포맷: `isXlsx(bytes)`가 참이면 `excel`, 아니면 CSV. 확장자는 보조 신호로만 — 안드로이드 `file_picker`가 확장자 없는 이름을 줄 수 있다.
- 구분자: 첫 5줄에서 후보별 분할 개수를 세어, 줄마다 개수가 일정하고 그 개수가 2 이상인 후보를 고른다. 동점이면 쉼표.
- CSV 파싱은 `CsvToListConverter(shouldParseNumbers: false)` — 모든 셀을 문자열로 받아 Task 2가 정규화한다.
- 시트 점수: 시트마다 `ColumnMatcher.findHeaderRow`를 돌려 그 행의 사전 적중 개수를 점수로 쓴다. 동점이면 첫 시트.
- 모든 셀은 `trim()`한 문자열로 담는다.
- CP949 전용 문자로 `eucKr.decode`가 던지면 `TableParseException`으로 감싸고 메시지에 "UTF-8로 저장해 주세요"를 담는다.

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/table_file_parser_test.dart`
Expected: PASS

- [ ] **Step 6: 커밋**

```bash
git add pubspec.yaml pubspec.lock lib/data/datasources/local/table_file_parser.dart test/table_file_parser_test.dart
git commit -m "feat: CSV/XLSX 표 파서 (인코딩·구분자·멀티시트 자동 판별)"
```

---

### Task 4: 매핑 기억 (`import_mapping_local_ds`)

같은 증권사 파일을 다음부터 자동으로 통과시킨다.

**Files:**
- Create: `lib/data/datasources/local/import_mapping_local_ds.dart`
- Modify: `lib/services/backup_service.dart:11-38`
- Test: `test/import_mapping_local_ds_test.dart`

**Interfaces:**
- Consumes: Task 2의 `ColumnRole`, `ColumnMatcher.normalizeHeader`
- Produces: `class ImportMappingLocalDataSource`
  - `ImportMappingLocalDataSource(SharedPreferences prefs)`
  - `static const prefsKey = 'import_column_mappings_v1'`
  - `static String signatureOf(List<String> header)`
  - `Map<ColumnRole, String>? load(String signature)` — 역할 → **열 이름**(인덱스 아님)
  - `Future<void> save(String signature, Map<ColumnRole, String> mapping)`

열 **이름**으로 저장하는 이유: 같은 증권사가 열 순서를 바꿔도 살아남는다. 이름을 인덱스로 바꾸는 것은 호출자(Task 6)가 한다.

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
setUp(() => SharedPreferences.setMockInitialValues({}));

test('서명은 열 순서가 바뀌어도 같다', () {
  expect(ImportMappingLocalDataSource.signatureOf(['종목코드', '수량']),
         ImportMappingLocalDataSource.signatureOf(['수량', '종목코드']));
});
test('서명은 열 구성이 다르면 다르다', () {
  expect(ImportMappingLocalDataSource.signatureOf(['종목코드', '수량']),
      isNot(ImportMappingLocalDataSource.signatureOf(['단축코드', '수량'])));
});
test('저장한 매핑을 같은 서명으로 되읽는다', () async {
  await ds.save('sig', {ColumnRole.symbol: '단축코드'});
  expect(ds.load('sig'), {ColumnRole.symbol: '단축코드'});
});
test('모르는 서명은 null', () => expect(ds.load('없음'), isNull));
test('같은 서명에 다시 저장하면 덮어쓴다', () async {});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/import_mapping_local_ds_test.dart`
Expected: FAIL — 클래스 미정의

- [ ] **Step 3: `import_mapping_local_ds.dart` 구현**

JSON 구조: `{"<signature>": {"symbol": "단축코드", "quantity": "보유수량"}}`. 서명은 각 헤더 셀에 `normalizeHeader` 적용 → 정렬 → `'|'`로 이어붙임 → `hashCode.toRadixString(16)`. 해시 충돌은 사용자가 고치면 덮어써지므로 암호학적 해시는 쓰지 않는다(의존성 추가 없음).

알 수 없는 역할 문자열이 JSON에 있으면 무시한다(앱 버전이 내려간 경우).

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/import_mapping_local_ds_test.dart`
Expected: PASS

- [ ] **Step 5: 백업에 키 추가**

`backup_service.dart`의 `_prefKeys` 리스트에 `'import_column_mappings_v1'` 추가. 파일 상단 doc comment의 키 목록에도 한 줄 추가. 안 넣으면 복원 때 기억된 매핑이 사라진다.

- [ ] **Step 6: 커밋**

```bash
git add lib/data/datasources/local/import_mapping_local_ds.dart lib/services/backup_service.dart test/import_mapping_local_ds_test.dart
git commit -m "feat: 열 매핑 기억 + 백업 대상에 포함"
```

---

### Task 5: DB 쓰기 (`import_writer`)

확정된 `ImportRow` 목록을 하나의 트랜잭션으로 쓴다. 파일 형식도 화면도 모른다. 거래 내역 가져오기(다음 확장)에서 재사용한다.

**Files:**
- Create: `lib/domain/services/import_writer.dart`
- Test: `test/import_writer_test.dart`

**Interfaces:**
- Consumes: Task 2의 `ImportRow`, `AppDatabase`, `AssetType`
- Produces: `class ImportWriter`
  - `ImportWriter(AppDatabase db)`
  - `Future<int> write({required int portfolioId, required List<ImportRow> rows, required String fileName, required double usdKrwRate})` → 등록된 종목 수
  - `static double totalInvestmentKrw(List<ImportRow> rows, double usdKrwRate)` — **순수 함수**
  - `static DateTime earliestDate(List<ImportRow> rows)` — **순수 함수**

- [ ] **Step 1: 실패하는 테스트 작성 (순수 함수만)**

DB 쓰기 자체는 `sqlite3` 테스트 하네스가 없어 단위 테스트하지 않는다(Task 1 Step 1 참조) — Task 7에서 기기로 확인한다. 금액 계산은 틀리면 조용히 잘못된 수치가 되므로(anti-goal 1) 반드시 덮는다.

```dart
group('totalInvestmentKrw', () {
  test('한국 종목은 수량×평단 그대로', () {
    expect(ImportWriter.totalInvestmentKrw([_kr(qty: 10, price: 71200)], 1400), 712000);
  });
  test('미국 종목은 환율로 환산한다', () {
    expect(ImportWriter.totalInvestmentKrw([_us(qty: 5, price: 100)], 1400), 700000);
  });
  test('섞여 있으면 합산한다', () {
    expect(ImportWriter.totalInvestmentKrw(
        [_kr(qty: 10, price: 71200), _us(qty: 5, price: 100)], 1400), 1412000);
  });
  test('avgPrice가 null인 줄은 합계에서 제외한다', () {
    expect(ImportWriter.totalInvestmentKrw([_kr(qty: 10, price: null)], 1400), 0);
  });
  test('빈 목록은 0', () => expect(ImportWriter.totalInvestmentKrw([], 1400), 0));
});

group('earliestDate', () {
  test('줄마다 날짜가 다르면 가장 이른 날짜', () {
    // 연평균의 보유기간이 과소평가되지 않게
  });
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/import_writer_test.dart`
Expected: FAIL — `ImportWriter` 미정의

- [ ] **Step 3: `import_writer.dart` 구현**

`rows`가 비면 트랜잭션에 들어가지 않고 즉시 `0`을 반환한다(Review Focus 4).

`write`는 전체를 `db.transaction(() async { ... })`로 감싼다. 줄마다:

1. `db.assetDao.getBySymbolAndType(symbol, assetType.value)` — 있으면 그 `id`, 없으면 `AssetsCompanion.insert(symbol:, name:, assetType: t.value, currency: t.currency)`로 insert. `lastPrice`는 **쓰지 않는다**(파일 가격은 과거 값이고 `lastPriceUpdatedAt`에 넣을 날짜가 없다).
2. `db.portfolioAssetDao.insert(PortfolioAssetsCompanion.insert(portfolioId:, assetId:, targetWeight: 0))` — 반환 id를 그대로 쓴다(KIS 화면처럼 되조회하지 않는다).
3. `row.avgPrice != null`이면 `db.transactionDao.insert(TransactionsCompanion.insert(portfolioAssetId:, type: 'buy', quantity:, price:, transactionDate: row.buyDate, memo: Value('파일 가져오기: ' + fileName)))`. `exchangeRate`는 `usStock`일 때 `usdKrwRate`, 아니면 기본값 1.

마지막에, **`totalInvestmentKrw`가 0보다 클 때만** `db.investmentDao.insert(InvestmentsCompanion.insert(portfolioId:, amount:, investmentDate: earliestDate(rows), memo: Value('파일 가져오기: ' + fileName)))` 한 건.

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/import_writer_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/domain/services/import_writer.dart test/import_writer_test.dart
git commit -m "feat: 표 가져오기 DB 쓰기 (단일 트랜잭션, 투자원금 1건)"
```

---

### Task 6: 화면과 연결

앞의 모듈을 조립한다. 파싱·검증 로직을 여기에 넣지 않는다.

**Files:**
- Create: `lib/presentation/providers/file_import_providers.dart`
- Create: `lib/presentation/screens/file_import/file_import_screen.dart`
- Modify: `lib/core/router/app_router.dart:20,39`
- Modify: `lib/presentation/screens/settings/settings_screen.dart:286`

**Interfaces:**
- Consumes: Task 2~5 전부, `appDatabaseProvider`·`sharedPreferencesProvider` (`database_providers.dart:20,40`), `usdKrwRateProvider` (`price_providers.dart:43`), `portfoliosStreamProvider`
- Produces: `/file-import` 라우트, `FileImportScreen`

- [ ] **Step 1: providers 작성**

```dart
final importMappingDsProvider = Provider<ImportMappingLocalDataSource>((ref) =>
    ImportMappingLocalDataSource(ref.watch(sharedPreferencesProvider)));

final importWriterProvider = Provider<ImportWriter>((ref) =>
    ImportWriter(ref.watch(appDatabaseProvider)));
```

plain `Provider`만. 화면 상태는 `ConsumerStatefulWidget`의 `State`가 들고 있는다(`StrategyResultScreen` 선례).

- [ ] **Step 2: 화면 구현**

스펙 "흐름"의 ASCII 스케치를 따른다. 순서:

1. `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'xlsx'], withData: true)` — 바이트를 직접 받는다(`backup_service`와 같은 방식).
2. `TableFileParser.parse(bytes, fileName)`
3. `signatureOf(header)` → `load(signature)` → `ColumnMatcher.resolveMapping(header: t.header, remembered: loaded)`. 병합 규칙은 `resolveMapping`에 있고 화면은 호출만 한다.
4. 역할 6개 드롭다운(`initialValue:` + `key: ValueKey(...)`, 각 역할에 `없음` 선택지), 취득일 `showDatePicker`(기본값 오늘, 미래 날짜 금지), 유형 드롭다운은 `자동` / `한국 주식·ETF` / `미국 주식·ETF` **셋만**.
5. 입력이 바뀌면 `ColumnMatcher.buildPreview(...)` 재계산. `alreadyHeldKeys`는 선택된 포트폴리오의 `portfolioAssetDao.getByPortfolio`에서 만든다(포트폴리오를 바꾸면 다시 만든다).
6. 미리보기: 통과 줄 목록, `합계 투자원금`(= `ImportWriter.totalInvestmentKrw`), 건너뛴 줄을 **사유별 한 줄씩** 경고로. `avgPrice`가 없는 줄에는 `평균단가 없음 — 종목만 등록` 표시.
7. 포트폴리오 선택(기존 드롭다운 / 새로 만들기 — 기본 이름은 파일명에서 확장자를 뗀 것, 수정 가능).
8. 가져오기 버튼: `ImportWriter.write(...)`. 통과 줄이 0이면 버튼을 **비활성**으로 두고 이유를 보여준다(Review Focus 4). 성공하면 매핑을 `save`하고 `SnackBar`로 알린 뒤 `pop`.
9. `TableParseException`은 `AlertDialog`로 메시지를 그대로 보여준다. `.xls`를 고르면 "엑셀에서 .xlsx로 저장해 주세요"로 안내한다.

- [ ] **Step 3: 라우트 등록**

`app_router.dart` — `/kis-import` 바로 뒤에:

```dart
// CSV·엑셀 표 파일로 보유 종목을 불러오는 화면.
GoRoute(
  path: '/file-import',
  builder: (context, state) => const FileImportScreen(),
),
```

- [ ] **Step 4: 설정 화면에 진입점 추가**

`settings_screen.dart`의 `증권사 계좌 가져오기` ListTile(`:286`) 바로 **아래**, 같은 섹션에 한 개 추가. `leading: Icon(Icons.table_chart_outlined)`, `title: '파일에서 가져오기'`, `subtitle: 'CSV·엑셀 표 파일로 보유 종목을 불러옵니다'`, `onTap: () => context.push('/file-import')`. Beta 배지는 붙이지 않는다.

- [ ] **Step 5: 검증**

```bash
flutter analyze
flutter test
```
Expected: analyze 무경고, 테스트 전체 통과.

- [ ] **Step 6: 커밋**

```bash
git add lib/presentation/providers/file_import_providers.dart lib/presentation/screens/file_import/ lib/core/router/app_router.dart lib/presentation/screens/settings/settings_screen.dart
git commit -m "feat: 파일에서 가져오기 화면 + 설정 진입점"
```

---

### Task 7: 실기기 확인

자동 테스트가 못 덮는 것: `file_picker` 실제 동작, 안드로이드 저장소 권한, 드리프트 마이그레이션이 **기존 DB**에서 돌아가는 것, `ImportWriter.write`의 실제 쓰기.

- [ ] **Step 1:** 기존 데이터가 있는 기기에 설치 → 앱 시작 → 계좌 가져오기로 넣었던 한국 종목이 **한국 주식**으로 보이고 중복이 없는지 (Task 1 마이그레이션)
- [ ] **Step 2:** 실제 증권사 CSV로 가져오기 → 자동 매핑 적중 여부를 보고 `column_matcher`의 사전 보강
- [ ] **Step 3:** 같은 파일을 다시 가져오기 → `이미 보유 중 — N줄 건너뜁니다`가 나오고 **실패하지 않는지**
- [ ] **Step 4:** `.xlsx` 파일로 같은 흐름 → 멀티시트 파일에서 올바른 시트를 골랐는지
- [ ] **Step 5:** 포트폴리오 화면에서 수익률·연평균·추이가 과거 취득일 기준으로 보이는지
- [ ] **Step 6:** 백업 내보내기 → 복원 → 기억된 매핑이 살아있는지
