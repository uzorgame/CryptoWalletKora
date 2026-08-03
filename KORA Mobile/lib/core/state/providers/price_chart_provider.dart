import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/services/price_chart_service.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';

// ── Selected period state ──────────────────────────────────────────────────
final priceChartPeriodProvider =
    StateProvider<PriceChartPeriod>((ref) => PriceChartPeriod.oneMonth);

// ── Price history for a single token ───────────────────────────────────────
/// Keyed by (symbol, period). Returns cached data instantly if available,
/// otherwise fetches from CoinGecko market_chart API.
final tokenPriceChartProvider = FutureProvider.autoDispose
    .family<List<PricePoint>, (String, PriceChartPeriod)>((ref, params) async {
  final (symbol, period) = params;
  return PriceChartService.instance.fetchPriceHistory(symbol, period);
});

// ── Background prefetch manager ────────────────────────────────────────────
/// Prefetches the default period (1M) for all tokens on app start,
/// then refreshes every 5 minutes while the app is active.
class PriceChartPrefetchManager with WidgetsBindingObserver {
  PriceChartPrefetchManager._();
  static final PriceChartPrefetchManager instance = PriceChartPrefetchManager._();

  Timer? _refreshTimer;
  bool _initialized = false;
  bool _appActive = true;
  WidgetRef? _ref;

  /// Initialize the prefetch manager. Call once from the app's root widget.
  void init(WidgetRef ref) {
    if (_initialized) return;
    _initialized = true;
    _ref = ref;
    WidgetsBinding.instance.addObserver(this);

    // Initial prefetch after 15s — let price refresh (also CoinGecko) finish first
    Future.delayed(const Duration(seconds: 15), () => _doPrefetch());

    // Schedule refresh every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_appActive) _doPrefetch();
    });

    if (kDebugMode) debugPrint('[PriceChart] Prefetch manager initialized');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed ||
                 state == AppLifecycleState.inactive;
    // When coming back to foreground, check if cache expired and refresh
    if (state == AppLifecycleState.resumed) {
      _doPrefetch();
    }
  }

  Future<void> _doPrefetch() async {
    final ref = _ref;
    if (ref == null) return;

    final wallet = ref.read(currentWalletProvider).value;
    if (wallet == null) return;

    // Collect all unique symbols from wallet assets
    final symbols = wallet.assets
        .map((a) => a.symbol.toUpperCase())
        .toSet()
        .toList();

    // Prefetch only default period (1M) — other periods fetched on demand
    await PriceChartService.instance.prefetchDefault(symbols);
  }

  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _initialized = false;
    _ref = null;
  }
}
