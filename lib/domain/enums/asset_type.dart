enum AssetType {
  usStock('usStock', '미국 주식/ETF'),
  krStock('krStock', '한국 주식/ETF'),
  crypto('crypto', '암호화폐'),
  krFund('krFund', '한국 펀드'),
  gold('gold', '현물'),
  cash('cash', '현금');

  final String value;
  final String label;

  const AssetType(this.value, this.label);

  static AssetType fromValue(String value) {
    return AssetType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AssetType.usStock,
    );
  }

  String get currency {
    switch (this) {
      case AssetType.usStock:
      case AssetType.gold:
        return 'USD';
      case AssetType.krStock:
      case AssetType.krFund:
      case AssetType.crypto:
      case AssetType.cash:
        return 'KRW';
    }
  }
}
