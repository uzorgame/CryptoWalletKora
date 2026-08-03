import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/services/tx_history_service.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/features/asset_detail/transaction_details_screen.dart';

// One movement of this asset in its history list.

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
    final amtStr  = '${sign}${tx.amount.toStringAsFixed(tx.amount < 0.001 ? 6 : 4)} ${tx.symbol}';
    final dateStr = DateFormat('MMM d, HH:mm').format(tx.timestamp);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionDetailsScreen(tx: tx, asset: asset),
      )),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        // Direction icon
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isSelf ? Icons.sync_rounded
                : isIn ? Icons.arrow_downward_rounded
                :        Icons.arrow_upward_rounded,
            color: color, size: 18,
          ),
        ),
        const SizedBox(width: 12),
        // Hash + date
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx.shortHash,
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(dateStr,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ])),
        // Amount + confirmation
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(amtStr,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          if (tx.confirmed)
            Text('Confirmed',
                style: TextStyle(color: AppColors.positive, fontSize: 11))
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 9, height: 9,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Color(0xFF2196F3)),
              ),
              const SizedBox(width: 4),
              Text('Processing',
                  style: TextStyle(color: Color(0xFF2196F3), fontSize: 11)),
            ]),
        ]),
      ]),
    ),
    );
  }
}
