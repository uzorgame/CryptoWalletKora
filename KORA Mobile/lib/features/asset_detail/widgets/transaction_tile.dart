import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/services/tx_history_service.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_rows.dart';
import 'package:kora/features/asset_detail/transaction_details_screen.dart';

// One movement of this asset in its history list — a hairline row, like the desktop's
// movement table. Direction is carried by the word and its colour, so no icon is needed to
// say what "RECEIVED" already says.

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.tx, required this.asset});
  final TxRecord tx;
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final isIn    = tx.direction == TxDirection.incoming;
    final isSelf  = tx.direction == TxDirection.self;
    final color   = isSelf ? AppColors.textSecondary
        : isIn   ? AppColors.positive
        :          AppColors.negative;
    final sign    = isSelf ? '' : isIn ? '+' : '−';
    final amtStr  = '$sign${tx.amount.toStringAsFixed(tx.amount < 0.001 ? 6 : 4)} ${tx.symbol}';
    final kindStr = isSelf ? 'SELF-TRANSFER' : isIn ? 'RECEIVED' : 'SENT';
    final dateStr = DateFormat('MMM d, HH:mm').format(tx.timestamp).toUpperCase();

    // The prototype's row exactly: the direction reads at .krsym size — the same weight the
    // symbol carries in the wallet list, because in a history it is the thing being named.
    return KoraRow(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionDetailsScreen(tx: tx, asset: asset),
      )),
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kindStr, style: kLabel(color, size: 12.5, tracking: 0.06)),
            const SizedBox(height: 4),
            Row(children: [
              Text(dateStr, style: kMonoText(AppColors.textSecondary, size: 10)),
              Text(' · ', style: kMonoText(AppColors.textSecondary, size: 10)),
              if (tx.confirmed)
                Text('CONFIRMED',
                    style: kMonoText(AppColors.textSecondary, size: 10))
              else
                Text('PROCESSING',
                    style: kMonoText(AppColors.warning, size: 10)),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(amtStr, style: kNum(color, size: 13.5)),
          const SizedBox(height: 4),
          Text(tx.shortHash, style: kMonoText(AppColors.textSecondary, size: 10)),
        ]),
      ],
    );
  }
}
