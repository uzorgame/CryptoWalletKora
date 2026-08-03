import 'package:flutter/material.dart';

import '../../core/services/tx_history_service.dart';
import '../../core/theme/kora_design.dart';
import '../format/moment.dart' as moment;
import '../format/money.dart';
import 'transaction_display.dart';

/// The column geometry for the transaction list, shared by its heading and its rows.
class MovementColumns {
  const MovementColumns._();

  static const double kind = 88;
  static const int counterparty = 4;
  static const int amount = 3;
  static const int when = 3;
  static const double status = 92;
  static const double gutter = 12;

  static Widget row({
    required Widget kindCell,
    required Widget counterpartyCell,
    required Widget amountCell,
    required Widget whenCell,
    required Widget statusCell,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        SizedBox(width: kind, child: kindCell),
        const SizedBox(width: gutter),
        Expanded(flex: counterparty, child: counterpartyCell),
        const SizedBox(width: gutter),
        Expanded(
          flex: amount,
          child: Align(alignment: Alignment.centerRight, child: amountCell),
        ),
        const SizedBox(width: gutter),
        Expanded(
          flex: when,
          child: Align(alignment: Alignment.centerRight, child: whenCell),
        ),
        const SizedBox(width: gutter),
        SizedBox(
          width: status,
          child: Align(alignment: Alignment.centerRight, child: statusCell),
        ),
      ],
    ),
  );
}

/// One transaction, as a row.
class MovementRow extends StatefulWidget {
  const MovementRow({super.key, required this.transaction, required this.onOpen});

  final TxRecord transaction;
  final VoidCallback onOpen;

  static const double height = 52;

  @override
  State<MovementRow> createState() => _MovementRowState();
}

class _MovementRowState extends State<MovementRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final t = widget.transaction;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: kHoverFast,
          curve: kEase,
          height: MovementRow.height,
          decoration: BoxDecoration(
            color: _hover ? p.surfaceHi : p.surface,
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: MovementColumns.row(
            kindCell: Text(
              t.incoming ? 'RECEIVED' : 'SENT',
              style: koraLabel(t.incoming ? p.up : p.down, size: 9.5, tracking: 0.12),
            ),
            counterpartyCell: Text(
              shortAddress(t.counterparty),
              style: koraLabel(p.text2, size: 11, tracking: 0),
              overflow: TextOverflow.ellipsis,
            ),
            amountCell: Text(
              '${t.incoming ? '+' : '−'}${quantity(t.amount)} ${t.symbol}',
              style: koraNumeric(p.text, size: 14),
            ),
            whenCell: Text(
              moment.ago(t.timestamp),
              style: koraLabel(p.text3, size: 10, tracking: 0),
            ),
            statusCell: StatusTag(confirmed: t.confirmed),
          ),
        ),
      ),
    );
  }
}

/// Pending is the one state a wallet owner may need to act on, so it is the one that gets a
/// colour. Amber appears nowhere else in the app.
///
/// Two states, not three: the history service reports `confirmed` as a boolean and has no
/// notion of a failed transfer. Offering a "failed" tag the data can never produce would be
/// inventing a state.
class StatusTag extends StatelessWidget {
  const StatusTag({super.key, required this.confirmed});

  final bool confirmed;

  static const Color pending = Color(0xFFD29922);

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final tone = confirmed ? p.text3 : pending;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: confirmed ? p.border : tone.withValues(alpha: 0.35)),
      ),
      child: Text(
        confirmed ? 'CONFIRMED' : 'PENDING',
        style: koraLabel(tone, size: 8.5, tracking: 0.1),
      ),
    );
  }
}
