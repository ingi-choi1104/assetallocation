import 'portfolio.dart';

// ─── Portfolio Bundle (묶음) ───────────────────────────────────────────────────

class PortfolioBundle {
  final int id;
  final String name;
  final List<int> portfolioIds; // ordered list of portfolio IDs
  final int sortOrder;

  const PortfolioBundle({
    required this.id,
    required this.name,
    required this.portfolioIds,
    this.sortOrder = 0,
  });

  PortfolioBundle copyWith({
    String? name,
    List<int>? portfolioIds,
    int? sortOrder,
  }) =>
      PortfolioBundle(
        id: id,
        name: name ?? this.name,
        portfolioIds: portfolioIds ?? this.portfolioIds,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'portfolioIds': portfolioIds,
        'sortOrder': sortOrder,
      };

  factory PortfolioBundle.fromJson(Map<String, dynamic> json) => PortfolioBundle(
        id: json['id'] as int,
        name: json['name'] as String,
        portfolioIds: (json['portfolioIds'] as List).cast<int>(),
        sortOrder: json['sortOrder'] as int? ?? 0,
      );
}

// ─── Home Screen Item (sealed union) ─────────────────────────────────────────

sealed class HomeItem {}

class HomePortfolioItem extends HomeItem {
  final Portfolio portfolio;
  HomePortfolioItem(this.portfolio);
}

class HomeBundleItem extends HomeItem {
  final PortfolioBundle bundle;
  final List<Portfolio> portfolios; // resolved Portfolio objects (valid IDs only)
  HomeBundleItem({required this.bundle, required this.portfolios});
}
