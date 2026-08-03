import 'package:flutter/material.dart';
import 'package:kora/features/send/chain_labels.dart';
import 'package:kora/core/theme/app_theme.dart';

// The small network tag beside an asset's name.

class NetChip extends StatelessWidget {
  const NetChip(this.blockchain, {super.key});
  final String blockchain;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(5)),
    child: Text(netLabel(blockchain),
        style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}
