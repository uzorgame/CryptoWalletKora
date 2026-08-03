import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora_windows/core/config/api_config.dart';
import 'package:kora_windows/core/models/tx_record.dart';
import 'package:kora_windows/core/services/history/network_guard.dart';

// Transaction history for the EVM chains.
//
// Etherscan's V2 endpoint covers the chains it covers; the rest each need their own
// Etherscan-compatible explorer, tried in order, because no single one of them is reliably up.

// Etherscan V2 unified endpoint — chains confirmed working on free tier
const _v2ChainIds = <String, int>{'ethereum': 1};

// Standalone Etherscan-compatible APIs.
// Each chain maps to a list of (baseUrl, keyType) tried in order.
// Note: bsc-dataseed.binance.org is a raw JSON-RPC node — NOT a history API.
final _standaloneApis = <String, List<(String, String)>>{
  'ethereum_classic': [...APIConfig.etcHistoryApis],
  'bsc': [
    (APIConfig.blockscoutBscApi, ''), // BlockScout BSC — free, no key
    (APIConfig.bscscanApiUrl, 'bsc'), // BscScan — BSC API key
  ],
};

Future<List<TxRecord>> fetchEvmHistory({
  required String address,
  required String blockchain,
  String? contractAddress,
  int limit = 50,
}) => guardNetwork(() async {
  final chainId = _v2ChainIds[blockchain];
  final standalone = _standaloneApis[blockchain];
  if (chainId == null && standalone == null) return [];

  final action = contractAddress != null ? 'tokentx' : 'txlist';

  // ── Fetch main transaction list ────────────────────────────────────────────
  Map<String, dynamic> data;
  String? _activeBase; // winning standalone base URL (reused for internalTxs)
  String _activeKey = '';

  if (chainId != null) {
    final apiKey = APIConfig.etherscanEthKey;
    debugPrint(
      '[TxHistory] $blockchain (chainId=$chainId) using API key: ${apiKey.isEmpty ? "EMPTY" : "${apiKey.substring(0, 8)}..."}',
    );
    final uri = Uri.parse(APIConfig.etherscanV2Url).replace(
      queryParameters: {
        'chainid': '$chainId',
        'module': 'account',
        'action': action,
        'address': address,
        if (contractAddress != null) 'contractaddress': contractAddress,
        'startblock': '0',
        'endblock': '99999999',
        'page': '1',
        'offset': '$limit',
        'sort': 'desc',
        'apikey': apiKey,
      },
    );
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
      final uri = Uri.parse(baseUrl).replace(
        queryParameters: {
          'module': 'account',
          'action': action,
          'address': address,
          if (contractAddress != null) 'contractaddress': contractAddress,
          'startblock': '0',
          'endblock': '99999999',
          'page': '1',
          'offset': '$limit',
          'sort': 'desc',
          if (apiKey.isNotEmpty) 'apikey': apiKey,
        },
      );
      debugPrint('[TxHistory] $blockchain trying: $baseUrl');
      try {
        final resp = await http.get(uri).timeout(const Duration(seconds: 20));
        if (resp.statusCode == 404) {
          found = {'status': '0', 'result': [], 'message': 'Not Found'};
          _activeBase = baseUrl;
          _activeKey = apiKey;
          break;
        }
        if (resp.statusCode != 200) {
          debugPrint('[TxHistory] $blockchain $baseUrl HTTP ${resp.statusCode} — trying next');
          continue;
        }
        final d = jsonDecode(resp.body) as Map<String, dynamic>;
        if (d['result'] is List) {
          found = d;
          _activeBase = baseUrl;
          _activeKey = apiKey;
          break;
        }
        debugPrint(
          '[TxHistory] $blockchain $baseUrl status=${d['status']} msg=${d['message']} — trying next',
        );
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
    final msg = (data['message'] as String? ?? '').toLowerCase();
    final resultStr = (data['result'] as String? ?? '').toLowerCase();
    // "No transactions found" family — message or result field may carry it.
    if (msg.contains('no transaction') ||
        msg.contains('no record') ||
        msg.contains('not found') ||
        resultStr.contains('no transaction') ||
        resultStr.contains('no record') ||
        resultStr.contains('not found') ||
        // Gracefully handle deprecated or plan-restricted endpoints
        resultStr.contains('deprecated') ||
        resultStr.contains('free api access is not supported') ||
        resultStr.contains('upgrade your api plan')) {
      return [];
    }
    // Only log when it's a genuinely unexpected error
    debugPrint(
      '[Etherscan] chainId=$chainId status=0 message="${data['message']}" result="${data['result']}"',
    );
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
        internalUri = Uri.parse(APIConfig.etherscanV2Url).replace(
          queryParameters: {
            'chainid': '$chainId',
            'module': 'account',
            'action': internalAction,
            'address': address,
            'startblock': '0',
            'endblock': '99999999',
            'page': '1',
            'offset': '$limit',
            'sort': 'desc',
            'apikey': apiKey,
          },
        );
      } else {
        // Reuse the winning API base URL from the main txlist fetch
        internalUri = Uri.parse(_activeBase!).replace(
          queryParameters: {
            'module': 'account',
            'action': internalAction,
            'address': address,
            'startblock': '0',
            'endblock': '99999999',
            'page': '1',
            'offset': '$limit',
            'sort': 'desc',
            if (_activeKey.isNotEmpty) 'apikey': _activeKey,
          },
        );
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
      final from = (m['from'] as String?) ?? '';
      final to = (m['to'] as String?) ?? '';
      final isToken = contractAddress != null;
      final value = BigInt.tryParse(m['value'] as String? ?? '0') ?? BigInt.zero;
      final decimals = isToken ? int.tryParse(m['tokenDecimal'] as String? ?? '18') ?? 18 : 18;
      final amount = value.toDouble() / BigInt.from(10).pow(decimals).toDouble();
      final sym = isToken ? (m['tokenSymbol'] as String? ?? '') : _nativeSym(blockchain);
      final ts = int.tryParse(m['timeStamp'] as String? ?? '0') ?? 0;
      final gas = BigInt.tryParse(m['gasUsed'] as String? ?? '0') ?? BigInt.zero;
      final gasP = BigInt.tryParse(m['gasPrice'] as String? ?? '0') ?? BigInt.zero;
      final fee = (gas * gasP).toDouble() / 1e18;

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
      records.add(
        TxRecord(
          hash: hash,
          from: dir == TxDirection.outgoing ? '' : from,
          to: dir == TxDirection.incoming ? '' : to,
          amount: amount,
          symbol: sym,
          timestamp: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
          direction: dir,
          confirmed: (int.tryParse(m['confirmations'] as String? ?? '0') ?? 0) > 0,
          blockchain: blockchain,
          feePaid: fee,
        ),
      );
    } catch (_) {
      continue; // skip malformed transaction, keep the rest
    }
  }

  // Process internal transactions (ETH received via contract calls)
  for (final raw in internalTxs) {
    try {
      final m = raw as Map<String, dynamic>;
      final hash = (m['hash'] as String?) ?? '';
      if (!seenHashes.add(hash)) continue; // deduplicate with normal txs
      final from = (m['from'] as String?) ?? '';
      final to = (m['to'] as String?) ?? '';
      final value = BigInt.tryParse(m['value'] as String? ?? '0') ?? BigInt.zero;
      final amount = value.toDouble() / 1e18;
      if (amount <= 0) continue;
      final ts = int.tryParse(m['timeStamp'] as String? ?? '0') ?? 0;
      TxDirection dir;
      if (from.toLowerCase() == addrL && to.toLowerCase() == addrL) {
        dir = TxDirection.self;
      } else if (from.toLowerCase() == addrL) {
        dir = TxDirection.outgoing;
      } else {
        dir = TxDirection.incoming;
      }
      records.add(
        TxRecord(
          hash: hash,
          from: dir == TxDirection.outgoing ? '' : from,
          to: dir == TxDirection.incoming ? '' : to,
          amount: amount,
          symbol: _nativeSym(blockchain),
          timestamp: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
          direction: dir,
          confirmed: true,
          blockchain: blockchain,
          feePaid: 0,
        ),
      );
    } catch (_) {
      continue;
    }
  }

  records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return records;
});

String _nativeSym(String b) => const {'bsc': 'BNB'}[b] ?? 'ETH';
