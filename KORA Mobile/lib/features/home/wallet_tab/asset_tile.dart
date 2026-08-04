import 'package:flutter/material.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/widgets/kora_mask.dart';
import 'package:kora/core/widgets/kora_rows.dart';

// One asset in the wallet tab's list — a hairline table row, not a card.
//
// The ticker sits in a box at the head of the row and the full name reads beside it, so
// the asset is named once instead of three times. The catalog's names carry the network
// where it matters ("Tether (Tron)"). The 24h move sits with the price, coloured by
// direction, the way the desktop table prints it.
class AssetTile extends StatelessWidget {
  const AssetTile({super.key, required this.asset, required this.visible,
      required this.currency, required this.onTap});
  final Asset asset;
  final bool visible;
  final CurrencyState currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUp = asset.priceChange24h >= 0;
    final sign = isUp ? '+' : '−';

    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.98,
      pressOpacity: 0.85,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: kHairlineSide())),
        child: Row(children: [
          KoraSymbolBox(asset.symbol),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asset.name,
                  overflow: TextOverflow.ellipsis,
                  style: kLabel(AppColors.textPrimary, size: 12.5, tracking: 0.06)),
              const SizedBox(height: 5),
              Row(children: [
                Text(currency.formatPrice(asset.priceUsd),
                    style: kMonoText(AppColors.textSecondary, size: 10)),
                Text(' · ', style: kMonoText(AppColors.textTertiary, size: 10)),
                Text('$sign${asset.priceChange24h.abs().toStringAsFixed(2)}%',
                    style: kMonoText(
                        isUp ? AppColors.positive : AppColors.negative, size: 10)),
              ]),
            ]),
          ),
          // Each hidden figure keeps the exact line box of the figure it replaces, so the
          // whole list stays still when balances are hidden.
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            SizedBox(
              height: 13.5 * kTextScale * 1.35,
              child: Align(
                alignment: Alignment.centerRight,
                // No ticker after the figure: the box at the head of the row already
                // names it, and a third mention was the duplication this row started with.
                child: visible
                    ? Text(_formatAmount(asset.balanceAsDouble),
                        style: kNum(AppColors.textPrimary, size: 13.5))
                    : const KoraMask(count: 4, textSize: 13.5 * kTextScale),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 10 * kTextScale * 1.35,
              child: Align(
                alignment: Alignment.centerRight,
                child: visible
                    ? Text(currency.formatPrice(asset.balanceInUsd),
                        style: kMonoText(AppColors.textSecondary, size: 10))
                    : KoraMask(count: 4, textSize: 10 * kTextScale,
                        color: AppColors.textSecondary),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  static String _formatAmount(double value) {
    if (value == 0) return '0';
    if (value < 0.000001) return '< 0.000001';
    if (value >= 1000000) return value.toStringAsFixed(0);
    if (value >= 1000) return value.toStringAsFixed(2);
    final s = value.toStringAsFixed(6);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
