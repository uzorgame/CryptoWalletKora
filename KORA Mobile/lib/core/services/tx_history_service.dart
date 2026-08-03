import 'dart:convert';
import 'dart:io';
import 'dart:math' show pow;
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/constants/token_catalog.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/utils/constants.dart';


// ─── BCH CashAddr → legacy address converter ────────────────────────────────

/// Converts a BCH CashAddr address (bare `q...` or with `bitcoincash:` prefix)
/// to a Base58Check legacy address (`1...` P2PKH or `3...` P2SH).
/// Returns the input unchanged if it is already legacy or conversion fails.
String _bchToLegacy(String addr) {
  try {
    if (addr.isEmpty) return addr;
    // Already legacy — starts with 1 (P2PKH) or 3 (P2SH)
    if (addr.startsWith('1') || addr.startsWith('3')) return addr;
    // Strip optional prefix and lowercase
    var raw = addr.toLowerCase();
    if (raw.startsWith('bitcoincash:')) raw = raw.substring('bitcoincash:'.length);
    // Map CashAddr charset to 5-bit values
    const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final data5 = <int>[];
    for (final ch in raw.runes) {
      final idx = charset.indexOf(String.fromCharCode(ch));
      if (idx < 0) return addr; // not a valid CashAddr char
      data5.add(idx);
    }
    // Last 8 5-bit groups are the checksum — drop them
    if (data5.length < 9) return addr;
    final payload5 = data5.sublist(0, data5.length - 8);
    // Convert 5-bit groups → 8-bit bytes (standard bit-converter, no padding)
    int acc = 0, bits = 0;
    final data8 = <int>[];
    for (final v in payload5) {
      acc = (acc << 5) | v;
      bits += 5;
      while (bits >= 8) {
        bits -= 8;
        data8.add((acc >> bits) & 0xff);
      }
    }
    if (data8.length < 21) return addr;
    // First byte = CashAddr version (0x00 = P2PKH, 0x08 = P2SH)
    final version = data8[0];
    final hash160 = data8.sublist(1, 21);
    final int legacyVersion;
    if (version == 0x00) {
      legacyVersion = 0x00; // P2PKH → '1...'
    } else if (version == 0x08) {
      legacyVersion = 0x05; // P2SH  → '3...'
    } else {
      return addr;
    }
    // Base58Check encode: [legacyVersion, ...hash160, ...checksum4]
    final payload = Uint8List(21)..[0] = legacyVersion;
    for (var i = 0; i < 20; i++) payload[i + 1] = hash160[i];
    final h1 = crypto.sha256.convert(payload).bytes;
    final h2 = crypto.sha256.convert(h1).bytes;
    final full = Uint8List(25);
    full.setRange(0, 21, payload);
    full.setRange(21, 25, h2.sublist(0, 4));
    return _bchBase58Encode(full);
  } catch (_) {
    return addr;
  }
}

String _bchBase58Encode(Uint8List bytes) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  var value = BigInt.zero;
  for (final b in bytes) {
    value = value * BigInt.from(256) + BigInt.from(b);
  }
  var result = '';
  while (value > BigInt.zero) {
    final rem = (value % BigInt.from(58)).toInt();
    value = value ~/ BigInt.from(58);
    result = alphabet[rem] + result;
  }
  for (final b in bytes) {
    if (b == 0) { result = '1$result'; } else { break; }
  }
  return result;
}

// ─── History TTL cache (in-memory, 10 min) ────────────────────────────────────────────
class _CachedHist {
  final List<TxRecord> records;
  final DateTime ts;
  _CachedHist(this.records) : ts = DateTime.now();
  bool get valid => DateTime.now().difference(ts) < AppConstants.historyCacheExpiration;
}
final _histCache = <String, _CachedHist>{};  // key: "blockchain:assetId:address"

/// Returns cached history for [asset] if still valid (< 1 h old).
List<TxRecord>? getCachedHistory(Asset asset) {
  final key    = '${asset.blockchain}:${asset.id}:${asset.contractAddress}';
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

// ─── Persistent pending-transaction store ───────────────────────────────────────────────────
//
// Pending (“Process”) transactions are saved to SharedPreferences so they
// survive in-memory cache clears and full app restarts.  They are removed once
// the matching txHash appears in the live API response, or after 30 minutes.
class PendingTxStore {
  static const _timeout = Duration(minutes: 30);
  static String _key(String assetId) => 'pending_txs_$assetId';

  /// Persist [tx] for [assetId].
  static Future<void> save(String assetId, TxRecord tx) async {
    final prefs    = await SharedPreferences.getInstance();
    final existing = _decode(prefs.getStringList(_key(assetId)));
    final updated  = [_encode(tx), ...existing.where((m) => m['hash'] != tx.hash)];
    await prefs.setStringList(_key(assetId), updated.map(jsonEncode).toList());
  }

  /// Load all non-expired pending txs for [assetId].
  static Future<List<TxRecord>> load(String assetId) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _decode(prefs.getStringList(_key(assetId)));
    final now   = DateTime.now();
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
  static Future<void> removeConfirmed(
      String assetId, Iterable<String> confirmedHashes) async {
    if (confirmedHashes.isEmpty) return;
    final set    = confirmedHashes.toSet();
    final prefs  = await SharedPreferences.getInstance();
    final items  = _decode(prefs.getStringList(_key(assetId)));
    final pruned = items.where((m) => !set.contains(m['hash'])).toList();
    if (pruned.length != items.length) {
      await prefs.setStringList(_key(assetId), pruned.map(jsonEncode).toList());
    }
  }

  // ── private helpers ────────────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _decode(List<String>? raw) {
    if (raw == null) return [];
    return raw
        .map((s) { try { return jsonDecode(s) as Map<String, dynamic>; } catch (_) { return null; } })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static Map<String, dynamic> _encode(TxRecord tx) => {
    'hash':       tx.hash,
    'from':       tx.from,
    'to':         tx.to,
    'amount':     tx.amount,
    'symbol':     tx.symbol,
    'timestamp':  tx.timestamp.toIso8601String(),
    'direction':  tx.direction.name,
    'blockchain': tx.blockchain,
    'feePaid':    tx.feePaid,
  };

  static TxRecord _toRecord(Map<String, dynamic> m) => TxRecord(
    hash:       m['hash']       as String,
    from:       m['from']       as String? ?? '',
    to:         m['to']         as String? ?? '',
    amount:     (m['amount']    as num).toDouble(),
    symbol:     m['symbol']     as String,
    timestamp:  DateTime.parse(m['timestamp'] as String),
    direction:  TxDirection.values.firstWhere(
        (d) => d.name == m['direction'], orElse: () => TxDirection.outgoing),
    confirmed:  false,
    blockchain: m['blockchain'] as String,
    feePaid:    m['feePaid'] != null ? (m['feePaid'] as num).toDouble() : null,
  );
}

// ─── Network-error guard ──────────────────────────────────────────────────────
// Wraps any async call; converts SocketException / ClientException into a
// friendly, user-readable Exception so the UI can show a clean message.
Future<T> _guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on SocketException catch (e) {
    // errno 7 (Android ENOENT/host not found) and 11001 (Windows WSAHOST_NOT_FOUND)
    // mean DNS resolution failed — the explorer is down, NOT that there's no internet.
    final isDnsFail = e.osError?.errorCode == 7
                   || e.osError?.errorCode == 8
                   || e.osError?.errorCode == 11001;
    final msg = isDnsFail
        ? 'Explorer unavailable. The server could not be reached.'
        : 'No internet connection. Transaction history is unavailable.';
    throw Exception(msg);
  } on http.ClientException {
    throw Exception('No internet connection. Transaction history is unavailable.');
  }
}

enum TxDirection { incoming, outgoing, self }

class TxRecord {
  final String hash;
  final String from;
  final String to;
  final double amount;
  final String symbol;
  final DateTime timestamp;
  final TxDirection direction;
  final bool confirmed;
  final double? feePaid;
  final String blockchain;

  const TxRecord({
    required this.hash,
    required this.from,
    required this.to,
    required this.amount,
    required this.symbol,
    required this.timestamp,
    required this.direction,
    required this.confirmed,
    required this.blockchain,
    this.feePaid,
  });

  String get shortHash =>
      hash.length > 16 ? '${hash.substring(0, 8)}…${hash.substring(hash.length - 6)}' : hash;

  String get shortFrom =>
      from.length > 14 ? '${from.substring(0, 6)}…${from.substring(from.length - 4)}' : from;

  String get shortTo =>
      to.length > 14 ? '${to.substring(0, 6)}…${to.substring(to.length - 4)}' : to;
}

// ─── EVM chains ──────────────────────────────────────────────────────────────────

// Etherscan V2 unified endpoint — chains confirmed working on free tier
const _v2ChainIds = <String, int>{
  'ethereum': 1,
};

// Standalone Etherscan-compatible APIs.
// Each chain maps to a list of (baseUrl, keyType) tried in order.
// Note: bsc-dataseed.binance.org is a raw JSON-RPC node — NOT a history API.
final _standaloneApis = <String, List<(String, String)>>{
  'ethereum_classic': [...APIConfig.etcHistoryApis],
  'bsc': [
    (APIConfig.blockscoutBscApi, ''),    // BlockScout BSC — free, no key
    (APIConfig.bscscanApiUrl,    'bsc'), // BscScan — BSC API key
  ],
};

Future<List<TxRecord>> fetchEvmHistory({
  required String address,
  required String blockchain,
  String? contractAddress,
  int limit = 50,
}) => _guard(() async {
  final chainId    = _v2ChainIds[blockchain];
  final standalone = _standaloneApis[blockchain];
  if (chainId == null && standalone == null) return [];

  final action = contractAddress != null ? 'tokentx' : 'txlist';

  // ── Fetch main transaction list ────────────────────────────────────────────
  Map<String, dynamic> data;
  String? _activeBase; // winning standalone base URL (reused for internalTxs)
  String  _activeKey  = '';

  if (chainId != null) {
    final apiKey = APIConfig.etherscanEthKey;
    debugPrint('[TxHistory] $blockchain (chainId=$chainId) using API key: ${apiKey.isEmpty ? "EMPTY" : "${apiKey.substring(0, 8)}..."}');
    final uri = Uri.parse(APIConfig.etherscanV2Url).replace(queryParameters: {
      'chainid':    '$chainId',
      'module':     'account',
      'action':     action,
      'address':    address,
      if (contractAddress != null) 'contractaddress': contractAddress,
      'startblock': '0',
      'endblock':   '99999999',
      'page':       '1',
      'offset':     '$limit',
      'sort':       'desc',
      'apikey':     apiKey,
    });
    debugPrint('[TxHistory] Request URL: $uri');
    final resp = await http.get(uri).timeout(const Duration(seconds: 20));
    if (resp.statusCode == 404) return [];
    if (resp.statusCode != 200) throw Exception('Etherscan HTTP ${resp.statusCode}');
    data = jsonDecode(resp.body) as Map<String, dynamic>;
  } else {
    // Standalone: try each fallback API until one returns a valid response.
    Map<String, dynamic>? found;
    for (final (baseUrl, keyType) in standalone!) {
      final apiKey = keyType == 'bsc' ? APIConfig.getEtherscanKey('bsc') : '';
      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'module':     'account',
        'action':     action,
        'address':    address,
        if (contractAddress != null) 'contractaddress': contractAddress,
        'startblock': '0',
        'endblock':   '99999999',
        'page':       '1',
        'offset':     '$limit',
        'sort':       'desc',
        if (apiKey.isNotEmpty) 'apikey': apiKey,
      });
      debugPrint('[TxHistory] $blockchain trying: $baseUrl');
      try {
        final resp = await http.get(uri).timeout(const Duration(seconds: 20));
        if (resp.statusCode == 404) {
          found = {'status': '0', 'result': [], 'message': 'Not Found'};
          _activeBase = baseUrl; _activeKey = apiKey;
          break;
        }
        if (resp.statusCode != 200) {
          debugPrint('[TxHistory] $blockchain $baseUrl HTTP ${resp.statusCode} — trying next');
          continue;
        }
        final d = jsonDecode(resp.body) as Map<String, dynamic>;
        if (d['result'] is List) {
          found = d; _activeBase = baseUrl; _activeKey = apiKey;
          break;
        }
        debugPrint('[TxHistory] $blockchain $baseUrl status=${d['status']} msg=${d['message']} — trying next');
      } catch (e) {
        debugPrint('[TxHistory] $blockchain $baseUrl error: $e — trying next');
        continue;
      }
    }
    if (found == null) return [];
    data = found;
  }

  // ── Validate response ──────────────────────────────────────────────────────
  if (data['status'] != '1') {
    // If result is a list it's an empty (or partial) valid response — never throw.
    if (data['result'] is List) return [];
    final msg       = (data['message'] as String? ?? '').toLowerCase();
    final resultStr = (data['result']  as String? ?? '').toLowerCase();
    // "No transactions found" family — message or result field may carry it.
    if (msg.contains('no transaction') || msg.contains('no record') ||
        msg.contains('not found') ||
        resultStr.contains('no transaction') || resultStr.contains('no record') ||
        resultStr.contains('not found') ||
        // Gracefully handle deprecated or plan-restricted endpoints
        resultStr.contains('deprecated') ||
        resultStr.contains('free api access is not supported') ||
        resultStr.contains('upgrade your api plan')) {
      return [];
    }
    // Only log when it's a genuinely unexpected error
    debugPrint('[Etherscan] chainId=$chainId status=0 message="${data['message']}" result="${data['result']}"');
    // Show the actual result string (the real reason), not just "NOTOK".
    throw Exception('Etherscan[chainId=$chainId]: ${data['result'] ?? data['message']}');
  }

  final txs = (data['result'] as List<dynamic>);

  // For native EVM assets (not tokens), also fetch internal transactions so
  // that BNB/ETH received via contract calls appears in history.
  List<dynamic> internalTxs = [];
  if (contractAddress == null) {
    try {
      final internalAction = 'txlistinternal';
      final Uri internalUri;
      if (chainId != null) {
        final apiKey = APIConfig.etherscanEthKey;
        internalUri = Uri.parse(APIConfig.etherscanV2Url).replace(queryParameters: {
          'chainid':    '$chainId',
          'module':     'account',
          'action':     internalAction,
          'address':    address,
          'startblock': '0',
          'endblock':   '99999999',
          'page':       '1',
          'offset':     '$limit',
          'sort':       'desc',
          'apikey':     apiKey,
        });
      } else {
        // Reuse the winning API base URL from the main txlist fetch
        internalUri = Uri.parse(_activeBase!).replace(queryParameters: {
          'module':     'account',
          'action':     internalAction,
          'address':    address,
          'startblock': '0',
          'endblock':   '99999999',
          'page':       '1',
          'offset':     '$limit',
          'sort':       'desc',
          if (_activeKey.isNotEmpty) 'apikey': _activeKey,
        });
      }
      final iResp = await http.get(internalUri).timeout(const Duration(seconds: 20));
      if (iResp.statusCode == 200) {
        final iData = jsonDecode(iResp.body) as Map<String, dynamic>;
        if (iData['status'] == '1' && iData['result'] is List) {
          internalTxs = iData['result'] as List<dynamic>;
        }
      }
    } catch (_) {}
  }

  final addrL = address.toLowerCase();
  final seenHashes = <String>{};
  final records = <TxRecord>[];

  for (final raw in txs) {
    try {
      final m = raw as Map<String, dynamic>;
      final from    = (m['from'] as String?) ?? '';
      final to      = (m['to']   as String?) ?? '';
      final isToken = contractAddress != null;
      final value   = BigInt.tryParse(m['value'] as String? ?? '0') ?? BigInt.zero;
      final decimals = isToken
          ? int.tryParse(m['tokenDecimal'] as String? ?? '18') ?? 18
          : 18;
      final amount = value.toDouble() / BigInt.from(10).pow(decimals).toDouble();
      final sym    = isToken ? (m['tokenSymbol'] as String? ?? '') : _nativeSym(blockchain);
      final ts     = int.tryParse(m['timeStamp'] as String? ?? '0') ?? 0;
      final gas    = BigInt.tryParse(m['gasUsed']  as String? ?? '0') ?? BigInt.zero;
      final gasP   = BigInt.tryParse(m['gasPrice'] as String? ?? '0') ?? BigInt.zero;
      final fee    = (gas * gasP).toDouble() / 1e18;

      TxDirection dir;
      if (from.toLowerCase() == addrL && to.toLowerCase() == addrL) {
        dir = TxDirection.self;
      } else if (from.toLowerCase() == addrL) {
        dir = TxDirection.outgoing;
      } else {
        dir = TxDirection.incoming;
      }

      final hash = (m['hash'] as String?) ?? '';
      if (!seenHashes.add(hash)) continue; // deduplicate
      records.add(TxRecord(
        hash:       hash,
        from:       dir == TxDirection.outgoing ? '' : from,
        to:         dir == TxDirection.incoming ? '' : to,
        amount:     amount,
        symbol:     sym,
        timestamp:  DateTime.fromMillisecondsSinceEpoch(ts * 1000),
        direction:  dir,
        confirmed:  (int.tryParse(m['confirmations'] as String? ?? '0') ?? 0) > 0,
        blockchain: blockchain,
        feePaid:    fee,
      ));
    } catch (_) {
      continue; // skip malformed transaction, keep the rest
    }
  }

  // Process internal transactions (ETH received via contract calls)
  for (final raw in internalTxs) {
    try {
      final m     = raw as Map<String, dynamic>;
      final hash  = (m['hash'] as String?) ?? '';
      if (!seenHashes.add(hash)) continue; // deduplicate with normal txs
      final from  = (m['from'] as String?) ?? '';
      final to    = (m['to']   as String?) ?? '';
      final value = BigInt.tryParse(m['value'] as String? ?? '0') ?? BigInt.zero;
      final amount = value.toDouble() / 1e18;
      if (amount <= 0) continue;
      final ts    = int.tryParse(m['timeStamp'] as String? ?? '0') ?? 0;
      TxDirection dir;
      if (from.toLowerCase() == addrL && to.toLowerCase() == addrL) {
        dir = TxDirection.self;
      } else if (from.toLowerCase() == addrL) {
        dir = TxDirection.outgoing;
      } else {
        dir = TxDirection.incoming;
      }
      records.add(TxRecord(
        hash:       hash,
        from:       dir == TxDirection.outgoing ? '' : from,
        to:         dir == TxDirection.incoming ? '' : to,
        amount:     amount,
        symbol:     _nativeSym(blockchain),
        timestamp:  DateTime.fromMillisecondsSinceEpoch(ts * 1000),
        direction:  dir,
        confirmed:  true,
        blockchain: blockchain,
        feePaid:    0,
      ));
    } catch (_) {
      continue;
    }
  }

  records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return records;
});

String _nativeSym(String b) => const {
  'bsc': 'BNB',
}[b] ?? 'ETH';

// ─── Tron via TronScan (free, no API key required) ───────────────────────────

Future<List<TxRecord>> fetchTronHistory({
  required String address,
  String? contractAddress,
  int limit = 50,
}) => _guard(() async {
  if (contractAddress != null) {
    return _fetchTrc20History(
        address: address, contractAddress: contractAddress, limit: limit);
  }
  return _fetchTrxHistory(address: address, limit: limit);
});

// Native TRX — TronScan /api/transaction (with fallback)
Future<List<TxRecord>> _fetchTrxHistory({
  required String address,
  int limit = 50,
}) => _guard(() async {
  Map<String, dynamic>? body;
  for (int i = 0; i < APIConfig.tronscanApis.length; i++) {
    final base = APIConfig.tronscanApis[i];
    try {
      final uri  = Uri.parse('$base/transaction?address=$address&limit=$limit&start=0&sort=-timestamp');
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) { body = jsonDecode(resp.body) as Map<String, dynamic>; break; }
      debugPrint('[TxHistory] TRX $base HTTP ${resp.statusCode} — trying next');
    } catch (e) {
      debugPrint('[TxHistory] TRX $base error: $e — trying next');
    }
    if (i < APIConfig.tronscanApis.length - 1) await Future.delayed(const Duration(seconds: 1));
  }
  if (body == null) throw Exception('All TronScan APIs failed for TRX history');
  final data = (body['data'] as List<dynamic>?) ?? [];

  final records = <TxRecord>[];
  for (final raw in data) {
    try {
      final m = raw as Map<String, dynamic>;
      // contractType 1 = TransferContract (plain TRX transfer)
      if ((m['contractType'] as int?) != 1) continue;

      final from  = (m['ownerAddress'] as String?) ?? '';
      final to    = (m['toAddress']    as String?) ?? '';
      final ts    = (m['timestamp']    as int?)    ?? 0; // already ms
      final amt   = ((m['amount'] is String)
              ? double.tryParse(m['amount'] as String) ?? 0.0
              : ((m['amount'] as num?) ?? 0).toDouble()) /
          1e6;
      final dir   = from == address ? TxDirection.outgoing : TxDirection.incoming;

      records.add(TxRecord(
        hash:       (m['hash'] as String?) ?? '',
        from:       dir == TxDirection.outgoing ? '' : from,
        to:         dir == TxDirection.incoming ? '' : to,
        amount:     amt,
        symbol:     'TRX',
        timestamp:  DateTime.fromMillisecondsSinceEpoch(ts),
        direction:  dir,
        confirmed:  (m['confirmed'] as bool?) ?? true,
        blockchain: 'tron',
      ));
    } catch (_) {
      continue;
    }
  }
  return records;
});

// TRC-20 tokens — TronScan /api/token_trc20/transfers (with fallback)
Future<List<TxRecord>> _fetchTrc20History({
  required String address,
  required String contractAddress,
  int limit = 50,
}) => _guard(() async {
  Map<String, dynamic>? body;
  for (int i = 0; i < APIConfig.tronscanApis.length; i++) {
    final base = APIConfig.tronscanApis[i];
    try {
      final uri  = Uri.parse(
          '$base/token_trc20/transfers'
          '?relatedAddress=$address&contract_address=$contractAddress'
          '&limit=$limit&start=0');
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) { body = jsonDecode(resp.body) as Map<String, dynamic>; break; }
      debugPrint('[TxHistory] TRC20 $base HTTP ${resp.statusCode} — trying next');
    } catch (e) {
      debugPrint('[TxHistory] TRC20 $base error: $e — trying next');
    }
    if (i < APIConfig.tronscanApis.length - 1) await Future.delayed(const Duration(seconds: 1));
  }
  if (body == null) throw Exception('All TronScan APIs failed for TRC-20 history');
  final transfers = (body['token_transfers'] as List<dynamic>?) ?? [];

  final records = <TxRecord>[];
  for (final raw in transfers) {
    try {
      final m   = raw as Map<String, dynamic>;
      final from = (m['from_address'] as String?) ?? '';
      final to   = (m['to_address']   as String?) ?? '';
      final ts   = (m['block_ts']     as int?)    ?? 0; // milliseconds
      final info = m['tokenInfo'] as Map<String, dynamic>? ?? {};
      final dec  = (info['tokenDecimal'] as int?) ?? 6;
      final sym  = (info['tokenAbbr']    as String?) ?? 'TRC20';
      final qty  = BigInt.tryParse(
              (m['quant'] as String?) ?? '0') ??
          BigInt.zero;
      final amt  = qty.toDouble() / BigInt.from(10).pow(dec).toDouble();
      final dir  = from == address ? TxDirection.outgoing : TxDirection.incoming;

      records.add(TxRecord(
        hash:       (m['transaction_id'] as String?) ?? '',
        from:       dir == TxDirection.outgoing ? '' : from,
        to:         dir == TxDirection.incoming ? '' : to,
        amount:     amt,
        symbol:     sym,
        timestamp:  DateTime.fromMillisecondsSinceEpoch(ts),
        direction:  dir,
        confirmed:  (m['confirmed'] as bool?) ?? true,
        blockchain: 'tron',
      ));
    } catch (_) {
      continue;
    }
  }
  return records;
});

// ─── Solana via Helius Enhanced Transactions API ─────────────────────────────

Future<List<TxRecord>> fetchSolanaHistory({
  required String address,
  int limit = 25,
}) => _guard(() async {
  final uri = Uri.parse(
    '${APIConfig.heliusEnhancedTxBase}/$address/transactions/'
    '?api-key=${APIConfig.heliusApiKey}&limit=${limit.clamp(1, 100)}',
  );
  final resp = await http.get(uri).timeout(const Duration(seconds: 15));
  if (resp.statusCode != 200) {
    throw Exception('Solana RPC HTTP ${resp.statusCode}');
  }

  final txList = jsonDecode(resp.body) as List<dynamic>;
  final records = <TxRecord>[];

  for (final txData in txList) {
    try {
      final tx = txData as Map<String, dynamic>;
      if (tx['transactionError'] != null) continue;

      final sig = (tx['signature'] as String?) ?? '';
      final ts  = (tx['timestamp'] as num? ?? 0).toInt();
      final fee = (tx['fee'] as num? ?? 0).toDouble() / 1e9;

      final nativeTransfers = (tx['nativeTransfers'] as List<dynamic>?) ?? [];
      for (final transfer in nativeTransfers) {
        final t      = transfer as Map<String, dynamic>;
        final from   = (t['fromUserAccount'] as String?) ?? '';
        final to     = (t['toUserAccount']   as String?) ?? '';
        final amount = (t['amount'] as num? ?? 0).toDouble() / 1e9;
        if (amount <= 0) continue;
        if (from != address && to != address) continue;

        final dir = to == address ? TxDirection.incoming : TxDirection.outgoing;
        records.add(TxRecord(
          hash:       sig,
          from:       from,
          to:         to,
          amount:     amount,
          symbol:     'SOL',
          timestamp:  DateTime.fromMillisecondsSinceEpoch(ts * 1000),
          direction:  dir,
          confirmed:  true,
          blockchain: 'solana',
          feePaid:    fee,
        ));
        break;
      }
    } catch (_) {
      continue;
    }
  }
  return records;
});

// ─── BCH via Blockchair (full amounts + direction + recipient) ───────────────

Future<List<TxRecord>> fetchBlockchairUtxoHistory({
  required String address,
  required String blockchain,
  required String symbol,
  int limit = 25,
}) => _guard(() async {
  final slug = switch (blockchain) {
    'bitcoin_cash' => 'bitcoin-cash',
    _              => blockchain,
  };

  // Strip bitcoincash: prefix (Blockchair uses bare q… format)
  final bareAddr = address.startsWith('bitcoincash:')
      ? address.substring(12)
      : address;

  // ── Step 1: get the list of TX hashes for this address ──────────────────
  final addrUri = Uri.parse(
      '${APIConfig.blockchairApiBase}/$slug/dashboards/address/$bareAddr'
  ).replace(queryParameters: {'limit': '$limit'});
  final addrResp = await http.get(addrUri).timeout(const Duration(seconds: 12));
  if (addrResp.statusCode != 200) return [];
  final addrBody = jsonDecode(addrResp.body) as Map<String, dynamic>;
  final addrData = (addrBody['data'] as Map<String, dynamic>?)?.values.first
      as Map<String, dynamic>?;
  if (addrData == null) return [];

  final hashes = ((addrData['transactions'] as List<dynamic>?) ?? [])
      .take(limit)
      .cast<String>()
      .toList();
  if (hashes.isEmpty) return [];

  // ── Step 2: batch-fetch full TX details (inputs + outputs per TX) ────────
  // Blockchair allows up to 10 TX hashes per batch request on the free tier.
  final txDetails = <String, Map<String, dynamic>>{};
  for (var i = 0; i < hashes.length; i += 10) {
    final batch = hashes.skip(i).take(10).join(',');
    try {
      final bUri  = Uri.parse(
          '${APIConfig.blockchairApiBase}/$slug/dashboards/transactions/$batch');
      final bResp = await http.get(bUri).timeout(const Duration(seconds: 12));
      if (bResp.statusCode == 200) {
        final bBody = jsonDecode(bResp.body) as Map<String, dynamic>;
        final data  = (bBody['data'] as Map<String, dynamic>?) ?? {};
        for (final e in data.entries) {
          if (e.value is Map) {
            txDetails[e.key] = e.value as Map<String, dynamic>;
          }
        }
      }
    } catch (_) { continue; }
  }

  // ── Step 3: build TxRecord list ─────────────────────────────────────────
  final records = <TxRecord>[];
  for (final hash in hashes) {
    try {
      final detail  = txDetails[hash];
      if (detail == null) continue;
      final txInfo  = (detail['transaction'] as Map<String, dynamic>?) ?? {};
      final inputs  = (detail['inputs']      as List<dynamic>?)         ?? [];
      final outputs = (detail['outputs']     as List<dynamic>?)         ?? [];

      final time = DateTime.tryParse((txInfo['time'] as String?) ?? '');
      final ts   = time ?? DateTime.now();

      // Sats we spent (our address in inputs)
      int sentSats = 0;
      for (final inp in inputs) {
        final i = inp as Map<String, dynamic>;
        if (i['recipient'] == bareAddr) {
          sentSats += (i['value'] as num?)?.toInt() ?? 0;
        }
      }

      // Sats we received (our address in outputs) + first external recipient
      int receivedSats = 0;
      String recipient = '';
      for (final out in outputs) {
        final o    = out as Map<String, dynamic>;
        final addr = o['recipient'] as String?;
        final val  = (o['value'] as num?)?.toInt() ?? 0;
        if (addr == bareAddr) {
          receivedSats += val;
        } else if (sentSats > 0 && recipient.isEmpty && addr != null) {
          recipient = addr;
        }
      }

      final TxDirection dir;
      final double amt;
      final String from;
      final String to;
      if (sentSats > 0) {
        dir  = TxDirection.outgoing;
        amt  = (sentSats - receivedSats).clamp(0, double.maxFinite) / 1e8;
        from = '';
        to   = _bchToLegacy(recipient);
      } else {
        dir  = TxDirection.incoming;
        amt  = receivedSats / 1e8;
        final rawSender = inputs.whereType<Map<String, dynamic>>()
            .map((i) => (i['recipient'] as String?) ?? '')
            .firstWhere((a) => a != bareAddr && a.isNotEmpty, orElse: () => '');
        from = _bchToLegacy(rawSender);
        to   = '';
      }

      records.add(TxRecord(
        hash:       hash,
        from:       from,
        to:         to,
        amount:     amt,
        symbol:     symbol,
        timestamp:  ts,
        direction:  dir,
        confirmed:  true,
        blockchain: blockchain,
        feePaid:    null,
      ));
    } catch (_) { continue; }
  }
  return records;
});


// ─── Solana SPL token history via Helius Enhanced Transactions API ──────────

Future<List<TxRecord>> fetchSolanaTokenHistory({
  required String ownerAddress,
  required String mintAddress,
  required String symbol,
  required int decimals,
  int limit = 25,
}) => _guard(() async {
  final uri = Uri.parse(
    '${APIConfig.heliusEnhancedTxBase}/$ownerAddress/transactions/'
    '?api-key=${APIConfig.heliusApiKey}&limit=${limit.clamp(1, 100)}',
  );
  final resp = await http.get(uri).timeout(const Duration(seconds: 15));
  if (resp.statusCode != 200) return [];

  final txList = jsonDecode(resp.body) as List<dynamic>;
  final records = <TxRecord>[];

  for (final txData in txList) {
    try {
      final tx = txData as Map<String, dynamic>;
      if (tx['transactionError'] != null) continue;

      final sig = (tx['signature'] as String?) ?? '';
      final ts  = (tx['timestamp'] as num? ?? 0).toInt();
      final fee = (tx['fee'] as num? ?? 0).toDouble() / 1e9;

      final tokenTransfers = (tx['tokenTransfers'] as List<dynamic>?) ?? [];
      for (final transfer in tokenTransfers) {
        final t = transfer as Map<String, dynamic>;
        if ((t['mint'] as String?) != mintAddress) continue;

        final from   = (t['fromUserAccount'] as String?) ?? '';
        final to     = (t['toUserAccount']   as String?) ?? '';
        final amount = (t['tokenAmount'] as num? ?? 0).toDouble();
        if (amount <= 0) continue;
        if (from != ownerAddress && to != ownerAddress) continue;

        final dir = to == ownerAddress ? TxDirection.incoming : TxDirection.outgoing;
        records.add(TxRecord(
          hash:       sig,
          from:       from,
          to:         to,
          amount:     amount,
          symbol:     symbol,
          timestamp:  DateTime.fromMillisecondsSinceEpoch(ts * 1000),
          direction:  dir,
          confirmed:  true,
          blockchain: 'solana',
          feePaid:    fee,
        ));
        break;
      }
    } catch (_) {
      continue;
    }
  }
  return records;
});


// ─── Bitcoin + Litecoin via BlockCypher (free, API key in constants) ─

Future<List<TxRecord>> fetchLitecoinHistory({
  required String address,
  int limit = 50,
}) => _guard(() async {
  // litecoinspace.org returns full TX objects (vin + vout) — gives us exact
  // sent/received amounts, correct direction, and the recipient address.
  final uri = Uri.parse('${APIConfig.litecoinspaceBase}/api/address/$address/txs');
  final resp = await http.get(uri).timeout(const Duration(seconds: 12));
  if (resp.statusCode != 200) return [];
  final txList = jsonDecode(resp.body) as List<dynamic>;

  final records = <TxRecord>[];
  for (final raw in txList.take(limit)) {
    try {
      final tx   = raw as Map<String, dynamic>;
      final hash = tx['txid'] as String;
      final status    = (tx['status'] as Map<String, dynamic>?) ?? {};
      final confirmed = status['confirmed'] as bool? ?? false;
      final blockTime = status['block_time'] as int?;
      final ts = blockTime != null
          ? DateTime.fromMillisecondsSinceEpoch(blockTime * 1000)
          : DateTime.now();

      // Sats we spent (our address in vin[].prevout)
      int sentSats = 0;
      for (final vin in (tx['vin'] as List<dynamic>? ?? [])) {
        final v       = vin as Map<String, dynamic>;
        final prevout = v['prevout'] as Map<String, dynamic>?;
        if (prevout?['scriptpubkey_address'] == address) {
          sentSats += (prevout?['value'] as int? ?? 0);
        }
      }

      // Sats we received (our address in vout[]) + first external recipient
      int receivedSats  = 0;
      String recipient  = '';
      for (final vout in (tx['vout'] as List<dynamic>? ?? [])) {
        final v    = vout as Map<String, dynamic>;
        final addr = v['scriptpubkey_address'] as String?;
        final val  = v['value'] as int? ?? 0;
        if (addr == address) {
          receivedSats += val;
        } else if (sentSats > 0 && recipient.isEmpty && addr != null) {
          recipient = addr;
        }
      }

      final TxDirection dir;
      final double amt;
      final String from;
      final String to;
      if (sentSats > 0) {
        dir  = TxDirection.outgoing;
        amt  = (sentSats - receivedSats).clamp(0, double.maxFinite) / 1e8;
        from = '';
        to   = recipient;
      } else {
        dir  = TxDirection.incoming;
        amt  = receivedSats / 1e8;
        String senderAddr = '';
        for (final vin in (tx['vin'] as List<dynamic>? ?? [])) {
          final v = vin as Map<String, dynamic>;
          final prevout = v['prevout'] as Map<String, dynamic>?;
          final vinAddr = prevout?['scriptpubkey_address'] as String?;
          if (vinAddr != null && vinAddr != address) { senderAddr = vinAddr; break; }
        }
        from = senderAddr;
        to   = '';
      }

      records.add(TxRecord(
        hash:       hash,
        from:       from,
        to:         to,
        amount:     amt,
        symbol:     'LTC',
        timestamp:  ts,
        direction:  dir,
        confirmed:  confirmed,
        blockchain: 'litecoin',
        feePaid:    null,
      ));
    } catch (_) { continue; }
  }
  return records;
});

Future<List<TxRecord>> fetchBitcoinHistory({
  required String address,
  int limit = 50,
}) => _guard(() async {
  // Try each BTC history API with 2-second delay between attempts
  for (int i = 0; i < APIConfig.btcHistoryApis.length; i++) {
    final baseUrl = APIConfig.btcHistoryApis[i];
    if (kDebugMode) debugPrint('[TxHistory] BTC trying: $baseUrl');
    
    try {
      final uri = Uri.parse('$baseUrl/$address');
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        List<dynamic> txList = [];
        
        // Different APIs have different response formats
        if (body is List) {
          // mempool.space format: direct array
          txList = body;
        } else if (body is Map && body['txs'] != null) {
          // blockchain.info format: {txs: [...]}
          txList = body['txs'] as List<dynamic>;
        } else if (body is Map && body['data'] != null) {
          // blockchair format: {data: {address: {transactions: [...]}}}
          final data = body['data'] as Map<String, dynamic>;
          final addrData = data[address] as Map<String, dynamic>?;
          txList = (addrData?['transactions'] as List<dynamic>?) ?? [];
        }
        
        if (kDebugMode) debugPrint('[TxHistory] BTC ✓ $baseUrl: ${txList.length} txs');
        return _parseBtcTransactions(txList, address, limit);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TxHistory] BTC $baseUrl error: $e — trying next');
    }
    
    // Wait 2 seconds before trying next API (except for last one)
    if (i < APIConfig.btcHistoryApis.length - 1) {
      await Future.delayed(const Duration(seconds: 2));
    }
  }
  
  // All APIs failed
  throw Exception('All BTC history APIs failed');
});

/// Parse BTC transactions from different API formats (mempool.space, blockchain.info, blockchair)
List<TxRecord> _parseBtcTransactions(List<dynamic> txList, String address, int limit) {
  final records = <TxRecord>[];
  final addrLower = address.toLowerCase();
  
  for (final raw in txList.take(limit)) {
    try {
      final m = raw as Map<String, dynamic>;
      
      // Extract common fields (different APIs use different field names)
      final hash = (m['txid'] ?? m['hash'] ?? '') as String;
      final timestamp = m['status']?['block_time'] ?? m['time'] ?? m['block_time'] ?? 0;
      final ts = timestamp is int 
          ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
          : DateTime.now();
      
      // Parse inputs and outputs
      final vin = (m['vin'] ?? m['inputs'] ?? []) as List<dynamic>;
      final vout = (m['vout'] ?? m['out'] ?? []) as List<dynamic>;
      
      bool isSender = false;
      bool isReceiver = false;
      double amountSent = 0;
      double amountReceived = 0;
      
      // Check inputs (if our address is in inputs, we're sending)
      for (final input in vin) {
        final prevout = input['prevout'] ?? input;
        final scriptPubKey = prevout['scriptpubkey_address'] ?? prevout['addr'] ?? '';
        if (scriptPubKey.toString().toLowerCase() == addrLower) {
          isSender = true;
          amountSent += ((prevout['value'] ?? 0) as num).toDouble() / 1e8;
        }
      }
      
      // Check outputs (if our address is in outputs, we're receiving)
      for (final output in vout) {
        final scriptPubKey = output['scriptpubkey_address'] ?? output['addr'] ?? '';
        if (scriptPubKey.toString().toLowerCase() == addrLower) {
          isReceiver = true;
          amountReceived += ((output['value'] ?? 0) as num).toDouble() / 1e8;
        }
      }
      
      // Determine direction and amount
      TxDirection direction;
      double amount;
      if (isSender && isReceiver) {
        direction = TxDirection.self;
        amount = amountReceived;
      } else if (isSender) {
        direction = TxDirection.outgoing;
        amount = amountSent - amountReceived; // net sent
      } else {
        direction = TxDirection.incoming;
        amount = amountReceived;
      }
      
      records.add(TxRecord(
        hash: hash,
        from: direction == TxDirection.outgoing ? '' : address,
        to: direction == TxDirection.incoming ? '' : address,
        amount: amount,
        symbol: 'BTC',
        timestamp: ts,
        direction: direction,
        confirmed: (m['status']?['confirmed'] ?? true) as bool,
        blockchain: 'bitcoin',
        feePaid: ((m['fee'] ?? 0) as num).toDouble() / 1e8,
      ));
    } catch (e) {
      if (kDebugMode) debugPrint('[TxHistory] BTC parse error: $e');
      continue;
    }
  }
  
  return records;
}

Future<List<TxRecord>> _fetchBlockCypherHistory({
  required String address,
  required String coin,      // 'btc' | 'ltc'
  required String symbol,
  required String blockchain,
  required double satFactor,
  int limit = 50,
}) => _guard(() async {
  final uri = Uri.parse(
    '${APIConfig.blockcypherApiBase}/$coin/main/addrs/$address/full',
  ).replace(queryParameters: {
    'token':             APIConfig.blockcypherToken,
    'limit':             '$limit',
    'instart':           '0',
    'outstart':          '0',
    'includeConfidence': 'false',
  });

  final resp = await http.get(uri, headers: {
    'Accept': 'application/json',
  }).timeout(const Duration(seconds: 15));

  if (resp.statusCode == 404) return []; // address not found (never used)
  if (resp.statusCode != 200) {
    throw Exception('BlockCypher HTTP ${resp.statusCode}');
  }

  final body   = jsonDecode(resp.body) as Map<String, dynamic>;
  final txList = (body['txs'] as List<dynamic>?) ?? [];
  final records = <TxRecord>[];

  for (final raw in txList) {
    try {
      final m = raw as Map<String, dynamic>;
      final hash = (m['hash'] as String?) ?? '';

      // Timestamps: prefer 'confirmed', fall back to 'received'
      final tsStr = (m['confirmed'] as String?) ?? (m['received'] as String?);
      final ts = tsStr != null
          ? DateTime.tryParse(tsStr) ?? DateTime.now()
          : DateTime.now();
      final isConfirmed = m['confirmed'] != null;

      // Inputs and outputs
      final inputs  = (m['inputs']  as List<dynamic>?) ?? [];
      final outputs = (m['outputs'] as List<dynamic>?) ?? [];

      // Determine if this address appears in inputs (sent) or outputs (received)
      bool inInputs = false;
      bool inOutputs = false;
      double inputTotal  = 0;
      double outputTotal = 0;

      final addrLower = address.toLowerCase();
      for (final inp in inputs) {
        final addrs = ((inp as Map)['addresses'] as List<dynamic>?) ?? [];
        if (addrs.any((a) => a.toString().toLowerCase() == addrLower)) {
          inInputs = true;
          inputTotal += ((inp['output_value'] as num?) ?? 0).toDouble();
        }
      }
      for (final out in outputs) {
        final addrs = ((out as Map)['addresses'] as List<dynamic>?) ?? [];
        if (addrs.any((a) => a.toString().toLowerCase() == addrLower)) {
          inOutputs = true;
          outputTotal += ((out['value'] as num?) ?? 0).toDouble();
        }
      }

      final TxDirection dir;
      final double amt;
      String fromAddr = '';
      String toAddr   = '';

      if (inInputs && inOutputs) {
        // Check for external outputs — a change output makes inOutputs=true even for sends
        final externalOut = outputs.cast<Map>().where(
          (o) => !((o['addresses'] as List?) ?? [])
                  .any((a) => a.toString().toLowerCase() == addrLower)
              && ((o['value'] as num?) ?? 0) > 0,
        ).toList();
        if (externalOut.isNotEmpty) {
          // We sent to an external address and got change back → outgoing
          dir      = TxDirection.outgoing;
          fromAddr = '';
          toAddr   = (externalOut.first['addresses'] as List?)?.first?.toString() ?? '';
          amt      = (inputTotal - outputTotal).abs() / satFactor;
        } else {
          // All outputs return to us → true self-transfer
          dir = TxDirection.self;
          amt = outputTotal / satFactor;
        }
      } else if (inInputs) {
        dir = TxDirection.outgoing;
        // Find the first non-self output address
        final firstOut = outputs.firstWhere(
          (o) => !((o as Map)['addresses'] as List? ?? [])
              .any((a) => a.toString().toLowerCase() == addrLower),
          orElse: () => outputs.first,
        );
        toAddr   = ((firstOut as Map)['addresses'] as List?)?.first?.toString() ?? '';
        fromAddr = '';
        // Net sent = inputs from us – outputs back to us (change)
        amt = (inputTotal - outputTotal).abs() / satFactor;
      } else {
        dir = TxDirection.incoming;
        toAddr   = '';
        final firstIn = inputs.firstOrNull as Map<String, dynamic>?;
        fromAddr = (firstIn?['addresses'] as List?)?.first?.toString() ?? '';
        // Fallback: BlockCypher may leave addresses:[] for SegWit outputs.
        // Sum all outputs whose addresses array is empty — those are ours.
        if (outputTotal == 0) {
          for (final out in outputs) {
            final addrs = ((out as Map)['addresses'] as List<dynamic>?) ?? [];
            if (addrs.isEmpty) {
              final v = (out as Map)['value'];
              outputTotal += v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
            }
          }
        }
        amt = outputTotal / satFactor;
      }

      final fee = ((m['fees'] as num?) ?? 0).toDouble() / satFactor;

      records.add(TxRecord(
        hash:       hash,
        from:       fromAddr,
        to:         toAddr,
        amount:     amt,
        symbol:     symbol,
        timestamp:  ts,
        direction:  dir,
        confirmed:  isConfirmed,
        blockchain: blockchain,
        feePaid:    fee,
      ));
    } catch (_) {
      continue;
    }
  }
  return records;
});

// ─── Unified dispatcher: fetch history for any wallet asset ──────────────────

/// Resolves the correct wallet address and dispatches to the appropriate fetch
/// function based on [asset.blockchain].
/// [walletAssets] is needed to find the native address for token assets.
Future<List<TxRecord>> fetchHistoryForAsset({
  required Asset asset,
  required List<Asset> walletAssets,
  int limit = 50,
}) async {
  // Resolve user's wallet address for this chain
  final String userAddress;
  if (asset.type == AssetType.native) {
    userAddress = asset.contractAddress;
  } else {
    final native = walletAssets.firstWhere(
      (a) => a.blockchain == asset.blockchain && a.type == AssetType.native,
      orElse: () => asset,
    );
    userAddress = native.contractAddress;
  }

  // Resolve token contract address from catalog (e.g. 0xdAC17... for USDT-ETH)
  String? contractAddr;
  if (asset.type == AssetType.token) {
    try {
      contractAddr = allCatalogTokens.firstWhere((t) => t.id == asset.id).contractAddress;
    } catch (_) {}
  }

  final chain = asset.blockchain;
  if (APIConfig.evmChains.contains(chain)) {
    return fetchEvmHistory(address: userAddress, blockchain: chain,
        contractAddress: contractAddr, limit: limit);
  } else if (chain == 'tron') {
    return fetchTronHistory(address: userAddress, contractAddress: contractAddr, limit: limit);
  } else if (chain == 'solana') {
    if (asset.type == AssetType.token && contractAddr != null) {
      return fetchSolanaTokenHistory(ownerAddress: userAddress, mintAddress: contractAddr,
          symbol: asset.symbol, decimals: asset.decimals);
    }
    return fetchSolanaHistory(address: userAddress, limit: limit);
  } else if (chain == 'bitcoin')           { return fetchBitcoinHistory(address: userAddress, limit: limit); }
  else if (chain == 'litecoin')          { return fetchLitecoinHistory(address: userAddress, limit: limit); }
  else if (chain == 'bitcoin_cash') {
    return fetchBlockchairUtxoHistory(address: userAddress, blockchain: chain,
        symbol: asset.symbol, limit: limit);
  }
  return [];
}



