import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/asset.dart';
import '../../services/tx_history_service.dart';
import 'asset_provider.dart';

/// What a history request actually depends on.
///
/// Not the asset object, and emphatically not the asset list. `assetsProvider` hands out a
/// fresh `List` on every read, and a Riverpod `Provider` notifies when `previous != next` —
/// which for a List is identity. So every balance write, every price tick and every optimistic
/// update produced a "new" list, invalidated every history, and re-ran the whole network
/// fan-out. On a wallet with two funded coins that is a pair of explorer calls every few
/// seconds, for the lifetime of the app.
///
/// A history changes when the address or the contract changes, and at no other time. Keying on
/// exactly that is what makes the invalidations stop.
@immutable
class _HistoryKey {
  const _HistoryKey(this.address, this.contract, this.balance);

  final String address;
  final String? contract;

  /// The coin balance, as stored — the string, not a parsed double.
  ///
  /// This is what makes the history refresh at the right moment and only then. A movement is
  /// precisely a thing that changes the balance, so when the balance changes there is
  /// something new to fetch, and when it does not there is not. Price ticks do not touch it.
  ///
  /// Without this the provider was fetched once and never again: it is not autoDispose, so
  /// nothing re-ran it, and a transaction sent from the app would never appear in the list
  /// until the next launch.
  final String balance;

  @override
  bool operator ==(Object other) =>
      other is _HistoryKey &&
      other.address == address &&
      other.contract == contract &&
      other.balance == balance;

  @override
  int get hashCode => Object.hash(address, contract, balance);
}

/// The address a chain's history is read against, and the contract to filter by.
///
/// A token has no address of its own — its movements are recorded against the native coin's
/// address on the same chain — which is why this needs the sibling assets to resolve.
_HistoryKey? _keyFor(List<Asset> assets, String assetId) {
  final asset = assets.where((a) => a.id == assetId).firstOrNull;
  if (asset == null) return null;
  if (asset.type == AssetType.native) {
    return _HistoryKey(asset.contractAddress, null, asset.balance);
  }

  final native = assets
      .where((a) => a.blockchain == asset.blockchain && a.type == AssetType.native)
      .firstOrNull;
  return _HistoryKey(
    native?.contractAddress ?? asset.contractAddress,
    asset.contractAddress,
    asset.balance,
  );
}

/// The balance each asset had when its history was last fetched, per wallet.
///
/// Used only to tell "the provider re-ran because funds moved" from "the provider ran for the
/// first time". The service's own cache is skipped in the first case and used in the second.
///
/// Keyed by wallet as well as asset. Asset ids repeat across wallets, so keyed by asset alone
/// every switch looked like a balance change on every coin — which skipped the cache and
/// refetched the whole wallet from every explorer, on a screen the user had merely switched to.
final Map<String, String> _lastSeenBalance = {};

/// Assets this session has seen movements for.
///
/// A coin's history does not stop existing when its balance reaches zero — sending everything
/// is precisely when the user most wants to see the transaction. The wallet-wide list used to
/// be built from funded coins alone, so emptying a coin removed it from the list, taking the
/// send that emptied it with it.
final Set<String> _everMoved = {};

/// One asset's movements, from the chain.
///
/// Keyed by wallet as well as asset. That is not redundancy: keyed by asset alone, opening a
/// second wallet would reuse the same provider instance, and Riverpod hands a reloading
/// provider its PREVIOUS value — so the new wallet's history page would show the old wallet's
/// transactions until the fetch returned. A separate key per wallet has no previous value to
/// show.
///
/// Deliberately not autoDispose: leaving a coin page and coming back is an ordinary thing to
/// do, and it should not cost two explorer round-trips each time. The family is bounded by
/// wallets × assets, both small.
final assetHistoryProvider =
    FutureProvider.family<List<TxRecord>, (String walletId, String assetId)>((ref, key) async {
      final (walletId, assetId) = key;
      final seenKey = '$walletId|$assetId';

      // `select` is what keeps this subscribed to the address and the balance rather than to the
      // whole list. The callback re-runs on every asset change, but the provider is only
      // invalidated when the value it returns actually differs.
      final watched = ref.watch(assetsProvider.select((assets) => _keyFor(assets, assetId)));
      if (watched == null) return const [];

      final assets = ref.read(assetsProvider);
      final asset = assets.firstWhere((a) => a.id == assetId);

      // The service's hour-long cache is only trusted while the balance is unchanged. Re-running
      // with a different balance means funds moved, and seeing the movement is the whole point of
      // the refetch — an hour-old list would hide the very transaction that triggered it.
      final moved =
          _lastSeenBalance[seenKey] != null && _lastSeenBalance[seenKey] != watched.balance;
      _lastSeenBalance[seenKey] = watched.balance;

      final cached = moved ? null : getCachedHistory(asset);
      final confirmed = cached ?? await fetchHistoryForAsset(asset: asset, walletAssets: assets);
      if (cached == null) setCachedHistory(asset, confirmed);
      if (confirmed.isNotEmpty) _everMoved.add(seenKey);

      // Anything already broadcast but not yet in a block will not come back from the chain for a
      // block or two. Merging it in means the user sees what they just sent, instead of a list
      // that looks as though it never happened.
      final pending = await PendingTxStore.load(asset.id);
      final seen = {for (final tx in confirmed) tx.hash};
      await PendingTxStore.removeConfirmed(asset.id, seen);

      return [...pending.where((tx) => !seen.contains(tx.hash)), ...confirmed];
    });

/// Every movement across the wallet, newest first.
///
/// Fetched per asset and merged here rather than by a single call, because each chain has its
/// own explorer and there is no endpoint that knows about all of them at once.
final walletHistoryProvider = FutureProvider.family<List<TxRecord>, String>((ref, walletId) async {
  // Only the ids. A coin is worth asking about if it holds something, or if it has already
  // told us it has a history: sending a whole balance used to drop that coin below the
  // filter on the very refresh the send triggered, so the transaction the user was waiting
  // to see removed its own row. Watching the asset list itself would put this
  // back on the every-tick treadmill the key above exists to get off; a `List<String>` under
  // `select` is compared with `==`, so it is joined into one string, which compares by value.
  final ids = ref.watch(
    assetsProvider.select(
      (assets) => [
        for (final a in assets)
          if (a.isVisible && (a.balanceAsDouble > 0 || _everMoved.contains('$walletId|${a.id}')))
            a.id,
      ].join(' '),
    ),
  );

  if (ids.isEmpty) return const [];

  // One chain's explorer being down is not the wallet's history being unavailable — but every
  // chain being down is.
  //
  // Future.wait fails the whole set on the first rejection, so a single unreachable explorer
  // turned every other chain's movements — already fetched — into an error page. Catching each
  // one separately fixes that, and taken alone it introduces the opposite lie: with nothing
  // reachable, every chain contributes an empty list and the page reports, calmly, that this
  // wallet has no transactions. So a failure is only swallowed while something else answered.
  final chains = ids.split(' ');
  final failures = <Object>[];
  final histories = await Future.wait([
    for (final id in chains)
      ref.watch(assetHistoryProvider((walletId, id)).future).catchError((Object error) {
        failures.add(error);
        return const <TxRecord>[];
      }),
  ]);

  if (failures.length == chains.length) throw failures.first;

  return [for (final history in histories) ...history]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
});
