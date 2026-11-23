import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:assetallocation/services/share_code.dart';

/// 공유 코드는 **추측 불가능해야** 한다.
///
/// 이전 생성기는 `DateTime.now().millisecondsSinceEpoch`를 시드로 쓰는 선형
/// 합동 생성기였다. 공유 시각을 대략 알면 후보가 몇 천 개로 줄고, 같은
/// 밀리초에 두 번 생성하면 **같은 코드**가 나와 한쪽 공유가 조용히 덮어써졌다.
void main() {
  group('ShareCode.generate', () {
    test('6자리다', () {
      for (var i = 0; i < 50; i++) {
        expect(ShareCode.generate().length, 6);
      }
    });

    test('허용 문자만 쓴다', () {
      for (var i = 0; i < 200; i++) {
        for (final ch in ShareCode.generate().split('')) {
          expect(ShareCode.chars.contains(ch), isTrue,
              reason: '$ch 는 허용 문자가 아니다');
        }
      }
    });

    test('헷갈리는 문자(I, O, 0, 1)는 쓰지 않는다', () {
      // 사용자가 코드를 받아 손으로 입력한다. O/0, I/1 구분은 실패한다.
      for (final ch in ['I', 'O', '0', '1']) {
        expect(ShareCode.chars.contains(ch), isFalse, reason: '$ch 가 포함됨');
      }
    });

    test('같은 밀리초에 연속 생성해도 서로 다르다', () {
      // 시간 시드 생성기였다면 여기서 같은 코드가 나온다 — 그게 이 테스트의 핵심.
      final codes = <String>{};
      for (var i = 0; i < 100; i++) {
        codes.add(ShareCode.generate());
      }
      expect(codes.length, 100, reason: '100개 중 중복이 있다');
    });

    test('2000개를 뽑아도 중복이 거의 없다', () {
      final codes = <String>{};
      for (var i = 0; i < 2000; i++) {
        codes.add(ShareCode.generate());
      }
      // 32^6 ≈ 10억. 2000개에서 중복이 나오면 생성기가 고장난 것이다.
      expect(codes.length, 2000);
    });

    test('Random을 주입하면 결정적이다', () {
      // 충돌 재시도 로직을 테스트할 수 있도록 주입을 허용한다.
      final a = ShareCode.generate(Random(42));
      final b = ShareCode.generate(Random(42));
      expect(a, b);
      expect(a.length, 6);
    });

    test('문자 분포가 한쪽으로 쏠리지 않는다', () {
      // 모듈로 편향이나 상수 반환을 잡는다.
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        seen.addAll(ShareCode.generate().split(''));
      }
      expect(seen.length, greaterThan(ShareCode.chars.length ~/ 2),
          reason: '쓰이는 문자가 너무 적다: ${seen.length}종');
    });
  });

  group('ShareCode.isValid', () {
    test('생성된 코드는 유효하다', () {
      for (var i = 0; i < 100; i++) {
        expect(ShareCode.isValid(ShareCode.generate()), isTrue);
      }
    });

    test('길이가 6이 아니면 무효', () {
      expect(ShareCode.isValid(''), isFalse);
      expect(ShareCode.isValid('ABCDE'), isFalse);
      expect(ShareCode.isValid('ABCDEFG'), isFalse);
    });

    test('허용되지 않은 문자가 있으면 무효', () {
      expect(ShareCode.isValid('ABCDE0'), isFalse, reason: '0은 쓰지 않는다');
      expect(ShareCode.isValid('ABCDEI'), isFalse, reason: 'I는 쓰지 않는다');
      expect(ShareCode.isValid('ABCD-F'), isFalse);
      expect(ShareCode.isValid('ABCD F'), isFalse);
      expect(ShareCode.isValid('가나다라마바'), isFalse);
    });

    test('소문자는 대문자로 보고 받아들인다', () {
      // 링크를 소문자로 옮겨 적는 사용자가 있다.
      expect(ShareCode.isValid('abcdef'), isTrue);
      expect(ShareCode.normalize('abcdef'), 'ABCDEF');
      expect(ShareCode.normalize('  abcdef  '), 'ABCDEF');
    });
  });
}
