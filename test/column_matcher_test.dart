import 'package:flutter_test/flutter_test.dart';

import 'package:assetallocation/domain/entities/import_table.dart';
import 'package:assetallocation/domain/enums/asset_type.dart';
import 'package:assetallocation/domain/services/column_matcher.dart';

ImportTable _table(List<String> header, List<List<String>> rows) =>
    ImportTable(header: header, rows: rows, sheetName: 'Sheet1');

final _fallback = DateTime(2026, 11, 22);

ImportPreview _preview(
  List<String> header,
  List<List<String>> rows, {
  AssetType? forcedType,
  Set<String> alreadyHeldKeys = const {},
  Map<ColumnRole, int>? mapping,
}) {
  final table = _table(header, rows);
  return ColumnMatcher.buildPreview(
    table: table,
    mapping: mapping ?? ColumnMatcher.guessMapping(header),
    forcedType: forcedType,
    fallbackDate: _fallback,
    alreadyHeldKeys: alreadyHeldKeys,
  );
}

void main() {
  group('parseNumber', () {
    test('천 단위 쉼표와 단위 표기를 걷어낸다', () {
      expect(ColumnMatcher.parseNumber('1,284,000원'), 1284000);
      expect(ColumnMatcher.parseNumber(' 10 주 '), 10);
      expect(ColumnMatcher.parseNumber('"1,000"'), 1000);
    });

    test('괄호는 음수', () {
      expect(ColumnMatcher.parseNumber('(500)'), -500);
    });

    test('소수 수량을 유지한다', () {
      expect(ColumnMatcher.parseNumber('0.5'), 0.5);
      expect(ColumnMatcher.parseNumber('1.234'), 1.234);
    });

    test('빈 칸과 붙임표는 null', () {
      expect(ColumnMatcher.parseNumber(''), isNull);
      expect(ColumnMatcher.parseNumber('   '), isNull);
      expect(ColumnMatcher.parseNumber('-'), isNull);
    });
  });

  group('parseDate', () {
    test('네 가지 형식', () {
      for (final s in ['2026-01-02', '2026.01.02', '20260102', '2026/01/02']) {
        expect(ColumnMatcher.parseDate(s), DateTime(2026, 1, 2), reason: s);
      }
    });

    test('한 자리 월·일도 읽는다', () {
      expect(ColumnMatcher.parseDate('2026-1-2'), DateTime(2026, 1, 2));
    });

    test('못 읽는 값은 null', () {
      expect(ColumnMatcher.parseDate('어제'), isNull);
      expect(ColumnMatcher.parseDate(''), isNull);
    });
  });

  group('findHeaderRow', () {
    test('상단 쓰레기 행을 건너뛰고 헤더를 찾는다', () {
      final rows = [
        ['삼성증권 잔고조회'],
        [''],
        ['계좌번호', '123-45'],
        [''],
        ['종목코드', '종목명', '보유수량', '매입단가'],
        ['005930', '삼성전자', '10', '71200'],
      ];
      expect(ColumnMatcher.findHeaderRow(rows), 4);
    });

    test('사전에 하나도 안 걸리면 첫 비어있지 않은 행', () {
      expect(
        ColumnMatcher.findHeaderRow([
          [''],
          ['가', '나'],
          ['1', '2'],
        ]),
        1,
      );
    });

    test('빈 표는 0', () {
      expect(ColumnMatcher.findHeaderRow([]), 0);
    });
  });

  group('guessMapping', () {
    test('증권사별 다른 이름을 같은 역할로 맞춘다', () {
      final m = ColumnMatcher.guessMapping(
          ['단축코드', '상품명', '보유수량', '매입단가', '현재가']);
      expect(m[ColumnRole.symbol], 0);
      expect(m[ColumnRole.name], 1);
      expect(m[ColumnRole.quantity], 2);
      expect(m[ColumnRole.avgPrice], 3);
      expect(m[ColumnRole.currentPrice], 4);
    });

    test('완전일치가 포함관계보다 우선한다', () {
      final m = ColumnMatcher.guessMapping(['매입단가합계', '매입단가']);
      expect(m[ColumnRole.avgPrice], 1);
    });

    test('한 열이 두 역할을 겸하지 않는다', () {
      // '종목코드'는 name 후보 '종목'을 포함하지만 symbol이 가져간다.
      final m = ColumnMatcher.guessMapping(['종목코드', '종목명']);
      expect(m[ColumnRole.symbol], 0);
      expect(m[ColumnRole.name], 1);
    });

    test('괄호와 공백이 붙은 열 이름도 맞춘다', () {
      final m = ColumnMatcher.guessMapping(['종목 코드', '매입단가 (원)']);
      expect(m[ColumnRole.symbol], 0);
      expect(m[ColumnRole.avgPrice], 1);
    });

    test('아무것도 못 맞추면 빈 매핑', () {
      expect(ColumnMatcher.guessMapping(['가', '나']), isEmpty);
    });
  });

  group('resolveMapping', () {
    test('기억된 매핑이 자동 매핑을 덮어쓴다', () {
      final m = ColumnMatcher.resolveMapping(
        header: ['수량', '결제수량', '종목코드'],
        remembered: {ColumnRole.quantity: '결제수량'},
      );
      expect(m[ColumnRole.quantity], 1);
      expect(m[ColumnRole.symbol], 2);
    });

    test('기억된 이름이 이 파일에 없으면 그 역할은 자동 매핑으로 떨어진다', () {
      final m = ColumnMatcher.resolveMapping(
        header: ['종목코드', '수량'],
        remembered: {ColumnRole.quantity: '없는열'},
      );
      expect(m[ColumnRole.quantity], 1);
    });

    test('remembered가 null이면 guessMapping과 같다', () {
      expect(
        ColumnMatcher.resolveMapping(header: ['종목코드', '수량']),
        ColumnMatcher.guessMapping(['종목코드', '수량']),
      );
    });
  });

  group('inferType', () {
    test('6자리 숫자는 krStock, 영문 티커는 usStock, 나머지는 null', () {
      expect(ColumnMatcher.inferType('005930'), AssetType.krStock);
      expect(ColumnMatcher.inferType('QQQ'), AssetType.usStock);
      expect(ColumnMatcher.inferType('BRK.B'), AssetType.usStock);
      expect(ColumnMatcher.inferType('삼성전자'), isNull);
      expect(ColumnMatcher.inferType(''), isNull);
    });
  });

  group('buildPreview', () {
    const header = ['종목코드', '종목명', '수량', '매입단가'];

    test('정상 줄을 읽는다', () {
      final p = _preview(header, [
        ['005930', '삼성전자', '10', '71,200'],
      ]);
      expect(p.rows.length, 1);
      expect(p.skipped, isEmpty);

      final r = p.rows.single;
      expect(r.symbol, '005930');
      expect(r.name, '삼성전자');
      expect(r.quantity, 10);
      expect(r.avgPrice, 71200);
      expect(r.assetType, AssetType.krStock);
      expect(r.buyDate, _fallback);
    });

    test('종목코드 없는 줄을 사유별로 센다', () {
      final p = _preview(header, [
        ['005930', '삼성전자', '10', '71200'],
        ['', '현금성자산', '1', '1000'],
        ['  ', '합계', '5', '2000'],
      ]);
      expect(p.rows.length, 1);
      expect(p.skipCounts[SkipReason.noSymbol], 2);
    });

    test('수량이 0이거나 음수면 badQuantity', () {
      final p = _preview(header, [
        ['005930', '삼성전자', '0', '71200'],
        ['000660', 'SK하이닉스', '(5)', '71200'],
        ['035720', '카카오', '', '71200'],
      ]);
      expect(p.rows, isEmpty);
      expect(p.skipCounts[SkipReason.badQuantity], 3);
    });

    test('유형을 못 정하면 unknownType', () {
      final p = _preview(header, [
        ['삼성전자', '삼성전자', '10', '71200'],
      ]);
      expect(p.rows, isEmpty);
      expect(p.skipCounts[SkipReason.unknownType], 1);
    });

    test('이미 보유한 종목은 alreadyHeld로 건너뛴다', () {
      final p = _preview(
        header,
        [
          ['005930', '삼성전자', '10', '71200'],
          ['000660', 'SK하이닉스', '3', '180000'],
        ],
        alreadyHeldKeys: {'005930|krStock'},
      );
      expect(p.rows.length, 1);
      expect(p.rows.single.symbol, '000660');
      expect(p.skipCounts[SkipReason.alreadyHeld], 1);
    });

    test('파일 안에 같은 종목이 두 줄이면 첫 줄만 통과하고 둘째는 duplicateInFile', () {
      final p = _preview(header, [
        ['005930', '삼성전자', '10', '71200'],
        ['005930', '삼성전자', '5', '68000'],
      ]);
      expect(p.rows.length, 1);
      expect(p.rows.single.quantity, 10);
      expect(p.skipCounts[SkipReason.duplicateInFile], 1);
    });

    test('forcedType이 있으면 파일 전체에 적용된다', () {
      final p = _preview(
        header,
        [
          ['005930', '삼성전자', '10', '71200'],
          ['QQQ', '나스닥100', '5', '500'],
        ],
        forcedType: AssetType.usStock,
      );
      expect(p.rows.length, 2);
      expect(p.rows.every((r) => r.assetType == AssetType.usStock), isTrue);
    });

    test('매수일 열이 있으면 줄마다 그 날짜를, 못 읽으면 fallbackDate를 쓴다', () {
      final p = _preview(
        ['종목코드', '수량', '매수일'],
        [
          ['005930', '10', '2025-03-04'],
          ['000660', '3', ''],
        ],
      );
      expect(p.rows[0].buyDate, DateTime(2025, 3, 4));
      expect(p.rows[1].buyDate, _fallback);
    });

    test('avgPrice가 없는 줄은 통과하되 avgPrice가 null이다', () {
      final p = _preview(header, [
        ['005930', '삼성전자', '10', ''],
      ]);
      expect(p.rows.length, 1);
      expect(p.rows.single.avgPrice, isNull);
    });

    test('종목명이 없으면 종목코드로 채운다', () {
      final p = _preview(header, [
        ['005930', '', '10', '71200'],
      ]);
      expect(p.rows.single.name, '005930');
    });

    test('열이 모자란 줄도 터지지 않는다', () {
      final p = _preview(header, [
        ['005930', '삼성전자'],
      ]);
      expect(p.rows, isEmpty);
      expect(p.skipCounts[SkipReason.badQuantity], 1);
    });

    test('매핑에 수량이 없으면 모든 줄이 badQuantity', () {
      final p = _preview(
        header,
        [
          ['005930', '삼성전자', '10', '71200'],
        ],
        mapping: const {ColumnRole.symbol: 0},
      );
      expect(p.rows, isEmpty);
      expect(p.skipCounts[SkipReason.badQuantity], 1);
    });

    test('현재가는 읽히지만 avgPrice와 별개다', () {
      final p = _preview(
        ['종목코드', '수량', '매입단가', '현재가'],
        [
          ['005930', '10', '71200', '80,000'],
        ],
      );
      expect(p.rows.single.avgPrice, 71200);
      expect(p.rows.single.currentPrice, 80000);
    });

    test('skipCounts는 사유가 없으면 그 키를 담지 않는다', () {
      final p = _preview(header, [
        ['005930', '삼성전자', '10', '71200'],
      ]);
      expect(p.skipCounts, isEmpty);
    });
  });
}
