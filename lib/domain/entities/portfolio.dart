import 'package:freezed_annotation/freezed_annotation.dart';

part 'portfolio.freezed.dart';

@freezed
class Portfolio with _$Portfolio {
  const factory Portfolio({
    required int id,
    required String name,
    String? description,
    required String baseCurrency,
    String? rebalancePeriod,
    DateTime? nextRebalanceDate,
    required double deviationThreshold,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Portfolio;
}
