class AssetSnapshotEntry {
  final String name;
  final String symbol;
  final String assetType;
  final double holdings;
  final double priceKrw;
  final double valueKrw;
  final double targetWeight;
  final String currency;

  const AssetSnapshotEntry({
    required this.name,
    required this.symbol,
    required this.assetType,
    required this.holdings,
    required this.priceKrw,
    required this.valueKrw,
    required this.targetWeight,
    required this.currency,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'symbol': symbol,
        'assetType': assetType,
        'holdings': holdings,
        'priceKrw': priceKrw,
        'valueKrw': valueKrw,
        'targetWeight': targetWeight,
        'currency': currency,
      };

  factory AssetSnapshotEntry.fromJson(Map<String, dynamic> j) =>
      AssetSnapshotEntry(
        name: j['name'] as String,
        symbol: j['symbol'] as String? ?? '',
        assetType: j['assetType'] as String? ?? '',
        holdings: (j['holdings'] as num).toDouble(),
        priceKrw: (j['priceKrw'] as num).toDouble(),
        valueKrw: (j['valueKrw'] as num).toDouble(),
        targetWeight: (j['targetWeight'] as num).toDouble(),
        currency: j['currency'] as String? ?? 'KRW',
      );
}

class PortfolioSnapshotEntry {
  final int portfolioId;
  final String name;
  final double valueKrw;
  final double invested;
  final double returnRate;
  final double annualizedReturnRate;
  final List<AssetSnapshotEntry> assets;

  const PortfolioSnapshotEntry({
    required this.portfolioId,
    required this.name,
    required this.valueKrw,
    required this.invested,
    required this.returnRate,
    this.annualizedReturnRate = 0,
    required this.assets,
  });

  Map<String, dynamic> toJson() => {
        'portfolioId': portfolioId,
        'name': name,
        'valueKrw': valueKrw,
        'invested': invested,
        'returnRate': returnRate,
        'annualizedReturnRate': annualizedReturnRate,
        'assets': assets.map((a) => a.toJson()).toList(),
      };

  factory PortfolioSnapshotEntry.fromJson(Map<String, dynamic> j) =>
      PortfolioSnapshotEntry(
        portfolioId: j['portfolioId'] as int,
        name: j['name'] as String,
        valueKrw: (j['valueKrw'] as num).toDouble(),
        invested: (j['invested'] as num).toDouble(),
        returnRate: (j['returnRate'] as num).toDouble(),
        annualizedReturnRate:
            (j['annualizedReturnRate'] as num? ?? 0).toDouble(),
        assets: (j['assets'] as List)
            .map((e) =>
                AssetSnapshotEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PortfolioSnapshot {
  final int id; // millisecondsSinceEpoch
  final DateTime takenAt;
  final String? memo;
  final double totalValueKrw;
  final double totalInvested;
  final double returnRate;
  final double annualizedReturnRate;
  final List<PortfolioSnapshotEntry> portfolios;

  const PortfolioSnapshot({
    required this.id,
    required this.takenAt,
    this.memo,
    required this.totalValueKrw,
    required this.totalInvested,
    required this.returnRate,
    this.annualizedReturnRate = 0,
    required this.portfolios,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'takenAt': takenAt.toIso8601String(),
        'memo': memo,
        'totalValueKrw': totalValueKrw,
        'totalInvested': totalInvested,
        'returnRate': returnRate,
        'annualizedReturnRate': annualizedReturnRate,
        'portfolios': portfolios.map((p) => p.toJson()).toList(),
      };

  factory PortfolioSnapshot.fromJson(Map<String, dynamic> j) =>
      PortfolioSnapshot(
        id: j['id'] as int,
        takenAt: DateTime.parse(j['takenAt'] as String),
        memo: j['memo'] as String?,
        totalValueKrw: (j['totalValueKrw'] as num).toDouble(),
        totalInvested: (j['totalInvested'] as num).toDouble(),
        returnRate: (j['returnRate'] as num).toDouble(),
        annualizedReturnRate:
            (j['annualizedReturnRate'] as num? ?? 0).toDouble(),
        portfolios: (j['portfolios'] as List)
            .map((e) =>
                PortfolioSnapshotEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
