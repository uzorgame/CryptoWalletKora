import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/asset.dart';
import '../../core/services/tx_history_service.dart';
import '../../core/state/providers/currency_provider.dart';
import '../../core/state/providers/history_provider.dart';
import '../../core/state/providers/wallet_provider.dart';
import '../coin/coin_view.dart';

/// One coin: what is held, what it is worth, and where it has moved.
class CoinScreen extends ConsumerWidget {
  const CoinScreen({
    super.key,
    required this.asset,
    required this.entrance,
    required this.onBack,
    required this.onSend,
    required this.onReceive,
  });

  final Asset asset;
  final int entrance;
  final VoidCallback onBack;
  final VoidCallback onSend;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(currentWalletProvider).value;
    final money = ref.watch(currencyProvider);
    // Keyed by wallet as well as asset — see the provider. Without the wallet in the key, the
    // page would show the previous wallet's movements for the moment after a switch.
    //
    // Named rather than watched inline because the retry below has to invalidate this exact
    // instance: a family provider is a different provider per key, and refreshing the wrong
    // key is a retry button that does nothing.
    final source = wallet == null ? null : assetHistoryProvider((wallet.id, asset.id));

    // Handed over whole. Unwrapping it here with `valueOrNull ?? const []` — which is what
    // this line used to do — told the page that an explorer refusing the request was a coin
    // that has never moved.
    final history = source == null ? const AsyncValue<List<TxRecord>>.data([]) : ref.watch(source);

    return CoinView(
      asset: asset,
      history: history,
      walletName: wallet?.name ?? 'WALLET',
      money: money,
      entrance: entrance,
      onBack: onBack,
      onSend: onSend,
      onReceive: onReceive,
      onRetryHistory: source == null ? null : () => ref.invalidate(source),
    );
  }
}
