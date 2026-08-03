import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/smooth_scroll.dart';

import '../../core/services/tx_history_service.dart';
import '../common/section_header.dart';
import '../../core/state/providers/currency_provider.dart';
import 'movement_table.dart';

/// Every movement in the open wallet, newest first.
class HistoryView extends StatelessWidget {
  const HistoryView({
    super.key,
    required this.history,
    required this.walletName,
    required this.money,
    required this.entrance,
    this.onRetry,
  });

  /// Passed on to the table unopened. Loading and failure are states this page has to show,
  /// not states to be flattened into an empty list on the way down.
  final AsyncValue<List<TxRecord>> history;

  final String walletName;
  final CurrencyState money;
  final int entrance;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final rows = history.valueOrNull;

    return SmoothScrollView.slivers(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'TRANSACTIONS',
                // Counted only once there is something to count. '0 TOTAL' beside a request
                // that has not answered, or has failed, is the same false statement the table
                // beneath it used to make, made in smaller type.
                aside: rows == null
                    ? walletName.toUpperCase()
                    : '${walletName.toUpperCase()} · ${rows.length} TOTAL',
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        MovementTable(
          history: history,
          walletName: walletName,
          money: money,
          entrance: entrance,
          onRetry: onRetry,
        ),
      ],
    );
  }
}
