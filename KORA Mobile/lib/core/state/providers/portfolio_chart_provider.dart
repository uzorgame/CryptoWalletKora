import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/services/portfolio_chart_service.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';

final chartPeriodProvider = StateProvider<ChartPeriod>((ref) => ChartPeriod.week);

/// Keyed by (period, walletId) so each wallet gets its own isolated cache.
final portfolioChartProvider = FutureProvider.autoDispose
    .family<List<ChartPoint>, (ChartPeriod, String)>((ref, params) async {
  final (period, walletId) = params;
  final wallet = ref.watch(currentWalletProvider).value;
  // Safety: if provider is called for a stale wallet id, return empty
  if (wallet == null || wallet.id != walletId) return [];
  return PortfolioChartService.fetchPortfolioHistory(
    assets: wallet.assets,
    period: period,
    walletId: walletId,
    allAssets: wallet.assets,
  );
});
