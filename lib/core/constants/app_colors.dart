import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Sophisticated forest green palette
  static const Color primary      = Color(0xFF1A5C38); // deep forest green
  static const Color primaryLight = Color(0xFF4CAF50); // medium green
  static const Color primaryDark  = Color(0xFF0D3D22); // very dark green

  static const Color secondary      = Color(0xFF4A7C59); // sage green
  static const Color secondaryLight = Color(0xFF7DAE8A);
  static const Color secondaryDark  = Color(0xFF1F4D32);

  static const Color surface    = Color(0xFFF6FBF7); // cool white with green tint
  static const Color background = Color(0xFFEDF4EF); // soft green-grey
  static const Color error      = Color(0xFFB71C1C);

  static const Color positive = Color(0xFF1B6B3A);
  static const Color negative = Color(0xFFC62828);
  static const Color neutral  = Color(0xFF4A5E52); // green-grey neutral

  // 상승/하락 — 한국 증시 관례로 통일한다: 상승 빨강, 하락 파랑.
  //
  // positive/negative와 쓰임이 다르다. up/down은 **값의 방향**(수익률, 일간
  // 변동, 지수 변동, 모멘텀)에만 쓰고, positive/negative는 방향이 아닌
  // 상태·역할·파괴적 동작(공격/방어 자산, 삭제 버튼 등)에 남겨둔다.
  // 둘을 섞으면 같은 초록이 어떤 화면에서는 '상승', 다른 화면에서는
  // '선택됨'을 뜻하게 된다 — 이 통일 작업 전의 상태가 정확히 그랬다.
  static const Color up   = Color(0xFFC62828); // 상승
  static const Color down = Color(0xFF1565C0); // 하락
  static const Color flat = Color(0xFF9E9E9E); // 변동 없음

  /// 변동값에 쓸 색. null이거나 0이면 [flat].
  ///
  /// 화면마다 `x > 0 ? ... : ...` 삼항을 다시 쓰면 한쪽만 고쳐지는 일이
  /// 생긴다(실제로 생겼다). 방향 색은 전부 이 함수를 지난다.
  static Color forChange(num? value) {
    if (value == null || value == 0) return flat;
    return value > 0 ? up : down;
  }

  // Chart colors — distinct, clean
  static const List<Color> chartColors = [
    Color(0xFF1A5C38), // forest green (primary)
    Color(0xFF1565C0), // blue
    Color(0xFFEF6C00), // orange
    Color(0xFF6A1B9A), // purple
    Color(0xFFAD1457), // pink
    Color(0xFF00838F), // teal
    Color(0xFFF9A825), // amber
    Color(0xFFC62828), // red
  ];
}
