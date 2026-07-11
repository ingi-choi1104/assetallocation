enum PortfolioAccountType {
  general('일반'),
  pension('연금/IRP'),
  isa('ISA');

  final String label;
  const PortfolioAccountType(this.label);

  double get dividendTaxRate {
    switch (this) {
      case PortfolioAccountType.general: return 0.154;
      case PortfolioAccountType.pension: return 0.0;
      case PortfolioAccountType.isa:     return 0.099;
    }
  }

  bool get isTaxExempt => this == PortfolioAccountType.pension;
}
