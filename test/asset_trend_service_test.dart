import 'package:flutter_test/flutter_test.dart';

import 'package:assetallocation/domain/entities/asset_trend.dart';
import 'package:assetallocation/domain/entities/investment.dart';
import 'package:assetallocation/domain/entities/transaction.dart';
import 'package:assetallocation/domain/enums/transaction_type.dart';
import 'package:assetallocation/domain/services/asset_trend_service.dart';

DateTime day(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: daysAgo));
}

Transaction buy(double qty, double price, int daysAgo) => Transaction(
      id: daysAgo,
      portfolioAssetId: 1,
      type: TransactionType.buy,
      quantity: qty,
      price: price,
      exchangeRate: 1,
      fee: 0,
      transactionDate: day(daysAgo),
      createdAt: day(daysAgo),
    );

Transaction sell(double qty, double price, int daysAgo) => Transaction(
      id: 500 + daysAgo,
      portfolioAssetId: 1,
      type: TransactionType.sell,
      quantity: qty,
      price: price,
      exchangeRate: 1,
      fee: 0,
      transactionDate: day(daysAgo),
      createdAt: day(daysAgo),
    );

void main() {
  group('AssetTrendService.build', () {
    test('평가금액 = 그날 보유수량 × 그날 시세', () {
      final series = AssetTrendService.build(
        assets: [
          TrendAssetInput(
            name: 'A',
            currency: 'KRW',
            transactions: [buy(10, 1000, 4)],
            bars: [
              TrendBar(date: day(4), close: 1000),
              TrendBar(date: day(2), close: 1500),
              TrendBar(date: day(0), close: 2000),
            ],
            currentPrice: 2000,
          ),
        ],
        fxHistory: const {},
        currentFxRates: const {'KRW': 1.0},
        investments: const [],
      );

      expect(series.points.length, 5);
      expect(series.points[0].valueKrw, 10 * 1000);
      // 시세가 없는 날은 직전 종가를 이월한다.
      expect(series.points[1].valueKrw, 10 * 1000);
      expect(series.points[2].valueKrw, 10 * 1500);
      expect(series.points[3].valueKrw, 10 * 1500);
      expect(series.points.last.valueKrw, 10 * 2000);
    });

    test('매도하면 그날부터 평가금액이 줄어든다', () {
      final series = AssetTrendService.build(
        assets: [
          TrendAssetInput(
            name: 'A',
            currency: 'KRW',
            transactions: [buy(10, 100, 3), sell(4, 100, 1)],
            bars: [TrendBar(date: day(3), close: 100)],
            currentPrice: 100,
          ),
        ],
        fxHistory: const {},
        currentFxRates: const {'KRW': 1.0},
        investments: const [],
      );

      expect(series.points[0].valueKrw, 1000);
      expect(series.points[1].valueKrw, 1000);
      expect(series.points[2].valueKrw, 600);
      expect(series.points[3].valueKrw, 600);
    });

    test('외화 자산은 그날 환율로 환산한다', () {
      final series = AssetTrendService.build(
        assets: [
          TrendAssetInput(
            name: 'SPY',
            currency: 'USD',
            transactions: [buy(2, 100, 2)],
            bars: [TrendBar(date: day(2), close: 100)],
            currentPrice: 100,
          ),
        ],
        fxHistory: {
          'USD': [
            TrendBar(date: day(2), close: 1300),
            TrendBar(date: day(0), close: 1400),
          ],
        },
        currentFxRates: const {'KRW': 1.0, 'USD': 1400},
        investments: const [],
      );

      expect(series.points.first.valueKrw, 2 * 100 * 1300);
      expect(series.points.last.valueKrw, 2 * 100 * 1400);
    });

    test('과거 시세가 없으면 현재가로 근사하고 이름을 남긴다', () {
      final series = AssetTrendService.build(
        assets: [
          TrendAssetInput(
            name: '금 현물',
            currency: 'KRW',
            transactions: [buy(3, 140000, 2)],
            bars: const [],
            currentPrice: 150000,
          ),
          const TrendAssetInput(
            name: '보유 없음',
            currency: 'KRW',
            transactions: [],
            bars: [],
            currentPrice: 150000,
          ),
        ],
        fxHistory: const {},
        currentFxRates: const {'KRW': 1.0},
        investments: const [],
      );

      expect(series.points.last.valueKrw, 3 * 150000);
      expect(series.approximated, ['금 현물']);
    });

    test('투입금액은 투자일 기준으로 누적된다', () {
      final series = AssetTrendService.build(
        assets: [
          TrendAssetInput(
            name: 'A',
            currency: 'KRW',
            transactions: [buy(1, 1000, 3)],
            bars: [TrendBar(date: day(3), close: 1200)],
            currentPrice: 1200,
          ),
        ],
        fxHistory: const {},
        currentFxRates: const {'KRW': 1.0},
        investments: [
          Investment(
            id: 1,
            portfolioId: 1,
            amount: 1000,
            investmentDate: day(3),
            createdAt: day(3),
          ),
          Investment(
            id: 2,
            portfolioId: 1,
            amount: 500,
            investmentDate: day(1),
            createdAt: day(1),
          ),
        ],
      );

      expect(series.hasInvested, isTrue);
      expect(series.points[0].investedKrw, 1000);
      expect(series.points[1].investedKrw, 1000);
      expect(series.points[2].investedKrw, 1500);
      expect(series.currentInvestedKrw, 1500);
    });

    test('일봉이 끊긴 최근 며칠은 실시간 시세로 채운다', () {
      // 마지막 봉은 3일 전. 그 뒤 사흘은 현재가(2,000)로 계산돼야 한다.
      final series = AssetTrendService.build(
        assets: [
          TrendAssetInput(
            name: 'A',
            currency: 'KRW',
            transactions: [buy(10, 1000, 5)],
            bars: [
              TrendBar(date: day(5), close: 1000),
              TrendBar(date: day(3), close: 1500),
            ],
            currentPrice: 2000,
          ),
        ],
        fxHistory: const {},
        currentFxRates: const {'KRW': 1.0},
        investments: const [],
      );

      expect(series.points[0].valueKrw, 10 * 1000); // day(5)
      expect(series.points[2].valueKrw, 10 * 1500); // day(3), 마지막 봉
      expect(series.points[3].valueKrw, 10 * 2000); // day(2) 이후는 현재가
      expect(series.points.last.valueKrw, 10 * 2000);
    });

    test('환율도 마지막 봉 이후는 현재 환율을 쓴다', () {
      final series = AssetTrendService.build(
        assets: [
          TrendAssetInput(
            name: 'SPY',
            currency: 'USD',
            transactions: [buy(2, 100, 4)],
            bars: [TrendBar(date: day(4), close: 100)],
            currentPrice: 100,
          ),
        ],
        fxHistory: {
          // 환율 일봉이 이틀 전에서 끊겼다.
          'USD': [
            TrendBar(date: day(4), close: 1300),
            TrendBar(date: day(2), close: 1350),
          ],
        },
        currentFxRates: const {'KRW': 1.0, 'USD': 1400},
        investments: const [],
      );

      expect(series.points[0].valueKrw, 2 * 100 * 1300);
      expect(series.points[2].valueKrw, 2 * 100 * 1350); // day(2)
      expect(series.points.last.valueKrw, 2 * 100 * 1400); // 오늘 = 현재 환율
      expect(series.approximated, isEmpty);
    });

    test('환율 이력을 못 받으면 근사했다고 알린다', () {
      final series = AssetTrendService.build(
        assets: [
          TrendAssetInput(
            name: 'SPY',
            currency: 'USD',
            transactions: [buy(2, 100, 3)],
            bars: [TrendBar(date: day(3), close: 100)],
            currentPrice: 100,
          ),
        ],
        fxHistory: const {},
        currentFxRates: const {'KRW': 1.0, 'USD': 1400},
        investments: const [],
      );

      expect(series.approximated, contains('USD 환율'));
      // 이력이 없으면 전 구간 현재 환율.
      expect(series.points.first.valueKrw, 2 * 100 * 1400);
    });

    test('외화 현금도 그날 환율로 환산한다', () {
      final series = AssetTrendService.build(
        assets: [
          TrendAssetInput(
            name: '달러 현금',
            currency: 'USD',
            transactions: [buy(1000, 1, 2)],
            bars: const [], // 현금은 시세가 없다 — 단가 1.0 고정
            currentPrice: 1.0,
          ),
        ],
        fxHistory: {
          'USD': [
            TrendBar(date: day(2), close: 1300),
            TrendBar(date: day(0), close: 1400),
          ],
        },
        currentFxRates: const {'KRW': 1.0, 'USD': 1400},
        investments: const [],
      );

      expect(series.points.first.valueKrw, 1000 * 1300);
      expect(series.points.last.valueKrw, 1000 * 1400);
    });

    test('그릴 것이 없으면 빈 시리즈', () {
      final series = AssetTrendService.build(
        assets: const [
          TrendAssetInput(
            name: 'A',
            currency: 'KRW',
            transactions: [],
            bars: [],
            currentPrice: 1000,
          ),
        ],
        fxHistory: const {},
        currentFxRates: const {'KRW': 1.0},
        investments: const [],
      );

      expect(series.isUsable, isFalse);
    });
  });

  group('AssetTrendService.startDate', () {
    test('첫 거래와 첫 투입금액 중 이른 날', () {
      final start = AssetTrendService.startDate(
        assets: [
          TrendAssetInput(
            name: 'A',
            currency: 'KRW',
            transactions: [buy(1, 100, 10)],
            bars: const [],
            currentPrice: 100,
          ),
        ],
        investments: [
          Investment(
            id: 1,
            portfolioId: 1,
            amount: 100,
            investmentDate: day(30),
            createdAt: day(30),
          ),
        ],
      );
      expect(start, day(30));
    });

    test('5년보다 오래되면 5년 전으로 자른다', () {
      final start = AssetTrendService.startDate(
        assets: [
          TrendAssetInput(
            name: 'A',
            currency: 'KRW',
            transactions: [buy(1, 100, 365 * 8)],
            bars: const [],
            currentPrice: 100,
          ),
        ],
        investments: const [],
      );
      expect(start, day(AssetTrendService.maxLookbackDays));
    });
  });

  _mddTests();
  _slicePeriodTests();

  group('TrendSeries.aggregate', () {
    List<TrendPoint> dailyPoints(int count) => [
          for (int i = count - 1; i >= 0; i--)
            TrendPoint(date: day(i), valueKrw: 100.0 + i, investedKrw: 50)
        ];

    test('일별은 그대로', () {
      final series = TrendSeries(points: dailyPoints(30));
      expect(series.aggregate(TrendInterval.daily), same(series.points));
    });

    test('주별은 주마다 한 점, 마지막은 오늘', () {
      final series = TrendSeries(points: dailyPoints(70));
      final weekly = series.aggregate(TrendInterval.weekly);

      expect(weekly.length, inInclusiveRange(10, 11));
      expect(weekly.last.date, series.points.last.date);
      // 마지막 주는 오늘에서 잘리므로 그 앞까지만 정확히 7일 간격이다.
      for (int i = 0; i < weekly.length - 2; i++) {
        expect(weekly[i + 1].date.difference(weekly[i].date).inDays, 7);
      }
    });

    test('월별은 달마다 한 점, 마지막은 오늘', () {
      final series = TrendSeries(points: dailyPoints(400));
      final monthly = series.aggregate(TrendInterval.monthly);

      expect(monthly.length, inInclusiveRange(13, 14));
      expect(monthly.last.date, series.points.last.date);
      final months = monthly.map((p) => '${p.date.year}-${p.date.month}');
      expect(months.toSet().length, monthly.length);
    });

    test('점이 2개 미만으로 줄면 일별로 되돌린다', () {
      final series = TrendSeries(points: dailyPoints(3));
      expect(series.aggregate(TrendInterval.monthly).length,
          greaterThanOrEqualTo(2));
    });
  });
}

// ── MDD (적립 현금흐름 제거) ──────────────────────────────────────────────────

TrendPoint pt(int daysAgo, double value, {double flow = 0}) =>
    TrendPoint(date: day(daysAgo), valueKrw: value, investedKrw: 0, flowKrw: flow);

void _mddTests() {
  group('AssetTrendService.drawdown', () {
    test('현금흐름이 없으면 평가액 낙폭 그대로', () {
      // 100 → 120(고점) → 90(바닥) → 110
      final dd = AssetTrendService.drawdown([
        pt(4, 100),
        pt(3, 120),
        pt(2, 90),
        pt(1, 100),
        pt(0, 110),
      ]);

      expect(dd.maxDrawdown, closeTo(-0.25, 1e-9)); // 120 → 90
      expect(dd.peakDate, day(3));
      expect(dd.troughDate, day(2));
      expect(dd.recovered, isFalse); // 110 < 120
      expect(dd.currentDrawdown, closeTo(110 / 120 - 1, 1e-9));
    });

    test('입금으로 생긴 신고점은 낙폭 계산을 어지럽히지 않는다', () {
      // 운용성과는 내내 그대로(수익률 0)인데 입금만 들어온 경우.
      final dd = AssetTrendService.drawdown([
        pt(3, 100),
        pt(2, 200, flow: 100), // 100 입금 — 성과 아님
        pt(1, 200),
        pt(0, 300, flow: 100), // 또 100 입금
      ]);

      expect(dd.maxDrawdown, 0); // 낙폭 없음
      expect(dd.hasDrawdown, isFalse);
    });

    test('입금 직후 하락도 실제 낙폭만 잡는다', () {
      // 100 → (100 입금) 200 → 180 : 실제로는 -10%만 하락
      final dd = AssetTrendService.drawdown([
        pt(2, 100),
        pt(1, 200, flow: 100),
        pt(0, 180),
      ]);

      expect(dd.maxDrawdown, closeTo(-0.1, 1e-9));
      expect(dd.troughDate, day(0));
    });

    test('출금은 낙폭으로 잡히지 않는다', () {
      // 100 → 100 → (50 출금) 50
      final dd = AssetTrendService.drawdown([
        pt(2, 100),
        pt(1, 100),
        pt(0, 50, flow: -50),
      ]);

      expect(dd.maxDrawdown, 0);
    });

    test('전량 매도(평가액 0)도 낙폭이 아니다', () {
      final dd = AssetTrendService.drawdown([
        pt(2, 100),
        pt(1, 100),
        pt(0, 0, flow: -100),
      ]);

      expect(dd.maxDrawdown, 0);
    });

    test('고점을 되찾으면 회복일을 알려준다', () {
      final dd = AssetTrendService.drawdown([
        pt(4, 100),
        pt(3, 120),
        pt(2, 90),
        pt(1, 110),
        pt(0, 130),
      ]);

      expect(dd.maxDrawdown, closeTo(-0.25, 1e-9));
      expect(dd.recovered, isTrue);
      expect(dd.recoveryDate, day(0));
      expect(dd.currentDrawdown, 0);
    });

    test('빈 구간이나 한 점이면 낙폭 없음', () {
      expect(AssetTrendService.drawdown(const []).hasDrawdown, isFalse);
      expect(AssetTrendService.drawdown([pt(0, 100)]).hasDrawdown, isFalse);
    });

    test('보유가 없다가 매수로 시작해도 첫날이 낙폭이 되지 않는다', () {
      final dd = AssetTrendService.drawdown([
        pt(3, 0),
        pt(2, 1000, flow: 1000), // 최초 매수
        pt(1, 900),
        pt(0, 950),
      ]);

      expect(dd.maxDrawdown, closeTo(-0.1, 1e-9));
      expect(dd.troughDate, day(1));
    });

    test('build()가 매수일의 순유입액을 기록한다', () {
      final series = AssetTrendService.build(
        assets: [
          TrendAssetInput(
            name: 'A',
            currency: 'KRW',
            transactions: [buy(10, 100, 3), buy(10, 100, 1)],
            bars: [TrendBar(date: day(3), close: 100)],
            currentPrice: 100,
          ),
        ],
        fxHistory: const {},
        currentFxRates: const {'KRW': 1.0},
        investments: const [],
      );

      // day(3)은 창의 첫날 → 기초 보유로 잡혀 유입 0
      expect(series.points[0].flowKrw, 0);
      expect(series.points[1].flowKrw, 0);
      // day(1)에 10주 추가 매수 = 1,000원 유입
      expect(series.points[2].flowKrw, closeTo(1000, 1e-9));
      // 적립만 했으므로 낙폭 없음
      expect(AssetTrendService.drawdown(series.points).maxDrawdown, 0);
    });
  });
}

void _slicePeriodTests() {
  group('AssetTrendService.sliceYears', () {
    List<TrendPoint> points(int days) => [
          for (int i = days - 1; i >= 0; i--)
            TrendPoint(date: day(i), valueKrw: 100, investedKrw: 0)
        ];

    test('최근 N년만 남긴다', () {
      final all = points(365 * 4); // 4년치
      final oneYear = AssetTrendService.sliceYears(all, 1);

      expect(oneYear.length, lessThan(all.length));
      expect(oneYear.last.date, all.last.date);
      final span = oneYear.last.date.difference(oneYear.first.date).inDays;
      expect(span, inInclusiveRange(360, 372));
    });

    test('데이터가 기간보다 짧으면 그대로', () {
      final all = points(100);
      expect(AssetTrendService.sliceYears(all, 5).length, all.length);
    });

    test('잘라서 2점 미만이면 원본 유지', () {
      final all = points(2);
      expect(AssetTrendService.sliceYears(all, 1).length, 2);
    });

    test('기간이 짧으면 그 안의 낙폭만 잡힌다', () {
      // 3년 전에 -50%, 최근 1년 안에는 -20%만 있었던 경우.
      final pts = <TrendPoint>[
        pt(365 * 3, 100),
        pt(365 * 3 - 10, 50), // 오래된 폭락
        pt(365 * 3 - 20, 100),
        pt(300, 100), // 최근 1년 안의 고점
        pt(50, 80), // 최근 1년 안 -20%
        pt(0, 90),
      ];

      final full = AssetTrendService.drawdown(pts);
      expect(full.maxDrawdown, closeTo(-0.5, 1e-9));

      final recent =
          AssetTrendService.drawdown(AssetTrendService.sliceYears(pts, 1));
      expect(recent.maxDrawdown, closeTo(-0.2, 1e-9));
      expect(recent.troughDate, day(50));
    });
  });

  group('MddPeriod', () {
    test('저장값이 없거나 이상하면 5년이 기본', () {
      expect(MddPeriod.fromYears(null), MddPeriod.y5);
      expect(MddPeriod.fromYears(99), MddPeriod.y5);
      expect(MddPeriod.fromYears(0), MddPeriod.y5);
    });

    test('저장된 연수를 복원한다', () {
      expect(MddPeriod.fromYears(1), MddPeriod.y1);
      expect(MddPeriod.fromYears(3), MddPeriod.y3);
      expect(MddPeriod.fromYears(4), MddPeriod.y4);
    });

    test('1~5년 다섯 항목', () {
      expect(MddPeriod.values.map((e) => e.years).toList(), [1, 2, 3, 4, 5]);
    });
  });
}
