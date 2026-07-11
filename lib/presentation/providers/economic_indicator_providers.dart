import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/economic_indicator_local_ds.dart';
import '../../domain/entities/economic_indicator.dart';
import 'database_providers.dart';
import 'price_providers.dart';

// ── Local cache datasource ────────────────────────────────────────────────────

final economicIndicatorLocalDsProvider =
    Provider<EconomicIndicatorLocalDs>((ref) {
  return EconomicIndicatorLocalDs(ref.watch(sharedPreferencesProvider));
});

// ── State notifier ────────────────────────────────────────────────────────────

class EconomicIndicatorsNotifier
    extends StateNotifier<List<EconomicIndicator>> {
  final Ref _ref;

  EconomicIndicatorsNotifier(this._ref)
      : super(_buildInitialState(_ref)) {
    _fetchAll();
  }

  static List<EconomicIndicator> _buildInitialState(Ref ref) {
    final cache = ref.read(economicIndicatorLocalDsProvider).loadAll();
    return allIndicatorDefs.map((def) {
      final cached = cache[def.symbol];
      return EconomicIndicator(
        def: def,
        price: cached?['price'],
        previousClose: cached?['previousClose'],
      );
    }).toList();
  }

  Future<void> refresh() => _fetchAll();

  Future<void> _fetchAll() async {
    final yahoo = _ref.read(yahooFinanceDsProvider);
    final naver = _ref.read(naverFinanceDsProvider);
    final localDs = _ref.read(economicIndicatorLocalDsProvider);
    final cacheToSave = <String, Map<String, double?>>{};

    // 은(SI=F)은 USD/oz로 조회되므로 환율을 곱해 원/oz로 환산.
    final usdKrw = await _ref.read(usdKrwRateProvider.future);
    const usdToKrwSymbols = {'SI=F'};

    // Fetch all in batches of 4 concurrent requests
    const batchSize = 4;
    final pending = List<IndicatorDef>.from(allIndicatorDefs);

    while (pending.isNotEmpty) {
      final batch = pending.take(batchSize).toList();
      pending.removeRange(0, batch.length);

      await Future.wait(batch.map((def) async {
        try {
          // 국내 금 현물(원/g)은 네이버 marketindex, 그 외는 야후.
          final quote = def.symbol == 'M04020000'
              ? await naver.fetchMetalPrice(def.symbol)
              : await yahoo.fetchCurrentPrice(def.symbol);
          if (quote == null || !mounted) return;
          final fx = usdToKrwSymbols.contains(def.symbol) ? usdKrw : 1.0;
          final price = quote.price * fx;
          final prevClose =
              quote.previousClose == null ? null : quote.previousClose! * fx;
          cacheToSave[def.symbol] = {
            'price': price,
            'previousClose': prevClose,
          };
          state = [
            for (final ind in state)
              if (ind.def.symbol == def.symbol)
                ind.copyWithPrices(price, prevClose)
              else
                ind,
          ];
        } catch (_) {
          // Keep cached value on error
        }
      }));
    }

    if (cacheToSave.isNotEmpty) {
      await localDs.saveAll(cacheToSave);
    }
  }
}

final economicIndicatorsProvider =
    StateNotifierProvider<EconomicIndicatorsNotifier, List<EconomicIndicator>>(
        (ref) {
  return EconomicIndicatorsNotifier(ref);
});
