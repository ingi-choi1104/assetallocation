// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assetallocation/data/datasources/local/table_file_parser.dart';
import 'package:assetallocation/domain/entities/import_table.dart';
import 'package:assetallocation/domain/services/column_matcher.dart';

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List _xlsx(Map<String, List<List<String>>> sheets) {
  final book = Excel.createExcel();
  sheets.forEach((name, rows) {
    final sheet = book[name];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
          TextCellValue(rows[r][c]),
        );
      }
    }
  });
  book.delete('Sheet1');
  return Uint8List.fromList(book.encode()!);
}

void main() {
  group('decodeCsv', () {
    // charset 패키지의 **인코더**는 일부 한글을 버린다('종목명' → '목명').
    // 그래서 고정 바이트로 테스트한다 — Windows CP949(51949)로 뽑은
    // '종목명\n삼성전자\n'의 권위 있는 바이트열이다. 우리는 디코드만 하므로
    // 인코더 버그는 앱에 영향이 없지만, 디코더가 멀쩡한지는 확인해야 한다.
    final eucKrBytes = Uint8List.fromList([
      0xC1, 0xBE, 0xB8, 0xF1, 0xB8, 0xED, 0x0A, // 종목명\n
      0xBB, 0xEF, 0xBC, 0xBA, 0xC0, 0xFC, 0xC0, 0xDA, 0x0A, // 삼성전자\n
    ]);

    test('EUC-KR 한글이 깨지지 않는다', () {
      expect(TableFileParser.decodeCsv(eucKrBytes), '종목명\n삼성전자\n');
    });

    test('EUC-KR 파일이 표로 읽힌다', () {
      final table = TableFileParser.parse(eucKrBytes, 'a.csv');
      expect(table.header, ['종목명']);
      expect(table.rows.single, ['삼성전자']);
    });

    // 생성된 변환표(euc_kr_table.g.dart)가 맞는지 넓게 확인한다.
    // 아래 바이트열은 Windows CP949(51949)로 뽑은 권위 있는 값이다.
    test('CP949로 저장된 실제 증권사 CSV가 그대로 읽힌다', () {
      final bytes = Uint8List.fromList([
        0xC1, 0xBE, 0xB8, 0xF1, 0xC4, 0xDA, 0xB5, 0xE5, 0x2C, 0xC1, 0xBE,
        0xB8, 0xF1, 0xB8, 0xED, 0x2C, 0xBA, 0xB8, 0xC0, 0xAF, 0xBC, 0xF6,
        0xB7, 0xAE, 0x2C, 0xB8, 0xC5, 0xC0, 0xD4, 0xB4, 0xDC, 0xB0, 0xA1,
        0x0D, 0x0A, 0x30, 0x30, 0x35, 0x39, 0x33, 0x30, 0x2C, 0xBB, 0xEF,
        0xBC, 0xBA, 0xC0, 0xFC, 0xC0, 0xDA, 0x2C, 0x31, 0x30, 0x2C, 0x37,
        0x31, 0x32, 0x30, 0x30, 0x0D, 0x0A, 0x30, 0x36, 0x39, 0x35, 0x30,
        0x30, 0x2C, 0x4B, 0x4F, 0x44, 0x45, 0x58, 0x20, 0x32, 0x30, 0x30,
        0x2C, 0x35, 0x2C, 0x33, 0x38, 0x31, 0x35, 0x30, 0x0D, 0x0A, 0x33,
        0x35, 0x37, 0x38, 0x37, 0x30, 0x2C, 0x54, 0x49, 0x47, 0x45, 0x52,
        0x20, 0x43, 0x44, 0xB1, 0xDD, 0xB8, 0xAE, 0xC5, 0xF5, 0xC0, 0xDA,
        0x4B, 0x49, 0x53, 0x28, 0xC7, 0xD5, 0xBC, 0xBA, 0x29, 0x2C, 0x33,
        0x2C, 0x35, 0x34, 0x33, 0x32, 0x30, 0x0D, 0x0A, 0x30, 0x30, 0x33,
        0x35, 0x35, 0x30, 0x2C, 0x4C, 0x47, 0x2C, 0x37, 0x2C, 0x38, 0x32,
        0x30, 0x30, 0x30, 0x0D, 0x0A,
      ]);

      final table = TableFileParser.parse(bytes, '잔고.csv');
      expect(table.header, ['종목코드', '종목명', '보유수량', '매입단가']);
      expect(table.rows, [
        ['005930', '삼성전자', '10', '71200'],
        ['069500', 'KODEX 200', '5', '38150'],
        ['357870', 'TIGER CD금리투자KIS(합성)', '3', '54320'],
        ['003550', 'LG', '7', '82000'],
      ]);
    });

    test('잘못된 바이트는 예외 대신 U+FFFD로 바뀐다', () {
      // 0xFF는 CP949에서 선행바이트가 될 수 없다.
      final text = TableFileParser.decodeCsv(Uint8List.fromList([0xFF, 0x41]));
      expect(text, '�A');
    });

    test('UTF-8 한글도 그대로 읽는다', () {
      expect(
        TableFileParser.decodeCsv(_utf8('종목명\n삼성전자\n')),
        contains('삼성전자'),
      );
    });

    test('UTF-8 BOM을 제거한다', () {
      final bytes = Uint8List.fromList(
          [0xEF, 0xBB, 0xBF, ...utf8.encode('종목코드,수량\n')]);
      expect(TableFileParser.decodeCsv(bytes).startsWith('종목코드'), isTrue);
    });

    test('BOM 있는 파일의 첫 열이 symbol로 매핑된다', () {
      final bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('종목코드,수량\n005930,10\n'),
      ]);
      final table = TableFileParser.parse(bytes, 'a.csv');
      expect(ColumnMatcher.guessMapping(table.header)[ColumnRole.symbol], 0);
    });
  });

  group('isXlsx', () {
    test('ZIP 매직바이트로 판별한다', () {
      expect(
        TableFileParser.isXlsx(Uint8List.fromList([0x50, 0x4B, 0x03, 0x04])),
        isTrue,
      );
      expect(TableFileParser.isXlsx(_utf8('a,b\n')), isFalse);
      expect(TableFileParser.isXlsx(Uint8List(0)), isFalse);
    });

    test('확장자가 .csv여도 내용이 xlsx면 xlsx로 읽는다', () {
      final bytes = _xlsx({
        '잔고': [
          ['종목코드', '수량'],
          ['005930', '10'],
        ],
      });
      final table = TableFileParser.parse(bytes, 'mislabeled.csv');
      expect(table.header, ['종목코드', '수량']);
    });
  });

  group('parse — csv', () {
    test('구분자를 자동으로 고른다 (쉼표·탭·세미콜론)', () {
      for (final d in [',', '\t', ';']) {
        // `$d10`은 식별자 d10으로 읽히므로 중괄호가 꼭 필요하다.
        final table = TableFileParser.parse(
          _utf8('종목코드${d}수량\n005930${d}10\n'),
          'a.csv',
        );
        expect(table.header, ['종목코드', '수량'], reason: 'delimiter: $d');
        expect(table.rows.single, ['005930', '10'], reason: 'delimiter: $d');
      }
    });

    test('CRLF 줄바꿈도 읽는다', () {
      final table =
          TableFileParser.parse(_utf8('종목코드,수량\r\n005930,10\r\n'), 'a.csv');
      expect(table.header, ['종목코드', '수량']);
      expect(table.rows.single, ['005930', '10']);
    });

    test('헤더 위 쓰레기 행을 잘라낸다', () {
      final table = TableFileParser.parse(
        _utf8('삼성증권 잔고조회\n계좌번호,123-45\n\n종목코드,수량\n005930,10\n'),
        'a.csv',
      );
      expect(table.header, ['종목코드', '수량']);
      expect(table.rows.length, 1);
    });

    test('헤더만 있고 데이터가 없으면 rows가 비고 예외가 아니다', () {
      expect(TableFileParser.parse(_utf8('종목코드,수량\n'), 'a.csv').rows, isEmpty);
    });

    test('완전히 빈 파일은 TableParseException', () {
      expect(
        () => TableFileParser.parse(Uint8List(0), 'a.csv'),
        throwsA(isA<TableParseException>()),
      );
    });

    test('공백만 있는 파일도 TableParseException', () {
      expect(
        () => TableFileParser.parse(_utf8('\n\n   \n'), 'a.csv'),
        throwsA(isA<TableParseException>()),
      );
    });

    test('열 개수가 헤더보다 적은 줄은 빈 문자열로 채운다', () {
      final table = TableFileParser.parse(
        _utf8('종목코드,종목명,수량\n005930,삼성전자\n'),
        'a.csv',
      );
      expect(table.rows.single, ['005930', '삼성전자', '']);
    });

    test('열이 헤더보다 많은 줄은 잘라낸다', () {
      final table = TableFileParser.parse(
        _utf8('종목코드,수량\n005930,10,군더더기\n'),
        'a.csv',
      );
      expect(table.rows.single, ['005930', '10']);
    });

    test('따옴표 안의 쉼표를 열 구분으로 보지 않는다', () {
      final table = TableFileParser.parse(
        _utf8('종목코드,종목명,수량\n005930,"삼성전자, 우선주",10\n'),
        'a.csv',
      );
      expect(table.rows.single[1], '삼성전자, 우선주');
    });

    test('빈 줄은 건너뛴다', () {
      final table = TableFileParser.parse(
        _utf8('종목코드,수량\n005930,10\n\n000660,3\n'),
        'a.csv',
      );
      expect(table.rows.length, 2);
    });

    test('sheetName은 CSV에서 파일명이다', () {
      expect(
        TableFileParser.parse(_utf8('종목코드,수량\n005930,10\n'), '잔고.csv')
            .sheetName,
        '잔고.csv',
      );
    });
  });

  group('parse — xlsx', () {
    test('시트가 여러 개면 헤더 점수가 가장 높은 시트를 쓴다', () {
      final bytes = _xlsx({
        '설명': [
          ['이 파일은 잔고 조회 결과입니다'],
          ['문의: 1588-0000'],
        ],
        '잔고': [
          ['종목코드', '종목명', '보유수량', '매입단가'],
          ['005930', '삼성전자', '10', '71200'],
        ],
      });

      final table = TableFileParser.parse(bytes, 'b.xlsx');
      expect(table.sheetName, '잔고');
      expect(table.header, ['종목코드', '종목명', '보유수량', '매입단가']);
      expect(table.rows.single, ['005930', '삼성전자', '10', '71200']);
    });

    test('숫자 셀을 문자열로 읽는다', () {
      final book = Excel.createExcel();
      final sheet = book['잔고'];
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          TextCellValue('종목코드'));
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0),
          TextCellValue('수량'));
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
          IntCellValue(5930));
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1),
          IntCellValue(10));
      book.delete('Sheet1');

      final table = TableFileParser.parse(
          Uint8List.fromList(book.encode()!), 'b.xlsx');
      expect(table.rows.single, ['5930', '10']);
    });

    test('날짜 셀을 yyyy-MM-dd로 읽는다', () {
      final book = Excel.createExcel();
      final sheet = book['잔고'];
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          TextCellValue('매수일'));
      sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
          DateCellValue(year: 2025, month: 3, day: 4));
      book.delete('Sheet1');

      final table = TableFileParser.parse(
          Uint8List.fromList(book.encode()!), 'b.xlsx');
      expect(ColumnMatcher.parseDate(table.rows.single.single),
          DateTime(2025, 3, 4));
    });

    test('시트가 모두 비면 TableParseException', () {
      final bytes = _xlsx({'빈시트': []});
      expect(
        () => TableFileParser.parse(bytes, 'b.xlsx'),
        throwsA(isA<TableParseException>()),
      );
    });
  });
}
