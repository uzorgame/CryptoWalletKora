import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/tx_history_service.dart';
import '../../core/state/providers/currency_provider.dart';
import '../../core/state/providers/history_provider.dart';
import '../../core/state/providers/wallet_provider.dart';
import '../history/history_view.dart';

/// Every movement across the wallet.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, required this.entrance});

  final int entrance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(currentWalletProvider).value;
    final money = ref.watch(currencyProvider);
    // Keyed by wallet, so switching wallets cannot briefly show the previous one's movements
    // under the new one's name — a reloading provider hands out its old value, and here that
    // old value would be someone else's money.
    //
    // Named rather than watched inline because the retry below has to invalidate this exact
    // instance: a family provider is a different provider per key, and refreshing the wrong
    // key is a retry button that does nothing.
    final source = wallet == null ? null : walletHistoryProvider(wallet.id);

    // Handed over whole. Unwrapping it here with `valueOrNull ?? const []` — which is what
    // this line used to do — told the view that a rate limit, a missing key and an unreachable
    // chain were a wallet that has never moved.
    final history = source == null ? const AsyncValue<List<TxRecord>>.data([]) : ref.watch(source);

    return HistoryView(
      history: history,
      walletName: wallet?.name ?? 'WALLET',
      money: money,
      entrance: entrance,
      onRetry: source == null ? null : () => ref.invalidate(source),
    );
  }
}
