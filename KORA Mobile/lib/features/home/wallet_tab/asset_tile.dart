import 'package:flutter/material.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/widgets/kora_mask.dart';

// One asset in the wallet tab's list — a hairline table row, not a card.
//
// The symbol leads in tracked mono with the full name grey beside it; the catalog's names
// already carry the network where it matters ("Tether (Tron)"), which is why no separate
// network chip survives here. The 24h move sits with the price, coloured by direction, the
// way the desktop table prints it.
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
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(asset.symbol,
                        style: kLabel(AppColors.textPrimary, size: 12.5, tracking: 0.06)),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(asset.name,
                          overflow: TextOverflow.ellipsis,
                          style: kBody(AppColors.textSecondary, size: 11)),
                    ),
                  ]),
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
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (visible)
              Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(_formatAmount(asset.balanceAsDouble),
                        style: kNum(AppColors.textPrimary, size: 13.5)),
                    const SizedBox(width: 5),
                    Text(asset.symbol,
                        style: kBody(AppColors.textSecondary, size: 10)),
                  ])
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: KoraMask(count: 4, size: 6),
              ),
            const SizedBox(height: 5),
            if (visible)
              Text(currency.formatPrice(asset.balanceInUsd),
                  style: kMonoText(AppColors.textSecondary, size: 10))
            else
              KoraMask(count: 4, size: 5, color: AppColors.textSecondary),
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
