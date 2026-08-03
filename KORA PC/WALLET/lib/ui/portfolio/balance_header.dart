import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';
import '../format/money.dart';

/// The one number the portfolio exists to show, and how it moved today.
class BalanceHeader extends StatelessWidget {
  const BalanceHeader({
    super.key,
    required this.walletName,
    required this.total,
    required this.change24h,
    required this.currencySymbol,
    this.hidden = false,
  });

  final String walletName;
  final double? total;
  final double? change24h;
  final String currencySymbol;

  /// "Hide balances" — the figure is replaced rather than blurred, because a blurred number
  /// still tells a shoulder how many digits it has.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final delta = change24h ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${walletName.toUpperCase()} · TOTAL BALANCE',
              style: koraLabel(p.text3, size: 9.5, tracking: 0.16),
            ),
            const SizedBox(height: 8),
            Text(
              hidden ? '••••••' : money(total, currencySymbol),
              style: koraNumeric(p.text, size: 46, weight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(width: 20),
        if (change24h != null && !hidden)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '${percent(delta)} · 24H',
              style: koraLabel(p.direction(delta), size: 12, tracking: 0),
            ),
          ),
      ],
    );
  }
}
