import 'package:kora_windows/core/models/asset.dart';
import 'package:kora_windows/core/models/tx_record.dart';
import 'package:kora_windows/core/utils/constants.dart';

// A short-lived in-memory cache of fetched histories.
//
// Keyed by chain, asset and address, so it cannot serve one wallet's history to another —
// for a token the address held here is the wallet's own, not the token's contract.

// ─── History TTL cache (in-memory, 10 min) ────────────────────────────────────────────
class _CachedHist {
  final List<TxRecord> records;
  final DateTime ts;
  _CachedHist(this.records) : ts = DateTime.now();
  bool get valid => DateTime.now().difference(ts) < AppConstants.historyCacheExpiration;
}

final _histCache = <String, _CachedHist>{}; // key: "blockchain:assetId:address"

/// Returns cached history for [asset] if still valid (< 1 h old).
List<TxRecord>? getCachedHistory(Asset asset) {
  final key = '${asset.blockchain}:${asset.id}:${asset.contractAddress}';
  final cached = _histCache[key];
  return (cached != null && cached.valid) ? cached.records : null;
}

/// Stores [records] in the history cache.
void setCachedHistory(Asset asset, List<TxRecord> records) {
  final key = '${asset.blockchain}:${asset.id}:${asset.contractAddress}';
  _histCache[key] = _CachedHist(records);
}

/// Removes the cached history for [asset] so the next load forces a fresh fetch.
void invalidateCachedHistory(Asset asset) {
  final key = '${asset.blockchain}:${asset.id}:${asset.contractAddress}';
  _histCache.remove(key);
}
