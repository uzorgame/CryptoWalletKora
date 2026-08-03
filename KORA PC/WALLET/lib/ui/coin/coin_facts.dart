import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';
import '../format/money.dart';

/// Four figures about a holding, in one band.
///
/// Four, not five: the movement table sits directly beneath this and its first row is the
/// most recent movement, so a LAST MOVED cell repeated what was already twenty pixels below
/// while squeezing the four figures that were not shown anywhere else.
///
/// Every one of them is something the wallet actually knows: how much is held, what one unit
/// is worth, what the holding is worth, and which chain it is on.
///
/// This band used to carry AVERAGE COST and PROFIT / LOSS. Both were removed, and for the
/// same reason: `TxRecord` has no price at the time of the movement, so there was nothing to
/// average and nothing to compare against. They rendered as two permanent dashes. A wallet is
/// also not a trading account — what it owes the user is an accurate statement of what is
/// there, not a verdict on whether holding it was a good idea.
class CoinFacts extends StatelessWidget {
  const CoinFacts({
    super.key,
    required this.quantityHeld,
    required this.price,
    required this.value,
    required this.network,
    required this.currencySymbol,
  });

  final double quantityHeld;
  final double? price;
  final double? value;

  /// The chain this holding lives on — 'Tron (TRC20)'. The single most consequential fact on
  /// the page: the same ticker on the wrong chain is a different asset and an unrecoverable
  /// transfer.
  final String network;

  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    final facts = <(String, String)>[
      ('HOLDINGS', quantity(quantityHeld)),
      ('PRICE', money(price, currencySymbol)),
      ('VALUE', money(value, currencySymbol)),
      ('NETWORK', network),
    ];

    return Container(
      decoration: BoxDecoration(color: p.border, border: Border.all(color: p.border)),
      child: Row(
        children: [
          for (final (i, fact) in facts.indexed) ...[
            if (i > 0) const SizedBox(width: 1),
            Expanded(
              child: Container(
                color: p.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(fact.$1, style: koraLabel(p.text3, size: 9, tracking: 0.14)),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(fact.$2, style: koraNumeric(p.text, size: 20)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
