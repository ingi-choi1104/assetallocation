import 'euc_kr_table.g.dart';

/// EUC-KR / CP949 디코더.
///
/// 한국 윈도우 엑셀은 CSV를 CP949로 저장한다. `dart:convert`에는 EUC-KR
/// 코덱이 없다.
///
/// `charset 2.0.1`을 쓰려 했지만 그 패키지는 두 변환표의 이름이 뒤바뀐 채
/// 인코더·디코더가 **반대 표**를 참조해서, '종목명'이 '馲辦辣'로 나온다
/// (데이터는 맞고 코드가 틀렸다). 그래서 Windows CP949에서 직접 뽑은 표
/// ([eucKrLeadTable], 16,910개 매핑)로 디코딩한다. 의존성이 없고
/// `flutter test`에서 그대로 검증된다.
///
/// 디코딩만 한다 — 앱이 EUC-KR로 **쓸** 일은 없다.
class EucKr {
  EucKr._();

  static const int _replacement = 0xFFFD;

  /// 잘못된 바이트는 예외 대신 U+FFFD로 바꾼다. 가져오기 화면에서는
  /// 파일 하나가 통째로 실패하는 것보다 깨진 글자를 보여 주고 사용자가
  /// 인코딩을 바꿔 저장하도록 하는 편이 낫다.
  static String decode(List<int> bytes) {
    final sb = StringBuffer();

    for (var i = 0; i < bytes.length; i++) {
      final lead = bytes[i];

      if (lead < 0x80) {
        sb.writeCharCode(lead);
        continue;
      }

      if (lead >= 0x81 && lead <= 0xFE && i + 1 < bytes.length) {
        final trail = bytes[i + 1];
        if (trail >= 0x41 && trail <= 0xFE) {
          sb.write(eucKrLeadTable[lead - 0x81][trail - 0x41]);
          i++;
          continue;
        }
      }

      sb.writeCharCode(_replacement);
    }

    return sb.toString();
  }
}
