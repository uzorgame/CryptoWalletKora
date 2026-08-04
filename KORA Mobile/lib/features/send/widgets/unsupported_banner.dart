import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';

// Shown for assets whose chain the send flow cannot sign yet.

class UnsupportedBanner extends StatelessWidget {
  const UnsupportedBanner(this.symbol, {super.key});
  final String symbol;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: AppColors.warning, width: 2),
        top: kHairlineSide(), right: kHairlineSide(), bottom: kHairlineSide(),
      ),
    ),
    child: Text(
      'SENDING $symbol IS NOT YET SUPPORTED IN THIS RELEASE. '
      'SUPPORT FOR MORE CHAINS WILL BE ADDED IN A FUTURE UPDATE.',
      style: kLabel(AppColors.warning, size: 9, tracking: 0.08, weight: FontWeight.w400)
          .copyWith(height: 1.8),
    ),
  );
}
