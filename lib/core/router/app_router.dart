import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/portfolio_detail/portfolio_detail_screen.dart';
import '../../presentation/screens/portfolio_form/portfolio_form_screen.dart';
import '../../presentation/screens/asset_search/asset_search_screen.dart';
import '../../presentation/screens/asset_detail/asset_detail_screen.dart';
import '../../presentation/screens/transaction_form/transaction_form_screen.dart';
import '../../presentation/screens/rebalance/rebalance_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/dynamic_allocation/strategy_selection_screen.dart';
import '../../presentation/screens/dynamic_allocation/strategy_result_screen.dart';
import '../../presentation/screens/portfolio_bundle/portfolio_bundle_screen.dart';
import '../../presentation/screens/snapshot/snapshot_list_screen.dart';
import '../../presentation/screens/snapshot/snapshot_detail_screen.dart';
import '../../presentation/screens/global_assets/global_assets_screen.dart';
import '../../presentation/screens/portfolio_bundle/bundle_assets_screen.dart';
import '../../domain/entities/dynamic_allocation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/global-assets',
        builder: (context, state) => const GlobalAssetsScreen(),
      ),
      GoRoute(
        path: '/snapshots',
        builder: (context, state) => const SnapshotListScreen(),
      ),
      GoRoute(
        path: '/snapshots/:id',
        builder: (context, state) => SnapshotDetailScreen(
          snapshotId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/bundle/:id',
        builder: (context, state) => PortfolioBundleScreen(
          bundleId: int.parse(state.pathParameters['id']!),
        ),
        routes: [
          GoRoute(
            path: 'assets',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return BundleAssetsScreen(
                bundleName: extra['name'] as String,
                portfolioIds: (extra['portfolioIds'] as List).cast<int>(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/dynamic-allocation',
        builder: (context, state) => const StrategySelectionScreen(),
      ),
      GoRoute(
        path: '/dynamic-allocation/result',
        builder: (context, state) {
          final config = state.extra as DynamicStrategyConfig;
          return StrategyResultScreen(config: config);
        },
      ),
      GoRoute(
        path: '/portfolio/new',
        builder: (context, state) => const PortfolioFormScreen(),
      ),
      GoRoute(
        path: '/portfolio/:id',
        builder: (context, state) => PortfolioDetailScreen(
          portfolioId: int.parse(state.pathParameters['id']!),
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => PortfolioFormScreen(
              portfolioId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'add-asset',
            builder: (context, state) => AssetSearchScreen(
              portfolioId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'rebalance',
            builder: (context, state) => RebalanceScreen(
              portfolioId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'asset/:assetId',
            builder: (context, state) => AssetDetailScreen(
              portfolioId: int.parse(state.pathParameters['id']!),
              portfolioAssetId:
                  int.parse(state.pathParameters['assetId']!),
            ),
            routes: [
              GoRoute(
                path: 'transaction',
                builder: (context, state) => TransactionFormScreen(
                  portfolioId: int.parse(state.pathParameters['id']!),
                  portfolioAssetId:
                      int.parse(state.pathParameters['assetId']!),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    ),
  );
});
