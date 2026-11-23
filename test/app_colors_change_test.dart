import 'package:flutter_test/flutter_test.dart';

import 'package:assetallocation/core/constants/app_colors.dart';

/// 상승/하락 색은 한국 증시 관례로 통일한다 — 상승 빨강, 하락 파랑.
///
/// 이 테스트가 지키는 것은 "어느 쪽이 빨강인가"다. 화면마다 삼항을 다시 쓰던
/// 탓에 같은 수익률이 화면에 따라 초록/빨강/파랑으로 나왔고, 그걸 한 함수로
/// 모은 뒤의 회귀를 막는다.
void main() {
  group('AppColors.forChange', () {
    test('상승은 빨간색', () {
      expect(AppColors.forChange(1), AppColors.up);
      expect(AppColors.forChange(0.0001), AppColors.up);
      expect(AppColors.forChange(1234.5), AppColors.up);
    });

    test('하락은 파란색', () {
      expect(AppColors.forChange(-1), AppColors.down);
      expect(AppColors.forChange(-0.0001), AppColors.down);
      expect(AppColors.forChange(-1234.5), AppColors.down);
    });

    test('변동 없음과 null은 회색', () {
      expect(AppColors.forChange(0), AppColors.flat);
      expect(AppColors.forChange(0.0), AppColors.flat);
      expect(AppColors.forChange(-0.0), AppColors.flat);
      expect(AppColors.forChange(null), AppColors.flat);
    });

    test('상승은 빨강, 하락은 파랑 — 초록은 방향에 쓰지 않는다', () {
      // 통일 전에는 수익률이 초록(positive)이었다. 방향 색에 초록이 다시
      // 끼어들면 이 테스트가 잡는다.
      expect(AppColors.up, isNot(AppColors.positive));
      expect(AppColors.down, isNot(AppColors.positive));
      expect(AppColors.forChange(1), isNot(AppColors.positive));
      expect(AppColors.forChange(-1), isNot(AppColors.positive));
    });

    test('상승과 하락은 서로 다른 색', () {
      expect(AppColors.up, isNot(AppColors.down));
      expect(AppColors.up, isNot(AppColors.flat));
      expect(AppColors.down, isNot(AppColors.flat));
    });
  });
}
