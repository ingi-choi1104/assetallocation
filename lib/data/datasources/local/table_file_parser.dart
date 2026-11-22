import 'dart:convert';
import 'dart:typed_data';

import '../../../core/utils/euc_kr.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../../../domain/entities/import_table.dart';
import '../../../domain/services/column_matcher.dart';

/// 파일을 표로 읽지 못했을 때. [message]는 사용자에게 그대로 보여줄 문구다.
class TableParseException implements Exception {
  final String message;
  const TableParseException(this.message);

  @override
  String toString() => message;
}

/// 파일 바이트를 [ImportTable]로 읽는다.
///
/// 파일 **선택**은 하지 않는다 — 화면이 `file_picker`로 바이트를 받아 넘긴다.
/// 덕분에 이 클래스는 순수 Dart이고 `flutter test`에서 전부 검증된다.
class TableFileParser {
  TableFileParser._();

  /// 읽을 수 있는 포맷인지 **확장자가 아니라 내용으로** 판별한 뒤 읽는다.
  /// 안드로이드 `file_picker`가 확장자 없는 이름을 줄 수 있다.
  static ImportTable parse(Uint8List bytes, String fileName) {
    if (bytes.isEmpty) {
      throw const TableParseException('파일이 비어 있습니다.');
    }
    if (_isLegacyXls(bytes)) {
      throw const TableParseException(
        '구형 엑셀(.xls) 파일입니다. 엑셀에서 열어 .xlsx로 저장한 뒤 다시 시도해 주세요.',
      );
    }
    if (_isUtf16(bytes)) {
      throw const TableParseException(
        'UTF-16으로 저장된 파일입니다. 엑셀에서 CSV(UTF-8) 또는 .xlsx로 저장한 뒤 다시 시도해 주세요.',
      );
    }
    if (isXlsx(bytes)) return _parseXlsx(bytes);
    return _parseCsv(bytes, fileName);
  }

  /// UTF-16 BOM(`FF FE` / `FE FF`). 그냥 두면 CP949 표로 억지로 읽혀
  /// 전부 깨진 글자가 되고, 모든 줄이 "종목코드 없음"으로 버려진다.
  static bool _isUtf16(Uint8List bytes) =>
      bytes.length >= 2 &&
      ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
          (bytes[0] == 0xFE && bytes[1] == 0xFF));

  /// `.xlsx`는 ZIP 컨테이너다 — 매직바이트 `PK`로 가린다.
  static bool isXlsx(Uint8List bytes) =>
      bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;

  /// 구형 `.xls`는 OLE2 복합 문서(`D0 CF 11 E0`)다.
  static bool _isLegacyXls(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0xD0 &&
      bytes[1] == 0xCF &&
      bytes[2] == 0x11 &&
      bytes[3] == 0xE0;

  /// UTF-8을 엄격 모드로 먼저 시도하고, 실패하면 EUC-KR로 읽는다.
  /// EUC-KR과 CP949는 같은 표로 덮는다 ([EucKr] 참조).
  ///
  /// 한국 엑셀이 CSV로 내보내면 맨 앞에 UTF-8 BOM이 붙어 첫 열 이름이
  /// `'﻿종목코드'`가 된다 — 사전에 안 걸려 첫 열이 통째로 날아가므로
  /// 지운다.
  static String decodeCsv(Uint8List bytes) {
    String text;
    try {
      text = const Utf8Decoder(allowMalformed: false).convert(bytes);
    } on FormatException {
      text = EucKr.decode(bytes);
    }
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    return text;
  }

  // ── CSV ────────────────────────────────────────────────────────────────────

  /// 구분자는 `csv` 패키지의 자동 탐지에 맡긴다 — 쉼표·세미콜론·탭·파이프를
  /// 후보로 보고 따옴표 안의 구분자를 세지 않는다. `dynamicTyping: false`로
  /// 모든 셀을 문자열로 받아 [ColumnMatcher]가 정규화하게 한다.
  static ImportTable _parseCsv(Uint8List bytes, String fileName) {
    final text = decodeCsv(bytes);

    // 증권사 "엑셀 다운로드"가 실제로는 HTML 표인 경우가 많다. 그냥 두면
    // 거대한 헤더 셀 하나와 0행으로 파싱돼 아무 안내 없이 쓸 수 없게 된다.
    if (_looksLikeHtml(text)) {
      throw const TableParseException(
        '엑셀 파일이 아니라 웹페이지(HTML)입니다. 엑셀에서 열어 .xlsx로 저장한 뒤 다시 시도해 주세요.',
      );
    }

    final parsed = const CsvDecoder(
      skipEmptyLines: true,
      dynamicTyping: false,
    ).convert(text);

    return _assemble(_toStringRows(parsed), fileName);
  }

  static bool _looksLikeHtml(String text) {
    final head = text.trimLeft();
    if (!head.startsWith('<')) return false;
    final lower = head.length > 1024 ? head.substring(0, 1024) : head;
    final probe = lower.toLowerCase();
    return probe.contains('<html') ||
        probe.contains('<table') ||
        probe.contains('<!doctype') ||
        probe.contains('<body');
  }

  // ── XLSX ───────────────────────────────────────────────────────────────────

  /// 시트가 여러 개면 시트마다 헤더 행을 찾아 맞춘 역할 수를 점수로 쓰고
  /// 가장 높은 시트를 고른다. 동점이면 앞쪽 시트.
  static ImportTable _parseXlsx(Uint8List bytes) {
    final Excel book;
    try {
      book = Excel.decodeBytes(bytes);
    } catch (e) {
      throw const TableParseException('엑셀 파일을 읽지 못했습니다.');
    }

    ImportTable? best;
    var bestScore = -1;
    var bestRowCount = -1;

    for (final entry in book.tables.entries) {
      final rows = _toStringRows(
        entry.value.rows.map((r) => r.map((d) => d?.value).toList()),
      );
      if (rows.isEmpty) continue;

      final table = _assemble(rows, entry.key);
      final score = ColumnMatcher.guessMapping(table.header).length;

      // 점수가 같으면 **행이 있는 시트**가 이긴다. 증권사 파일은 앞에
      // '양식'·'안내' 시트를 끼워 넣는데, 그게 헤더만 있으면 점수는 같고
      // 먼저 나왔다는 이유로 이겨 버려 "0행 인식"이 된다.
      final better = score > bestScore ||
          (score == bestScore && table.rows.length > bestRowCount);
      if (better) {
        bestScore = score;
        bestRowCount = table.rows.length;
        best = table;
      }
    }

    if (best == null) {
      throw const TableParseException('엑셀 파일에서 표를 찾지 못했습니다.');
    }
    return best;
  }

  // ── 공통 ───────────────────────────────────────────────────────────────────

  /// 모든 셀을 문자열로 바꾸고, 통째로 빈 줄은 버린다.
  static List<List<String>> _toStringRows(Iterable<List<dynamic>> raw) => raw
      .map((r) => r.map(_cellToString).toList())
      .where((r) => r.any((c) => c.isNotEmpty))
      .toList();

  static String _cellToString(dynamic cell) {
    if (cell == null) return '';
    if (cell is String) return cell.trim();
    if (cell is TextCellValue) return cell.value.toString().trim();
    if (cell is IntCellValue) return cell.value.toString();
    if (cell is DoubleCellValue) return _plainDouble(cell.value);
    if (cell is DateCellValue) {
      final m = cell.month.toString().padLeft(2, '0');
      final d = cell.day.toString().padLeft(2, '0');
      return '${cell.year}-$m-$d';
    }
    if (cell is BoolCellValue) return cell.value.toString();
    if (cell is FormulaCellValue) return cell.formula.trim();
    return cell.toString().trim();
  }

  /// `10.0` → `'10'`. 정수인 실수에 소수점이 붙으면 종목코드가 망가진다.
  static String _plainDouble(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// 헤더 행을 찾아 그 위를 버리고, 본문 줄을 헤더 길이에 맞춘다.
  static ImportTable _assemble(List<List<String>> rows, String sheetName) {
    if (rows.isEmpty) {
      throw const TableParseException('파일에서 표를 찾지 못했습니다.');
    }

    final headerIndex = ColumnMatcher.findHeaderRow(rows);
    final rawHeader = rows[headerIndex];
    final rawBody = rows.sublist(headerIndex + 1);

    // 폭은 헤더와 본문 중 가장 넓은 줄에 맞춘다. 헤더에 맞춰 **잘라내면**
    // 수량·단가가 조용히 사라진다 — 헤더에 빈 자리를 붙여 두고 사용자가
    // 매핑하게 하는 편이 낫다.
    var width = rawHeader.length;
    for (final row in rawBody) {
      if (row.length > width) width = row.length;
    }

    return ImportTable(
      header: _fit(rawHeader, width),
      rows: rawBody.map((r) => _fit(r, width)).toList(),
      sheetName: sheetName,
    );
  }

  static List<String> _fit(List<String> row, int width) {
    if (row.length == width) return row;
    if (row.length > width) return row.sublist(0, width);
    return [...row, ...List.filled(width - row.length, '')];
  }
}
