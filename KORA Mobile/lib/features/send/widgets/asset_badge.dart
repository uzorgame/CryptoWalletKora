import 'package:flutter/material.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/features/send/widgets/net_chip.dart';

// The coin icon, name and network of the asset being sent.

class AssetBadge extends StatelessWidget {
  const AssetBadge({super.key, required this.asset});
  final Asset asset;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(color: AppColors.surface, border: kHairline()),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(asset.symbol,
                  style: kLabel(AppColors.textPrimary, size: 12.5, tracking: 0.06)),
              const SizedBox(width: 7),
              Flexible(child: Text(asset.name,
                  overflow: TextOverflow.ellipsis,
                  style: kBody(AppColors.textSecondary, size: 11))),
            ]),
        const SizedBox(height: 5),
        Text('BALANCE ' + asset.formattedBalance.toUpperCase(),
            style: kMonoText(AppColors.textSecondary, size: 9.5)),
      ])),
      NetChip(asset.blockchain),
    ]),
  );
}
