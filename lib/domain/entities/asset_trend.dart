// 추이(자산 그래프) 메뉴 전용 모델. 다른 메뉴와 공유하지 않는다.

/// 그래프 집계 단위.
enum TrendInterval {
  daily('일별'),
  weekly('주별'),
  monthly('월별');

  final String label;

  const TrendInterval(this.label);
}

/// 시세 한 개 (해당 시세의 원래 통화 기준).
class TrendBar {
  final DateTime date;
  final double close;

  const TrendBar({required this.date, required this.close});
}

/// 추이 곡선의 하루치. 두 금액 모두 원화.
class TrendPoint {
  final DateTime date;

  /// 그날 보유수량 × 그날 시세 (실선).
  final double valueKrw;

  /// 그날까지 누적 투입금액 (점선).
  final double investedKrw;

  /// 그날 순유입액 (매수 − 매도를 그날 시세로 환산). MDD를 계산할 때 이
  /// 금액을 빼야 적립 때문에 수익률이 부풀거나 꺼지지 않는다.
  final double flowKrw;

  const TrendPoint({
    required this.date,
    required this.valueKrw,
    required this.investedKrw,
    this.flowKrw = 0,
  });
}

/// MDD를 계산할 기간. 추이 데이터가 최대 5년이라 상한도 5년이다.
enum MddPeriod {
  y1('최근 1년', 1),
  y2('최근 2년', 2),
  y3('최근 3년', 3),
  y4('최근 4년', 4),
  y5('최근 5년', 5);

  final String label;
  final int years;

  const MddPeriod(this.label, this.years);

  static MddPeriod fromYears(int? years) => MddPeriod.values.firstWhere(
        (e) => e.years == years,
        orElse: () => MddPeriod.y5,
      );
}

/// 최대 낙폭(MDD)과 그 시기.
///
/// 적립식이라 평가액에는 입금이 섞여 있으므로, 평가액이 아니라 현금흐름을
/// 제거한 TWR(시간가중) 지수 위에서 잰 값이다.
class DrawdownResult {
  /// 최대 낙폭. 0 또는 음수 (-0.182 = -18.2%).
  final double maxDrawdown;

  /// 낙폭이 시작된 고점 날짜.
  final DateTime? peakDate;

  /// 바닥 날짜.
  final DateTime? troughDate;

  /// 고점을 되찾은 날짜. 아직 못 되찾았으면 null.
  final DateTime? recoveryDate;

  /// 지금 고점 대비 낙폭. 0 또는 음수.
  final double currentDrawdown;

  const DrawdownResult({
    required this.maxDrawdown,
    required this.currentDrawdown,
    this.peakDate,
    this.troughDate,
    this.recoveryDate,
  });

  static const DrawdownResult none =
      DrawdownResult(maxDrawdown: 0, currentDrawdown: 0);

  bool get hasDrawdown =>
      maxDrawdown < 0 && peakDate != null && troughDate != null;

  bool get recovered => recoveryDate != null;
}

/// 전체 자산의 일별 추이.
class TrendSeries {
  /// 날짜 오름차순, 하루 한 점.
  final List<TrendPoint> points;

  /// 투입금액 기록이 하나라도 있는지 — 없으면 점선을 그리지 않는다.
  final bool hasInvested;

  /// 과거 시세 제공처가 없어 현재가로 근사한 자산 이름.
  final List<String> approximated;

  const TrendSeries({
    required this.points,
    this.hasInvested = false,
    this.approximated = const [],
  });

  static const TrendSeries empty = TrendSeries(points: []);

  bool get isUsable => points.length >= 2;

  double get currentValueKrw =>
      points.isEmpty ? 0 : points.last.valueKrw;

  double get currentInvestedKrw =>
      points.isEmpty ? 0 : points.last.investedKrw;

  /// 주별·월별은 각 구간의 마지막 날만 남긴다. 마지막 점은 항상 오늘이라
  /// 현재 평가액과 어긋나지 않는다. 남는 점이 2개 미만이면 일별 그대로 둔다.
  List<TrendPoint> aggregate(TrendInterval interval) {
    if (interval == TrendInterval.daily || points.length < 2) return points;

    int bucketOf(DateTime d) {
      if (interval == TrendInterval.monthly) return d.year * 12 + d.month;
      // 1970-01-04는 일요일 — 주 경계를 일요일에 맞춘다.
      final days = DateTime(d.year, d.month, d.day)
          .difference(DateTime(1970, 1, 4))
          .inDays;
      return days ~/ 7;
    }

    final out = <TrendPoint>[];
    for (int i = 0; i < points.length; i++) {
      final lastOfBucket = i == points.length - 1 ||
          bucketOf(points[i + 1].date) != bucketOf(points[i].date);
      if (lastOfBucket) out.add(points[i]);
    }
    return out.length >= 2 ? out : points;
  }
}
