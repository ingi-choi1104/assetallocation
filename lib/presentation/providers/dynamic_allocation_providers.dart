import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/portfolio_strategy_local_ds.dart';
import '../../data/datasources/remote/dynamic_price_ds.dart';
import '../../domain/services/dynamic_allocation_service.dart';
import 'database_providers.dart';

final dynamicPriceDsProvider = Provider<DynamicPriceDataSource>((ref) {
  return DynamicPriceDataSource(ref.read(dioProvider));
});

final dynamicAllocationServiceProvider = Provider<DynamicAllocationService>((ref) {
  return const DynamicAllocationService();
});

final portfolioStrategyLocalDsProvider =
    Provider<PortfolioStrategyLocalDataSource>((ref) {
  return PortfolioStrategyLocalDataSource(ref.read(sharedPreferencesProvider));
});
