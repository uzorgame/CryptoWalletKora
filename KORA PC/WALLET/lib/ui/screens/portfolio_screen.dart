import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/asset.dart';
import '../../core/services/portfolio_chart_service.dart';
import '../../core/state/providers/asset_provider.dart';
import '../../core/state/providers/currency_provider.dart';
import '../../core/state/providers/portfolio_chart_provider.dart';
import '../../core/state/providers/wallet_provider.dart';
import '../portfolio/portfolio_view.dart';

/// Connects the portfolio to the providers that already exist.
///
/// Everything here is a read from the app's own state — `visibleAssetsProvider`,
/// `portfolioChartProvider`, `currencyProvider`, `currentWalletProvider`. The view below it
/// takes those objects unchanged; nothing is translated on the way, so there is no second
/// version of the truth to keep in step.
class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({
    super.key,
    required this.entrance,
    required this.onOpenAsset,
    required this.onAddToken,
    required this.onReceive,
  });

  final int entrance;
  final ValueChanged<Asset> onOpenAsset;
  final VoidCallback onAddToken;
  final ValueChanged<Asset> onReceive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(currentWalletProvider).value;
    final assets = ref.watch(sortedAssetsByValueProvider);
    final money = ref.watch(currencyProvider);
    final period = ref.watch(chartPeriodProvider);

    // The curve is keyed by wallet as well as period, so switching wallets cannot show the
    // previous one's history while the new one loads.
    //
    // Named rather than watched inline because the retry below has to invalidate this exact
    // instance: a family provider is a different provider per key, and refreshing the wrong
    // key is a retry button that does nothing.
    final source = wallet == null ? null : portfolioChartProvider((period, wallet.id));

    // Handed over whole. Unwrapping it here with `valueOrNull ?? const []` — which is what
    // this line used to do — drew a wallet whose history the explorer refused to hand over as
    // a wallet that has no history.
    final curve = source == null ? const AsyncValue<List<ChartPoint>>.data([]) : ref.watch(source);

    return PortfolioView(
      walletName: wallet?.name ?? 'WALLET',
      assets: assets,
      curve: curve,
      range: period,
      money: money,
      entrance: entrance,
      onRange: (value) => ref.read(chartPeriodProvider.notifier).state = value,
      onOpenAsset: onOpenAsset,
      onAddToken: onAddToken,
      onReceive: onReceive,
      onRetryCurve: source == null ? null : () => ref.invalidate(source),
    );
  }
}
