import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';

// Shown for assets whose chain the send flow cannot sign yet.

class UnsupportedBanner extends StatelessWidget {
  const UnsupportedBanner(this.symbol, {super.key});
  final String symbol;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3), width: 0.5)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.construction_rounded, color: AppColors.warning, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(
        'Sending $symbol is not yet supported in this release. '
        'Support for more chains will be added in a future update.',
        style: TextStyle(color: AppColors.warning, fontSize: 12, height: 1.4),
      )),
    ]),
  );
}
