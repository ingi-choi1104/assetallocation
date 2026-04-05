import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/background_refresh_provider.dart';
import 'presentation/providers/database_providers.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. DB에 저장된 마지막 가격을 메모리 캐시로 즉시 로드 (일일 변동 표시용)
      await ref.read(priceRepositoryProvider).initializePriceCache();
      // 2. 백그라운드에서 실시간 가격 가져오기 시작 (5분 주기 자동 갱신)
      ref.read(backgroundPriceRefreshProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '자산배분 헬퍼',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
