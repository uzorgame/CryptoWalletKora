import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/tx_history_service.dart';
import '../../core/theme/kora_design.dart';
import '../common/kora_button.dart';
import '../common/kora_sheet.dart';
import '../format/chain_display.dart';
import '../../core/state/providers/currency_provider.dart';
import '../format/currency_format.dart';
import '../format/moment.dart' as moment;
import '../format/money.dart';
import 'movement_row.dart' show StatusTag;
import 'transaction_display.dart';

/// One transaction, in full.
///
/// Every row is something the chain itself told us: what moved, between whom, when, over
/// which network, what the transfer cost, and the hash to check it all against.
///
/// It used to carry PRICE THEN, VALUE THEN, VALUE NOW and SINCE THEN as well. No caller ever
/// had a historical unit price to pass — `TxRecord` does not carry one and nothing looks one
/// up — so all four printed a dash on every transaction the sheet was ever opened for, which
/// is to say the four rows people opened the sheet to read were the four that never said
/// anything. They are gone for the reason AVERAGE COST and PROFIT / LOSS left `CoinFacts`:
/// this is a wallet rather than a trading account, and what it owes the user is an accurate
/// account of what happened, not a verdict on whether it was worth doing.
class MovementSheet extends StatelessWidget {
  const MovementSheet({
    super.key,
    required this.transaction,
    required this.walletName,
    required this.money,
  });

  final TxRecord transaction;
  final String walletName;
  final CurrencyState money;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final t = transaction;
    final chain = ChainDisplay.of(t.blockchain);

    return KoraSheet(
      width: 460,
      title: '${t.incoming ? 'RECEIVED' : 'SENT'} ${t.symbol}',
      subtitle: '${chain.network} · ${chain.tag} · ${walletName.toUpperCase()}',
      body: [
        Center(
          child: Text(
            '${t.incoming ? '+' : '−'}${quantity(t.amount)} ${t.symbol}',
            style: koraNumeric(t.incoming ? p.up : p.down, size: 30, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(border: Border.all(color: p.border)),
          child: Column(
            children: [
              _Row(
                label: 'STATUS',
                trailing: StatusTag(confirmed: t.confirmed),
              ),
              _Row(label: 'DATE', value: '${moment.day(t.timestamp)} · ${moment.ago(t.timestamp)}'),
              // A transfer between the user's own addresses has no counterparty worth naming.
              if (t.isSelfTransfer)
                const _Row(label: 'BETWEEN', value: 'YOUR OWN ADDRESSES')
              else
                _Row(label: t.incoming ? 'FROM' : 'TO', value: t.counterparty),
              _Row(label: 'NETWORK', value: '${chain.network} (${chain.tag})'),
              _Row(
                label: 'NETWORK FEE',
                value: t.incoming ? 'PAID BY SENDER' : money.format(t.feePaid),
              ),
              _Row(label: 'TRANSACTION', value: t.hash, last: true),
            ],
          ),
        ),
      ],
      actions: [
        _CopyButton(value: t.hash),
        KoraButton(
          label: 'DONE',
          expand: true,
          tone: KoraButtonTone.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value, this.trailing, this.last = false});

  final String label;
  final String? value;
  final Widget? trailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: p.surface,
        border: last ? null : Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: koraLabel(p.text3, size: 9, tracking: 0.14)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  trailing ??
                  // No tinted variant any more. The only row that ever took one was SINCE
                  // THEN, and colour here would have to mean something — this sheet reports
                  // what happened, and none of what is left has a direction to signal.
                  Text(
                    value ?? '—',
                    textAlign: TextAlign.right,
                    style: koraLabel(p.text, size: 11, tracking: 0),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Copying is the whole reason a hash is shown, so the button says whether it worked.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.value});

  final String value;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) => KoraButton(
    label: _copied ? 'COPIED' : 'COPY HASH',
    expand: true,
    onPressed: () async {
      await Clipboard.setData(ClipboardData(text: widget.value));
      if (!mounted) return;
      setState(() => _copied = true);
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) setState(() => _copied = false);
    },
  );
}
