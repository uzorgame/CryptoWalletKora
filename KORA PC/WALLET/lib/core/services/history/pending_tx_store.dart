import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kora_windows/core/models/tx_record.dart';

// Transactions this app has broadcast that no explorer has reported yet.
//
// Kept on disk rather than in memory: a send is exactly the moment a user is most likely to
// close the window, and a transaction that vanishes from the list until the chain catches up
// looks like a transaction that did not happen.

// ─── Persistent pending-transaction store ───────────────────────────────────────────────────
//
// Pending (“Process”) transactions are saved to SharedPreferences so they
// survive in-memory cache clears and full app restarts. They are removed once the matching
// txHash appears in the live API response — which is the normal path, and the only one that
// means anything about the chain.
class PendingTxStore {
  /// How long an unreported transaction is still shown.
  ///
  /// A backstop for entries no explorer will ever report, not a guess at how long a chain
  /// takes. It was thirty minutes, which is inside the ordinary range for a Bitcoin
  /// transaction at a modest fee: the send vanished from the list with nothing confirmed to
  /// replace it, so the wallet showed neither the money nor the transaction that moved it.
  /// A day is past the point where a transaction is still merely slow.
  static const _timeout = Duration(hours: 24);
  static String _key(String assetId) => 'pending_txs_$assetId';

  /// Persist [tx] for [assetId].
  static Future<void> save(String assetId, TxRecord tx) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = _decode(prefs.getStringList(_key(assetId)));
    final updated = [_encode(tx), ...existing.where((m) => m['hash'] != tx.hash)];
    await prefs.setStringList(_key(assetId), updated.map(jsonEncode).toList());
  }

  /// Load all non-expired pending txs for [assetId].
  static Future<List<TxRecord>> load(String assetId) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _decode(prefs.getStringList(_key(assetId)));
    final now = DateTime.now();
    final valid = items.where((m) {
      final ts = DateTime.tryParse(m['timestamp'] as String? ?? '');
      return ts != null && now.difference(ts) < _timeout;
    }).toList();
    if (valid.length != items.length) {
      // Purge expired entries
      await prefs.setStringList(_key(assetId), valid.map(jsonEncode).toList());
    }
    return valid.map(_toRecord).toList();
  }

  /// Remove txs whose hashes appear in [confirmedHashes].
  static Future<void> removeConfirmed(String assetId, Iterable<String> confirmedHashes) async {
    if (confirmedHashes.isEmpty) return;
    final set = confirmedHashes.toSet();
    final prefs = await SharedPreferences.getInstance();
    final items = _decode(prefs.getStringList(_key(assetId)));
    final pruned = items.where((m) => !set.contains(m['hash'])).toList();
    if (pruned.length != items.length) {
      await prefs.setStringList(_key(assetId), pruned.map(jsonEncode).toList());
    }
  }

  // ── private helpers ────────────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _decode(List<String>? raw) {
    if (raw == null) return [];
    return raw
        .map((s) {
          try {
            return jsonDecode(s) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static Map<String, dynamic> _encode(TxRecord tx) => {
    'hash': tx.hash,
    'from': tx.from,
    'to': tx.to,
    'amount': tx.amount,
    'symbol': tx.symbol,
    'timestamp': tx.timestamp.toIso8601String(),
    'direction': tx.direction.name,
    'blockchain': tx.blockchain,
    'feePaid': tx.feePaid,
  };

  static TxRecord _toRecord(Map<String, dynamic> m) => TxRecord(
    hash: m['hash'] as String,
    from: m['from'] as String? ?? '',
    to: m['to'] as String? ?? '',
    amount: (m['amount'] as num).toDouble(),
    symbol: m['symbol'] as String,
    timestamp: DateTime.parse(m['timestamp'] as String),
    direction: TxDirection.values.firstWhere(
      (d) => d.name == m['direction'],
      orElse: () => TxDirection.outgoing,
    ),
    confirmed: false,
    blockchain: m['blockchain'] as String,
    feePaid: m['feePaid'] != null ? (m['feePaid'] as num).toDouble() : null,
  );
}
