import '../entities/asset_trend.dart';
import '../entities/investment.dart';
import '../entities/transaction.dart';
import '../enums/transaction_type.dart';

/// 추이 메뉴에서 쓰는 한 자산의 입력값.
class TrendAssetInput {
  final String name;

  /// 자산의 원래 통화 ('KRW', 'USD', ...).
  final String currency;

  /// 이 자산의 전체 거래내역 (순서 무관).
  final List<Transaction> transactions;

  /// 원래 통화 기준 일별 종가, 날짜 오름차순. 과거 시세를 못 받으면 빈 목록.
  final List<TrendBar> bars;

  /// 최근 가격 — 시세가 없는 구간의 대체값.
  final double currentPrice;

  const TrendAssetInput({
    required this.name,
    required this.currency,
    required this.transactions,
    required this.bars,
    required this.currentPrice,
  });
}

/// 거래내역·투입금액·과거 시세로 전체 자산의 일별 추이를 만든다.
/// 순수 계산만 하며 네트워크나 DB를 건드리지 않는다.
class AssetTrendService {
  AssetTrendService._();

  /// 가져오는 과거 정보의 상한 — 5년.
  static const int maxLookbackDays = 365 * 5;

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 곡선이 시작하는 날: 첫 거래 또는 첫 투입금액. 5년을 넘으면 5년 전으로
  /// 자른다. 그릴 것이 없으면 null.
  static DateTime? startDate({
    required List<TrendAssetInput> assets,
    required List<Investment> investments,
  }) {
    DateTime? earliest;
    void consider(DateTime d) {
      if (earliest == null || d.isBefore(earliest!)) earliest = d;
    }

    for (final a in assets) {
      for (final tx in a.transactions) {
        consider(tx.transactionDate);
      }
    }
    for (final inv in investments) {
      consider(inv.investmentDate);
    }
    if (earliest == null) return null;

    final today = _dayKey(DateTime.now());
    final floor = today.subtract(const Duration(days: maxLookbackDays));
    final start = _dayKey(earliest!);
    return start.isBefore(floor) ? floor : start;
  }

  static TrendSeries build({
    required List<TrendAssetInput> assets,
    required Map<String, List<TrendBar>> fxHistory,
    required Map<String, double> currentFxRates,
    required List<Investment> investments,
    DateTime? startOverride,
  }) {
    final start = startOverride == null
        ? startDate(assets: assets, investments: investments)
        : _dayKey(startOverride);
    if (start == null) return TrendSeries.empty;

    final today = _dayKey(DateTime.now());
    final dayCount = today.difference(start).inDays + 1;
    if (dayCount < 2) return TrendSeries.empty;

    final days = List<DateTime>.generate(
      dayCount,
      (i) => start.add(Duration(days: i)),
      growable: false,
    );

    // ── 통화별 일별 환율 ────────────────────────────────────────────────────
    final approximated = <String>[];
    final fxByCurrency = <String, List<double>>{};
    for (final currency
        in assets.map((a) => a.currency.toUpperCase()).toSet()) {
      if (currency == 'KRW') continue;
      final bars = fxHistory[currency] ?? const <TrendBar>[];
      final live = currentFxRates[currency];
      // 환율 이력을 못 받으면 전 구간이 현재 환율로 눌리므로 그 사실을 알린다.
      if (bars.isEmpty) approximated.add('$currency 환율');
      fxByCurrency[currency] = _forwardFill(
        bars: bars,
        days: days,
        fallback: live ?? 1.0,
        latest: live,
      );
    }

    // ── 자산별 기여분 합산 ──────────────────────────────────────────────────
    final totals = List<double>.filled(dayCount, 0);
    // 그날 순유입액 (매수 − 매도). MDD 계산에서 걷어낸다.
    final flows = List<double>.filled(dayCount, 0);

    for (final asset in assets) {
      final currency = asset.currency.toUpperCase();
      final prices = _forwardFill(
        bars: asset.bars,
        days: days,
        fallback: asset.currentPrice,
        latest: asset.currentPrice,
      );
      final holdings = _holdingsPerDay(asset.transactions, days);
      final fx = currency == 'KRW' ? null : fxByCurrency[currency];

      var everHeld = false;
      for (int i = 0; i < dayCount; i++) {
        final qty = holdings[i];
        final rate = fx == null ? 1.0 : fx[i];
        if (qty != 0) {
          everHeld = true;
          totals[i] += qty * prices[i] * rate;
        }
        // 수량이 변한 날은 그 변화분이 현금 유입·유출이다.
        if (i > 0) {
          final delta = qty - holdings[i - 1];
          if (delta != 0) flows[i] += delta * prices[i] * rate;
        }
      }

      if (everHeld && asset.bars.isEmpty) approximated.add(asset.name);
    }

    // ── 누적 투입금액 ───────────────────────────────────────────────────────
    final invested = _investedPerDay(investments, days);

    return TrendSeries(
      points: [
        for (int i = 0; i < dayCount; i++)
          TrendPoint(
            date: days[i],
            valueKrw: totals[i],
            investedKrw: invested[i],
            flowKrw: flows[i],
          )
      ],
      hasInvested: investments.isNotEmpty,
      approximated: approximated,
    );
  }

  /// 최근 [years]년 구간만 남긴다. 그보다 데이터가 짧으면 그대로 돌려준다.
  static List<TrendPoint> sliceYears(List<TrendPoint> points, int years) {
    if (points.isEmpty || years <= 0) return points;
    final today = _dayKey(DateTime.now());
    final cutoff = DateTime(today.year - years, today.month, today.day);
    final out = points.where((p) => !p.date.isBefore(cutoff)).toList();
    return out.length >= 2 ? out : points;
  }

  /// 최대 낙폭(MDD)과 그 시기.
  ///
  /// 적립식 계좌에서는 평가액으로 낙폭을 재면 안 된다 — 입금이 신고점을 만들고
  /// 출금이 가짜 하락을 만든다. 그래서 하루 수익률에서 그날의 순유입액을 빼
  /// 현금흐름을 제거한 TWR(시간가중) 지수를 만들고, 그 지수 위에서 잰다.
  ///
  ///     r(t) = ( V(t) − 순유입(t) ) / V(t−1)
  ///     NAV(t) = NAV(t−1) × r(t)
  ///
  /// 이러면 전량 매도(V=0)도 r=1이 되어 낙폭으로 잡히지 않는다.
  static DrawdownResult drawdown(List<TrendPoint> points) {
    if (points.length < 2) return DrawdownResult.none;

    final navs = <double>[1.0];
    var nav = 1.0;
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1].valueKrw;
      if (prev > 0) {
        final r = (points[i].valueKrw - points[i].flowKrw) / prev;
        // 데이터가 튀는 날(음수·무한대)은 지수를 건드리지 않고 넘어간다.
        if (r.isFinite && r > 0) nav *= r;
      }
      navs.add(nav);
    }

    var peak = navs.first;
    var peakDate = points.first.date;
    var maxDd = 0.0;
    var peakAtMax = peak;
    var troughIndex = -1;
    DateTime? ddPeak;
    DateTime? ddTrough;

    for (int i = 0; i < navs.length; i++) {
      if (navs[i] > peak) {
        peak = navs[i];
        peakDate = points[i].date;
      }
      final dd = navs[i] / peak - 1;
      if (dd < maxDd) {
        maxDd = dd;
        ddPeak = peakDate;
        ddTrough = points[i].date;
        peakAtMax = peak;
        troughIndex = i;
      }
    }

    DateTime? recovery;
    if (troughIndex >= 0) {
      for (int i = troughIndex + 1; i < navs.length; i++) {
        if (navs[i] >= peakAtMax) {
          recovery = points[i].date;
          break;
        }
      }
    }

    return DrawdownResult(
      maxDrawdown: maxDd,
      currentDrawdown: peak > 0 ? navs.last / peak - 1 : 0,
      peakDate: ddPeak,
      troughDate: ddTrough,
      recoveryDate: recovery,
    );
  }

  /// [bars]를 [days]에 얹고 마지막 종가를 앞으로 이월한다. 첫 시세 이전 날은
  /// 첫 종가를, [bars]가 비면 전 구간 [fallback]을 쓴다.
  ///
  /// 일봉은 보통 하루 이틀 늦게 갱신되므로, 마지막 봉보다 뒤의 날에는 [latest]
  /// (앱이 들고 있는 실시간 값)를 쓴다. 이래야 추이의 '오늘' 금액이 홈 화면의
  /// 전체 자산과 같아진다.
  static List<double> _forwardFill({
    required List<TrendBar> bars,
    required List<DateTime> days,
    required double fallback,
    double? latest,
  }) {
    if (bars.isEmpty) return List<double>.filled(days.length, fallback);

    final sorted = List<TrendBar>.from(bars)
      ..sort((a, b) => a.date.compareTo(b.date));
    final lastBarDay = _dayKey(sorted.last.date);
    final useLatest = latest != null && latest > 0;

    final out = List<double>.filled(days.length, sorted.first.close);
    int cursor = 0;
    double last = sorted.first.close;

    for (int i = 0; i < days.length; i++) {
      while (cursor < sorted.length &&
          !_dayKey(sorted[cursor].date).isAfter(days[i])) {
        last = sorted[cursor].close;
        cursor++;
      }
      out[i] = (useLatest && days[i].isAfter(lastBarDay)) ? latest : last;
    }
    return out;
  }

  /// 날짜별 누적 보유수량.
  static List<double> _holdingsPerDay(
    List<Transaction> transactions,
    List<DateTime> days,
  ) {
    final out = List<double>.filled(days.length, 0);
    if (transactions.isEmpty) return out;

    final sorted = List<Transaction>.from(transactions)
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

    int cursor = 0;
    double qty = 0;

    // 창 시작 이전 거래는 기초 수량에 이미 반영된 것으로 본다.
    while (cursor < sorted.length &&
        _dayKey(sorted[cursor].transactionDate).isBefore(days.first)) {
      qty += sorted[cursor].type == TransactionType.buy
          ? sorted[cursor].quantity
          : -sorted[cursor].quantity;
      cursor++;
    }

    for (int i = 0; i < days.length; i++) {
      while (cursor < sorted.length &&
          !_dayKey(sorted[cursor].transactionDate).isAfter(days[i])) {
        qty += sorted[cursor].type == TransactionType.buy
            ? sorted[cursor].quantity
            : -sorted[cursor].quantity;
        cursor++;
      }
      out[i] = qty;
    }
    return out;
  }

  /// 날짜별 누적 투입금액 (원).
  static List<double> _investedPerDay(
    List<Investment> investments,
    List<DateTime> days,
  ) {
    final out = List<double>.filled(days.length, 0);
    if (investments.isEmpty) return out;

    final sorted = List<Investment>.from(investments)
      ..sort((a, b) => a.investmentDate.compareTo(b.investmentDate));

    int cursor = 0;
    double total = 0;

    while (cursor < sorted.length &&
        _dayKey(sorted[cursor].investmentDate).isBefore(days.first)) {
      total += sorted[cursor].amount;
      cursor++;
    }

    for (int i = 0; i < days.length; i++) {
      while (cursor < sorted.length &&
          !_dayKey(sorted[cursor].investmentDate).isAfter(days[i])) {
        total += sorted[cursor].amount;
        cursor++;
      }
      out[i] = total;
    }
    return out;
  }
}
