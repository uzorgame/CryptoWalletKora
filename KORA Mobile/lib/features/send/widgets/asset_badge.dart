import 'package:flutter/material.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/widgets/chips/coin_icon.dart';
import 'package:kora/features/send/widgets/net_chip.dart';

// The coin icon, name and network of the asset being sent.

class AssetBadge extends StatelessWidget {
  const AssetBadge({super.key, required this.asset});
  final Asset asset;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5)),
    child: Row(children: [
      CoinIcon(symbol: asset.symbol, iconUrl: asset.iconUrl, size: 36),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(asset.symbol,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        NetChip(asset.blockchain),
      ])),
      Text(asset.formattedBalance,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]),
  );
}
