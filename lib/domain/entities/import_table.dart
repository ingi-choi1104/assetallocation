import '../enums/asset_type.dart';

/// CSV·엑셀 표 가져오기의 도메인 모델. plain Dart — build_runner가 필요 없다.

/// 표의 한 열이 맡는 역할.
enum ColumnRole {
  symbol('종목코드'),
  name('종목명'),
  quantity('수량'),
  avgPrice('평균단가'),
  currentPrice('현재가'),
  buyDate('매수일');

  final String label;
  const ColumnRole(this.label);

  static ColumnRole? fromName(String name) {
    for (final r in ColumnRole.values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

/// 줄 하나가 가져오기에서 빠진 이유. 사용자에게 사유별로 세어 보여준다.
enum SkipReason {
  /// 종목코드가 비어 있다. 코드가 없으면 시세가 영영 안 붙는다.
  noSymbol('종목코드 없음'),

  /// 수량을 숫자로 못 읽었거나 0 이하다.
  badQuantity('수량 없음'),

  /// 한국·미국 중 어느 쪽인지 판단할 수 없다.
  unknownType('유형 판단 불가'),

  /// 고른 유형에 맞는 종목코드 형식이 아니다(예: 한국인데 한글 이름).
  invalidSymbol('종목코드 형식 오류'),

  /// 같은 종목이 이 파일 안에 이미 있었다.
  duplicateInFile('파일 내 중복'),

  /// 이 포트폴리오에 이미 있는 종목이다.
  alreadyHeld('이미 보유 중');

  final String label;
  const SkipReason(this.label);
}

/// 파일에서 읽어낸 표. 헤더 위 쓰레기 행은 이미 잘려 있다.
class ImportTable {
  final List<String> header;
  final List<List<String>> rows;

  /// `.xlsx`에서 고른 시트 이름. CSV는 파일명을 쓴다.
  final String sheetName;

  const ImportTable({
    required this.header,
    required this.rows,
    required this.sheetName,
  });
}

/// 가져올 준비가 된 한 줄.
class ImportRow {
  final int rowIndex;
  final String symbol;
  final String name;
  final double quantity;

  /// 없으면 종목만 등록하고 거래·투자원금은 만들지 않는다.
  final double? avgPrice;

  /// 미리보기 전용. `assets.lastPrice`에 쓰지 않는다 — 파일의 가격은 과거
  /// 시점 값인데 갱신시각으로 넣을 날짜가 없다.
  final double? currentPrice;

  final DateTime buyDate;
  final AssetType assetType;

  const ImportRow({
    required this.rowIndex,
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.avgPrice,
    required this.currentPrice,
    required this.buyDate,
    required this.assetType,
  });

  /// `{symbol, assetType}` 중복 판정에 쓰는 키.
  String get key => '$symbol|${assetType.value}';
}

/// 빠진 줄 하나.
class SkippedRow {
  final int rowIndex;
  final SkipReason reason;

  const SkippedRow({required this.rowIndex, required this.reason});
}

/// 확인·수정 화면이 보여주는 것 전부.
class ImportPreview {
  final List<ImportRow> rows;
  final List<SkippedRow> skipped;

  /// 사유가 하나도 없는 키는 담지 않는다.
  final Map<SkipReason, int> skipCounts;

  const ImportPreview({
    required this.rows,
    required this.skipped,
    required this.skipCounts,
  });
}
