import 'dart:math';

/// 포트폴리오 공유 코드.
///
/// Firestore도 Flutter도 모르는 순수 Dart다 — 생성 규칙만 담당한다.
///
/// 코드가 추측 가능하면 공유 문서가 그대로 열린다. 이전 구현은
/// `DateTime.now().millisecondsSinceEpoch`를 시드로 쓰는 선형 합동
/// 생성기여서, 공유 시각을 대략 알면 후보가 몇 천 개로 줄고 같은 밀리초에
/// 두 번 생성하면 같은 코드가 나왔다. 여기서는 [Random.secure]를 쓴다.
class ShareCode {
  ShareCode._();

  /// 코드에 쓰는 문자. 손으로 옮겨 적는 코드이므로 헷갈리는
  /// `I`/`1`, `O`/`0`은 뺀다.
  static const String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// 코드 길이. 32^6 ≈ 10억.
  static const int length = 6;

  static final Random _secure = Random.secure();

  /// 새 코드를 만든다. [random]은 테스트용 주입구다 — 생략하면
  /// 암호학적 난수를 쓴다.
  static String generate([Random? random]) {
    final rnd = random ?? _secure;
    final buf = StringBuffer();
    for (var i = 0; i < length; i++) {
      buf.write(chars[rnd.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  /// 입력 코드를 비교·조회에 쓸 형태로 맞춘다 (공백 제거 + 대문자).
  static String normalize(String input) => input.trim().toUpperCase();

  /// 사용자가 입력한 코드가 형식에 맞는지. 소문자는 대문자로 보고 받아들인다.
  static bool isValid(String input) {
    final code = normalize(input);
    if (code.length != length) return false;
    for (final ch in code.split('')) {
      if (!chars.contains(ch)) return false;
    }
    return true;
  }
}
