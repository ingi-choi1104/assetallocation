import '../entities/portfolio.dart';

abstract interface class PortfolioRepository {
  Stream<List<Portfolio>> watchAllPortfolios();
  Future<List<Portfolio>> getAllPortfolios();
  Future<Portfolio?> getPortfolioById(int id);
  Future<int> createPortfolio(Portfolio portfolio);
  Future<void> updatePortfolio(Portfolio portfolio);
  Future<void> deletePortfolio(int id);
}
