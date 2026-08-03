import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/smooth_scroll.dart';

import '../../core/models/asset.dart';
import '../../core/services/portfolio_chart_service.dart';
import '../../core/theme/kora_design.dart';
import '../common/section_header.dart';
import '../common/segmented_control.dart';
import '../../core/state/providers/currency_provider.dart';
import '../format/currency_format.dart';
import '../format/money.dart';
import 'asset_table.dart';
import 'balance_header.dart';
import 'empty_wallet.dart';
import 'portfolio_chart.dart';

/// What the change beside the range control is measured over, in words.
extension ChartPeriodSpoken on ChartPeriod {
  String get spoken => this == ChartPeriod.year ? 'the year' : label;
}

/// The first screen: what the wallet is worth, how it got there, and what is in it.
///
/// Sending and receiving are not here. There is no answer to "send what?" until a coin is
/// chosen, so both actions live on the coin's own page.
class PortfolioView extends StatelessWidget {
  const PortfolioView({
    super.key,
    required this.walletName,
    required this.assets,
    required this.curve,
    required this.range,
    required this.money,
    required this.entrance,
    required this.onRange,
    required this.onOpenAsset,
    required this.onAddToken,
    required this.onReceive,
    this.onRetryCurve,
    this.hideBalances = false,
  });

  final String walletName;

  /// Straight from `visibleAssetsProvider` — the same objects the rest of the app works with.
  final List<Asset> assets;

  /// Passed to the chart unopened, so that a request the explorer refused is not drawn as a
  /// wallet with no past.
  final AsyncValue<List<ChartPoint>> curve;

  final ChartPeriod range;
  final CurrencyState money;
  final int entrance;

  final ValueChanged<ChartPeriod> onRange;
  final ValueChanged<Asset> onOpenAsset;
  final VoidCallback onAddToken;
  final ValueChanged<Asset> onReceive;

  final VoidCallback? onRetryCurve;

  final bool hideBalances;

  /// What the portfolio is worth, or null when that is not yet known.
  ///
  /// Zero is a real answer only for a wallet that holds nothing. A wallet holding coins whose
  /// prices have not arrived also sums to zero, and printing $0.00 over a funded wallet says
  /// the money is gone. The dash says "not yet", which is what is actually true.
  double? get _totalUsd {
    final total = assets.fold<double>(0, (sum, asset) => sum + asset.balanceInUsd);
    if (total > 0) return total;
    return assets.any((a) => a.balanceAsDouble > 0) ? null : 0;
  }

  /// The change over the period the curve is showing, not a separate figure that could
  /// disagree with the line above it. Takes the drawn points rather than reading [curve], so
  /// that a figure cannot be quoted for a curve the chart is not showing.
  double? _rangeChange(List<ChartPoint> points) {
    if (points.length < 2) return null;
    final first = points.first.value;
    if (first == 0) return null;
    return (points.last.value / first - 1) * 100;
  }

  double? get _change24h {
    var now = 0.0;
    var before = 0.0;
    for (final asset in assets) {
      if (asset.balanceInUsd == 0) continue;
      now += asset.balanceInUsd;
      before += asset.balanceInUsd / (1 + asset.priceChange24h / 100);
    }
    return before == 0 ? null : (now / before - 1) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final points = curve.valueOrNull ?? const <ChartPoint>[];
    // Emptiness is a fact about the balances, not about whether prices have loaded — and not
    // about whether the curve arrived either, which is why a failed request is left to the
    // chart to report rather than being dressed up here as a wallet that holds nothing.
    final empty = points.length < 2 && assets.every((a) => a.balanceAsDouble <= 0);
    final change = _rangeChange(points);

    return SmoothScrollView(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BalanceHeader(
            walletName: walletName,
            total: _totalUsd == null ? null : money.convert(_totalUsd!),
            change24h: _change24h,
            currencySymbol: money.symbol,
            hidden: hideBalances,
          ),
          const SizedBox(height: 20),
          if (empty)
            EmptyWallet(
              symbol: assets.isEmpty ? 'BTC' : assets.first.symbol,
              // Guarded on both sides: naming a fallback symbol while still reaching for
              // assets.first would crash on the one case the fallback exists for.
              onReceive: assets.isEmpty ? onAddToken : () => onReceive(assets.first),
            )
          else ...[
            PortfolioChart(series: curve, currencySymbol: money.symbol, onRetry: onRetryCurve),
            const SizedBox(height: 20),
            Row(
              children: [
                SegmentedControl(
                  options: [for (final r in ChartPeriod.values) r.label],
                  selected: range.label,
                  onSelect: (label) =>
                      onRange(ChartPeriod.values.firstWhere((r) => r.label == label)),
                ),
                const SizedBox(width: 16),
                if (change != null)
                  Text(
                    '${percent(change)} over ${range.spoken}',
                    style: koraLabel(p.direction(change), size: 12, tracking: 0),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SectionHeader(
            title: 'ASSETS',
            action: _AddTokenButton(onTap: onAddToken),
          ),
          const SizedBox(height: 20),
          AssetTable(
            assets: assets,
            money: money,
            entrance: entrance,
            hidden: hideBalances,
            onOpen: onOpenAsset,
          ),
        ],
      ),
    );
  }
}

class _AddTokenButton extends StatefulWidget {
  const _AddTokenButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddTokenButton> createState() => _AddTokenButtonState();
}

class _AddTokenButtonState extends State<_AddTokenButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedDefaultTextStyle(
          duration: kControl,
          curve: kEase,
          style: koraLabel(_hover ? p.text : p.text3, size: 9.5, tracking: 0.14),
          child: const Text('+ ADD TOKEN'),
        ),
      ),
    );
  }
}
