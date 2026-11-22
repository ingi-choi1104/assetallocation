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

    test('지수 표기를 숫자 조각으로 이어붙이지 않는다', () {
      // 엑셀이 큰 수를 E 표기로 내보낸다. 글자만 걷어내면 1.2E+5가 1.25가 된다.
      expect(ColumnMatcher.parseNumber('1.2E+5'), isNull);
      expect(ColumnMatcher.parseNumber('5.93E+03'), isNull);
    });

    test('숫자가 두 덩어리면 null', () {
      // '10주 (5)'를 105로 읽으면 수량이 조용히 틀린다.
      expect(ColumnMatcher.parseNumber('10주 (5)'), isNull);
      expect(ColumnMatcher.parseNumber('1 234'), isNull);
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

    test('두 자리 연도를 올해 이전으로 펼친다', () {
      // 키움 등이 쓰는 YY.MM.DD. 그냥 받으면 서기 25년이 되어 보유기간이
      // 2000년으로 계산된다.
      expect(ColumnMatcher.parseDate('25.03.04'), DateTime(2025, 3, 4));
      expect(ColumnMatcher.parseDate('99.12.31'), DateTime(1999, 12, 31));
      expect(ColumnMatcher.parseDate('26-01-02'), DateTime(2026, 1, 2));
    });

    test('말이 안 되는 연도는 null', () {
      expect(ColumnMatcher.parseDate('1800-01-02'), isNull);
      expect(ColumnMatcher.parseDate('2300-01-02'), isNull);
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

    test('포함관계는 더 긴 후보가 이긴다 — 짧은 후보가 선점하지 않는다', () {
      // symbol 후보 '코드'가 '국가코드'를 집어가면 종목코드 열이 사라진다.
      final m = ColumnMatcher.guessMapping(['국가코드', '종목명', '보유수량']);
      expect(m[ColumnRole.symbol], isNull);
      expect(m[ColumnRole.name], 1);
      expect(m[ColumnRole.quantity], 2);
    });

    test('name 후보 종목이 수량 열을 가로채지 않는다', () {
      final m = ColumnMatcher.guessMapping(['종목코드', '보유종목수량']);
      expect(m[ColumnRole.symbol], 0);
      expect(m[ColumnRole.quantity], 1);
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

    test('마지막 자리가 영문인 한국 코드도 한국으로 본다', () {
      // 우선주·신주인수권: 00088K, 01I390 같은 코드가 실재한다.
      expect(ColumnMatcher.inferType('00088K'), AssetType.krStock);
    });

    test('한 글자 티커도 미국으로 본다', () {
      // F(포드), GM, BP는 실재한다. '국가코드' 열이 symbol로 잘못 잡히는
      // 문제는 여기서 막지 않고 guessMapping에서 막는다.
      expect(ColumnMatcher.inferType('F'), AssetType.usStock);
      expect(ColumnMatcher.inferType('GM'), AssetType.usStock);
    });
  });

  group('matchesType', () {
    test('한국 유형은 6자리 코드만 받는다', () {
      expect(ColumnMatcher.matchesType('005930', AssetType.krStock), isTrue);
      expect(ColumnMatcher.matchesType('00088K', AssetType.krStock), isTrue);
      expect(ColumnMatcher.matchesType('삼성전자', AssetType.krStock), isFalse);
      expect(ColumnMatcher.matchesType('QQQ', AssetType.krStock), isFalse);
    });

    test('미국 유형은 영문 티커만 받는다', () {
      expect(ColumnMatcher.matchesType('QQQ', AssetType.usStock), isTrue);
      expect(ColumnMatcher.matchesType('BRK.B', AssetType.usStock), isTrue);
      expect(ColumnMatcher.matchesType('005930', AssetType.usStock), isFalse);
      expect(ColumnMatcher.matchesType('삼성전자', AssetType.usStock), isFalse);
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
          ['QQQ', '나스닥100', '5', '500'],
          ['SPY', 'S&P500', '2', '600'],
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

    test('엑셀이 숫자로 저장해 앞의 0이 날아간 종목코드를 6자리로 되살린다', () {
      final p = _preview(header, [
        ['5930', '삼성전자', '10', '71200'],
        ['660', 'SK하이닉스', '3', '180000'],
      ]);
      expect(p.rows.map((r) => r.symbol), ['005930', '000660']);
      expect(p.rows.every((r) => r.assetType == AssetType.krStock), isTrue);
    });

    test('유형을 미국으로 골랐으면 숫자 코드를 한국식으로 채워 넣지 않는다', () {
      // 0을 채워 005930(삼성전자)으로 만들어 버리면 남의 종목이 된다.
      final p = _preview(
        header,
        [
          ['5930', '뭔가', '10', '100'],
        ],
        forcedType: AssetType.usStock,
      );
      expect(p.rows, isEmpty);
      expect(p.skipCounts[SkipReason.invalidSymbol], 1);
    });

    test('6자리를 넘는 숫자는 채우지 않는다', () {
      final p = _preview(header, [
        ['1234567', '뭔가', '10', '100'],
      ]);
      expect(p.rows, isEmpty);
      expect(p.skipCounts[SkipReason.unknownType], 1);
    });

    test('유형을 직접 골라도 종목코드 형식은 검사한다', () {
      // 매핑이 틀려 '유형 판단 불가'가 쏟아지면 사용자는 유형을 직접 고르게
      // 된다. 그때 검사가 없으면 한글 이름이 symbol인 자산이 등록되고
      // 평가액이 영영 0으로 남는다.
      final p = _preview(
        header,
        [
          ['삼성전자', '삼성전자', '10', '71200'],
          ['005930', '삼성전자', '10', '71200'],
        ],
        forcedType: AssetType.krStock,
      );
      expect(p.rows.length, 1);
      expect(p.rows.single.symbol, '005930');
      expect(p.skipCounts[SkipReason.invalidSymbol], 1);
    });

    test('미국으로 골랐는데 6자리 숫자면 건너뛴다', () {
      final p = _preview(
        header,
        [
          ['005930', '삼성전자', '10', '71200'],
        ],
        forcedType: AssetType.usStock,
      );
      expect(p.rows, isEmpty);
      expect(p.skipCounts[SkipReason.invalidSymbol], 1);
    });

    test('미래 날짜는 취득일로 대체한다', () {
      final p = _preview(
        ['종목코드', '수량', '매수일'],
        [
          ['005930', '10', '2099-01-02'],
        ],
      );
      expect(p.rows.single.buyDate, _fallback);
    });

    test('미국 티커는 대문자로 맞춘다', () {
      final p = _preview(header, [
        ['aapl', '애플', '3', '200'],
      ]);
      expect(p.rows.single.symbol, 'AAPL');
      expect(p.rows.single.assetType, AssetType.usStock);
    });

    test('skipCounts는 사유가 없으면 그 키를 담지 않는다', () {
      final p = _preview(header, [
        ['005930', '삼성전자', '10', '71200'],
      ]);
      expect(p.skipCounts, isEmpty);
    });
  });
}
