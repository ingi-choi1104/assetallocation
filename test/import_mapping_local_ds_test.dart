import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:assetallocation/data/datasources/local/import_mapping_local_ds.dart';
import 'package:assetallocation/domain/entities/import_table.dart';
import 'package:assetallocation/domain/services/column_matcher.dart';

void main() {
  late SharedPreferences prefs;
  late ImportMappingLocalDataSource ds;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    ds = ImportMappingLocalDataSource(prefs);
  });

  group('signatureOf', () {
    test('열 순서가 바뀌어도 같다', () {
      expect(
        ImportMappingLocalDataSource.signatureOf(['종목코드', '수량']),
        ImportMappingLocalDataSource.signatureOf(['수량', '종목코드']),
      );
    });

    test('공백·괄호·대소문자 차이를 무시한다', () {
      expect(
        ImportMappingLocalDataSource.signatureOf(['종목 코드', 'QTY']),
        ImportMappingLocalDataSource.signatureOf(['종목코드', 'qty']),
      );
    });

    test('열 구성이 다르면 다르다', () {
      expect(
        ImportMappingLocalDataSource.signatureOf(['종목코드', '수량']),
        isNot(ImportMappingLocalDataSource.signatureOf(['단축코드', '수량'])),
      );
    });

    test('열 개수가 다르면 다르다', () {
      expect(
        ImportMappingLocalDataSource.signatureOf(['종목코드', '수량']),
        isNot(ImportMappingLocalDataSource.signatureOf(['종목코드'])),
      );
    });

    test('빈 헤더도 서명이 나온다', () {
      expect(ImportMappingLocalDataSource.signatureOf([]), isNotEmpty);
    });
  });

  group('load / save', () {
    test('저장한 매핑을 같은 서명으로 되읽는다', () async {
      await ds.save('sig', {
        ColumnRole.symbol: '단축코드',
        ColumnRole.quantity: '보유수량',
      });

      expect(ds.load('sig'), {
        ColumnRole.symbol: '단축코드',
        ColumnRole.quantity: '보유수량',
      });
    });

    test('모르는 서명은 null', () {
      expect(ds.load('없음'), isNull);
    });

    test('같은 서명에 다시 저장하면 덮어쓴다', () async {
      await ds.save('sig', {ColumnRole.symbol: '종목코드'});
      await ds.save('sig', {ColumnRole.symbol: '단축코드'});

      expect(ds.load('sig'), {ColumnRole.symbol: '단축코드'});
    });

    test('서명이 여러 개 공존한다', () async {
      await ds.save('a', {ColumnRole.symbol: '종목코드'});
      await ds.save('b', {ColumnRole.symbol: '단축코드'});

      expect(ds.load('a'), {ColumnRole.symbol: '종목코드'});
      expect(ds.load('b'), {ColumnRole.symbol: '단축코드'});
    });

    test('빈 매핑을 저장하면 그 서명을 지운다', () async {
      await ds.save('sig', {ColumnRole.symbol: '종목코드'});
      await ds.save('sig', {});

      expect(ds.load('sig'), isNull);
    });

    test('모르는 역할 이름이 섞여 있으면 그것만 무시한다', () async {
      // 앱 버전이 내려가 저장된 역할이 사라진 경우.
      await prefs.setString(
        ImportMappingLocalDataSource.prefsKey,
        jsonEncode({
          'sig': {'symbol': '종목코드', 'wasEnde': '뭔가'},
        }),
      );

      expect(ds.load('sig'), {ColumnRole.symbol: '종목코드'});
    });

    test('깨진 JSON은 null로 떨어지고 던지지 않는다', () async {
      await prefs.setString(
          ImportMappingLocalDataSource.prefsKey, '{이건 JSON이 아니다');

      expect(ds.load('sig'), isNull);
    });

    test('깨진 JSON 위에 저장하면 복구된다', () async {
      await prefs.setString(ImportMappingLocalDataSource.prefsKey, 'xxx');
      await ds.save('sig', {ColumnRole.symbol: '종목코드'});

      expect(ds.load('sig'), {ColumnRole.symbol: '종목코드'});
    });
  });

  group('기억된 매핑이 실제 파일에 적용된다', () {
    test('저장 → signatureOf → resolveMapping 왕복', () async {
      const header = ['수량', '결제수량', '종목코드'];
      final signature = ImportMappingLocalDataSource.signatureOf(header);

      await ds.save(signature, {ColumnRole.quantity: '결제수량'});

      final mapping = ColumnMatcher.resolveMapping(
        header: header,
        remembered: ds.load(signature),
      );

      expect(mapping[ColumnRole.quantity], 1);
      expect(mapping[ColumnRole.symbol], 2);
    });
  });
}
