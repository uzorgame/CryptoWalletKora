import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/services/tx_history_service.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
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

    return AnimatedTap(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionDetailsScreen(tx: tx, asset: asset),
      )),
      pressScale: 0.98,
      pressOpacity: 0.85,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: kHairlineSide())),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kindStr, style: kLabel(color, size: 10.5, tracking: 0.12)),
              const SizedBox(height: 5),
              Row(children: [
                Text(dateStr, style: kMonoText(AppColors.textTertiary, size: 9.5)),
                Text(' · ', style: kMonoText(AppColors.textTertiary, size: 9.5)),
                if (tx.confirmed)
                  Text('CONFIRMED',
                      style: kMonoText(AppColors.textTertiary, size: 9.5))
                else
                  Text('PROCESSING',
                      style: kMonoText(AppColors.warning, size: 9.5)),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(amtStr, style: kNum(color, size: 13)),
            const SizedBox(height: 5),
            Text(tx.shortHash, style: kMonoText(AppColors.textTertiary, size: 9.5)),
          ]),
        ]),
      ),
    );
  }
}
