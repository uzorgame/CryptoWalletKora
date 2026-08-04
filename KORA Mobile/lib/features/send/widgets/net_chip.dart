import 'package:flutter/material.dart';
import 'package:kora/features/send/chain_labels.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';

// The small network tag beside an asset's name.

class NetChip extends StatelessWidget {
  const NetChip(this.blockchain, {super.key});
  final String blockchain;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(border: kHairline()),
    child: Text(netLabel(blockchain).toUpperCase(),
        style: kLabel(AppColors.textTertiary, size: 8, tracking: 0.1)),
  );
}
