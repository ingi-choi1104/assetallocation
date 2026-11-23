import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assetallocation/core/utils/thousands_input_formatter.dart';

/// 사용자가 [text]를 끝까지 입력한 상태를 흉내낸다.
String typed(ThousandsInputFormatter f, String text) {
  var value = const TextEditingValue();
  for (int i = 0; i < text.length; i++) {
    final next = value.text + text[i];
    value = f.formatEditUpdate(
      value,
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      ),
    );
  }
  return value.text;
}

void main() {
  group('입력 중 쉼표', () {
    const decimal = ThousandsInputFormatter();
    const integer = ThousandsInputFormatter.integer();

    test('정수는 세 자릿수마다 끊는다', () {
      expect(typed(integer, '1000000'), '1,000,000');
      expect(typed(integer, '100'), '100');
      expect(typed(integer, '1234'), '1,234');
    });

    test('소수점은 그대로 두고 정수부만 끊는다', () {
      expect(typed(decimal, '1234.56'), '1,234.56');
      expect(typed(decimal, '10.5'), '10.5');
      expect(typed(decimal, '3.75'), '3.75');
    });

    test('정수 모드에서는 소수점을 받지 않는다', () {
      expect(typed(integer, '1000.50'), '100,050');
    });

    test('소수점은 하나만 남는다', () {
      expect(typed(decimal, '1.2.3'), '1.23');
    });

    test('점으로 시작하면 0을 붙인다', () {
      expect(typed(decimal, '.5'), '0.5');
    });

    test('선행 0은 지운다', () {
      expect(typed(integer, '007'), '7');
      expect(typed(decimal, '0.5'), '0.5');
    });

    test('숫자가 아닌 문자는 무시한다', () {
      expect(typed(integer, '1a2b3c'), '123');
    });

    test('소수 자릿수를 제한한다', () {
      const two = ThousandsInputFormatter(decimalRange: 2);
      expect(typed(two, '1.239'), '1.23');
    });

    test('모두 지우면 빈 값', () {
      final out = integer.formatEditUpdate(
        const TextEditingValue(text: '1,234'),
        const TextEditingValue(text: ''),
      );
      expect(out.text, '');
    });

    test('중간에 끼워 넣어도 커서가 끝으로 튀지 않는다', () {
      // '1,234'에서 '1' 뒤에 '9'를 넣어 '19,234'가 되는 상황.
      final out = integer.formatEditUpdate(
        const TextEditingValue(text: '1,234'),
        const TextEditingValue(
          text: '19,234',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(out.text, '19,234');
      // 숫자 두 개('1','9') 뒤 = 인덱스 2
      expect(out.selection.baseOffset, 2);
    });
  });

  group('parse', () {
    test('쉼표를 걷어내고 숫자로', () {
      expect(ThousandsInputFormatter.parse('1,000,000'), 1000000);
      expect(ThousandsInputFormatter.parse('1,234.56'), 1234.56);
      expect(ThousandsInputFormatter.parse('10.5'), 10.5);
    });

    test('빈 값이나 잘못된 값은 null', () {
      expect(ThousandsInputFormatter.parse(''), isNull);
      expect(ThousandsInputFormatter.parse(null), isNull);
      expect(ThousandsInputFormatter.parse('abc'), isNull);
    });
  });

  group('display', () {
    test('정수는 소수점 없이', () {
      expect(ThousandsInputFormatter.display(1000000), '1,000,000');
      expect(ThousandsInputFormatter.display(100), '100');
    });

    test('소수는 불필요한 0을 지운다', () {
      expect(ThousandsInputFormatter.display(10.5), '10.5');
      expect(ThousandsInputFormatter.display(3.75), '3.75');
      expect(ThousandsInputFormatter.display(1234.5), '1,234.5');
    });

    test('display → parse 왕복', () {
      for (final v in [1000000.0, 10.5, 3.75, 0.001, 1234.56]) {
        expect(
          ThousandsInputFormatter.parse(ThousandsInputFormatter.display(v)),
          closeTo(v, 1e-9),
        );
      }
    });
  });
}
