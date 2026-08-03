import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/tx_history_service.dart';
import '../../core/theme/kora_design.dart';
import '../../core/widgets/kora_rise.dart';
import '../common/kora_button.dart';
import '../common/kora_sheet.dart';
import '../../core/state/providers/currency_provider.dart';
import 'movement_row.dart';
import 'movement_sheet.dart';

/// The transaction list, headed and bordered.
///
/// Builds as a sliver, not a box: a wallet can hold hundreds of movements, and a box child is
/// laid out and painted in full however little of it is on screen. Lives on its own because
/// two screens need it — the history page shows every movement in the wallet, a coin's page
/// only its own — so a change to a column happens once.
class MovementTable extends StatelessWidget {
  const MovementTable({
    super.key,
    required this.history,
    required this.walletName,
    required this.money,
    required this.entrance,
    this.onRetry,
    this.emptyMessage = 'NO TRANSACTIONS',
  });

  /// The movements as the provider holds them, loading and failure included.
  ///
  /// Deliberately not a plain list. The screens above used to unwrap this with
  /// `valueOrNull ?? const []`, which handed a rate limit, a missing API key and a chain that
  /// was simply down to this table as the same value as a wallet that has never moved — and
  /// the table then stated NO TRANSACTIONS over all four. A wallet may say that it could not
  /// ask; it may not say that nothing happened when it does not know.
  final AsyncValue<List<TxRecord>> history;

  final String walletName;
  final CurrencyState money;
  final int entrance;

  /// Invalidates whatever provider produced [history]. Null where there is nothing to retry,
  /// which is the case when no wallet is open and so no request was ever made.
  final VoidCallback? onRetry;

  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return DecoratedSliver(
      decoration: BoxDecoration(border: Border.all(color: p.border)),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.bgAlt,
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              child: MovementColumns.row(
                kindCell: _heading(p, 'TYPE'),
                counterpartyCell: _heading(p, 'COUNTERPARTY'),
                amountCell: _heading(p, 'AMOUNT'),
                whenCell: _heading(p, 'WHEN'),
                statusCell: _heading(p, 'STATUS'),
              ),
            ),
          ),
          _body(p),
        ],
      ),
    );
  }

  /// The rows, or an honest account of why there are none.
  Widget _body(Kora p) {
    final rows = history.valueOrNull;

    // The order is the whole point. A reload that still holds rows keeps showing them: the
    // list would otherwise blank to LOADING on every poll, and the rows it would be replacing
    // are still true.
    //
    // A failed reload keeps them for the same reason. Transactions already fetched did not
    // stop having happened because the next poll could not reach the explorer, and replacing a
    // list somebody is reading with an error panel — on a three-minute timer, over a flaky
    // connection — loses their place to report something they cannot act on. The failure is
    // worth the whole frame only when there is nothing behind it.
    if (rows != null && rows.isNotEmpty && (history.isLoading || history.hasError)) {
      return _rows(rows);
    }
    if (history.isLoading) return _message(p, 'LOADING MOVEMENTS…');
    if (history.hasError) return _unreachable(p);
    if (rows == null || rows.isEmpty) return _message(p, emptyMessage);
    return _rows(rows);
  }

  Widget _rows(List<TxRecord> rows) => SliverList.builder(
    itemCount: rows.length,
    itemBuilder: (context, i) => _row(context, rows[i], i),
  );

  Widget _row(BuildContext context, TxRecord transaction, int i) {
    final row = MovementRow(
      transaction: transaction,
      onOpen: () => showKoraSheet(
        context,
        dismissible: true,
        builder: (_) =>
            MovementSheet(transaction: transaction, walletName: walletName, money: money),
      ),
    );

    if (i >= kStaggeredRows) return row;
    return Rise(generation: entrance, delay: kRowStagger * i, duration: kRowRise, child: row);
  }

  /// One quiet line where the rows would be.
  Widget _message(Kora p, String text) =>
      _panel(p, child: Text(text, style: koraLabel(p.text3, size: 10, tracking: 0.16)));

  /// The request failed, which is a different fact from the wallet having no movements, so it
  /// is stated as a different thing — and in brighter ink than the empty message, because this
  /// one has to be read rather than merely noticed. The retry is the only action that can
  /// change it, so it is the only one offered.
  Widget _unreachable(Kora p) => _panel(
    p,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('EXPLORER UNREACHABLE', style: koraLabel(p.text2, size: 11, tracking: 0.18)),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            'The chain could not be reached, so this is not a wallet with no transactions — it '
            'is a wallet that could not ask. Nothing has been lost.',
            textAlign: TextAlign.center,
            style: koraBody(p.text3, size: 12).copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: 18),
        KoraButton(label: 'TRY AGAIN', onPressed: onRetry),
      ],
    ),
  );

  /// A single box adapter, not a column of rows: whatever goes in here replaces the lazy list
  /// rather than joining it, so the table stays one sliver either way.
  Widget _panel(Kora p, {required Widget child}) => SliverToBoxAdapter(
    child: Container(
      color: p.surface,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      alignment: Alignment.center,
      child: child,
    ),
  );

  Widget _heading(Kora p, String text) =>
      Text(text, style: koraLabel(p.text3, size: 9.5, tracking: 0.12));
}
