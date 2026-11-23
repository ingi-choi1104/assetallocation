import 'package:flutter/services.dart';

/// 입력하는 동안 정수부에 세 자릿수마다 쉼표를 넣는다.
///
/// 소수점을 허용하므로 수량(10.5주, 금 3.75g)과 금액(1,000,000원)에 모두 쓸 수
/// 있다. 저장할 때는 [parse]로 쉼표를 걷어낸 값을 쓴다.
class ThousandsInputFormatter extends TextInputFormatter {
  /// 소수점 이하 최대 자릿수.
  final int decimalRange;

  const ThousandsInputFormatter({this.decimalRange = 8});

  /// 정수만 받는 금액 입력용.
  const ThousandsInputFormatter.integer() : decimalRange = 0;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final allowed = decimalRange > 0 ? RegExp(r'[^0-9.]') : RegExp(r'[^0-9]');
    var raw = newValue.text.replaceAll(allowed, '');

    // 소수점은 하나만 남긴다.
    if (decimalRange > 0) {
      final first = raw.indexOf('.');
      if (first != -1) {
        raw = raw.substring(0, first + 1) +
            raw.substring(first + 1).replaceAll('.', '');
      }
    }
    if (raw.isEmpty) return const TextEditingValue();

    // '.'로 시작하면 '0.'으로 보정한다.
    if (raw.startsWith('.')) raw = '0$raw';

    var intPart = raw;
    var decimalPart = '';
    final dot = raw.indexOf('.');
    if (dot != -1) {
      intPart = raw.substring(0, dot);
      decimalPart = raw.substring(dot + 1);
      if (decimalPart.length > decimalRange) {
        decimalPart = decimalPart.substring(0, decimalRange);
      }
    }

    // 선행 0 제거 ('007' → '7'), 단 '0' 하나는 남긴다.
    intPart = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (intPart.isEmpty) intPart = '0';

    final formatted = dot != -1
        ? '${_group(intPart)}.$decimalPart'
        : _group(intPart);

    // 커서 앞의 '숫자 개수'를 유지해 편집 중 커서가 끝으로 튀지 않게 한다.
    final digitsBeforeCaret = newValue.text
        .substring(0, newValue.selection.end.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .length;
    var seen = 0;
    var caret = formatted.length;
    for (int i = 0; i < formatted.length; i++) {
      if (formatted[i] != ',') seen++;
      if (seen == digitsBeforeCaret) {
        caret = i + 1;
        break;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  static String _group(String digits) {
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  /// 쉼표가 섞인 입력을 숫자로. 비었거나 숫자가 아니면 null.
  static double? parse(String? text) {
    if (text == null) return null;
    final cleaned = text.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// 기존 값을 입력란에 채울 때 쓰는 표시 문자열.
  /// 정수면 소수점을 붙이지 않고, 아니면 불필요한 0을 지운다.
  static String display(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return _group(value.toInt().toString());
    }
    var s = value.toStringAsFixed(8);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    final dot = s.indexOf('.');
    if (dot == -1) return _group(s);
    return '${_group(s.substring(0, dot))}.${s.substring(dot + 1)}';
  }
}
