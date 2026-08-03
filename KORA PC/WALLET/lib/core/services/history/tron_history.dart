import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora_windows/core/config/api_config.dart';
import 'package:kora_windows/core/models/tx_record.dart';
import 'package:kora_windows/core/services/history/network_guard.dart';

// Transaction history for Tron.
//
// TRX and TRC-20 come from two different TronScan endpoints and are merged here, because from
// the wallet's side "what moved on Tron" is one question.

Future<List<TxRecord>> fetchTronHistory({
  required String address,
  String? contractAddress,
  int limit = 50,
}) => guardNetwork(() async {
  if (contractAddress != null) {
    return _fetchTrc20History(address: address, contractAddress: contractAddress, limit: limit);
  }
  return _fetchTrxHistory(address: address, limit: limit);
});

// Native TRX — TronScan /api/transaction (with fallback)
Future<List<TxRecord>> _fetchTrxHistory({required String address, int limit = 50}) =>
    guardNetwork(() async {
      Map<String, dynamic>? body;
      for (int i = 0; i < APIConfig.tronscanApis.length; i++) {
        final base = APIConfig.tronscanApis[i];
        try {
          final uri = Uri.parse(
            '$base/transaction?address=$address&limit=$limit&start=0&sort=-timestamp',
          );
          final resp = await http.get(uri).timeout(const Duration(seconds: 12));
          if (resp.statusCode == 200) {
            body = jsonDecode(resp.body) as Map<String, dynamic>;
            break;
          }
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

          final from = (m['ownerAddress'] as String?) ?? '';
          final to = (m['toAddress'] as String?) ?? '';
          final ts = (m['timestamp'] as int?) ?? 0; // already ms
          final amt =
              ((m['amount'] is String)
                  ? double.tryParse(m['amount'] as String) ?? 0.0
                  : ((m['amount'] as num?) ?? 0).toDouble()) /
              1e6;
          final dir = from == address ? TxDirection.outgoing : TxDirection.incoming;

          records.add(
            TxRecord(
              hash: (m['hash'] as String?) ?? '',
              from: dir == TxDirection.outgoing ? '' : from,
              to: dir == TxDirection.incoming ? '' : to,
              amount: amt,
              symbol: 'TRX',
              timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
              direction: dir,
              confirmed: (m['confirmed'] as bool?) ?? true,
              blockchain: 'tron',
            ),
          );
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
}) => guardNetwork(() async {
  // TronScan rejects any limit above 50 on this endpoint with HTTP 400 — not an empty page,
  // a hard refusal. The portfolio chart asks for 1000, so every mirror returned 400, the loop
  // fell through to the throw below, and USDT-TRON — the whole of this wallet — had no
  // history at all. Pages of 50 are collected until the caller's limit is met or the chain
  // runs out.
  const int page = 50;
  final transfers = <dynamic>[];
  var start = 0;

  while (transfers.length < limit) {
    final want = limit - transfers.length < page ? limit - transfers.length : page;
    Map<String, dynamic>? body;

    for (int i = 0; i < APIConfig.tronscanApis.length; i++) {
      final base = APIConfig.tronscanApis[i];
      try {
        final uri = Uri.parse(
          '$base/token_trc20/transfers'
          '?relatedAddress=$address&contract_address=$contractAddress'
          '&limit=$want&start=$start',
        );
        final resp = await http.get(uri).timeout(const Duration(seconds: 12));
        if (resp.statusCode == 200) {
          body = jsonDecode(resp.body) as Map<String, dynamic>;
          break;
        }
        debugPrint('[TxHistory] TRC20 $base HTTP ${resp.statusCode} — trying next');
      } catch (e) {
        debugPrint('[TxHistory] TRC20 $base error: $e — trying next');
      }
      if (i < APIConfig.tronscanApis.length - 1) await Future.delayed(const Duration(seconds: 1));
    }

    // A first page that cannot be fetched is a failure; a later one that cannot is the end of
    // what we can see, and the pages already in hand are still worth returning.
    if (body == null) {
      if (start == 0) throw Exception('All TronScan APIs failed for TRC-20 history');
      break;
    }

    final batch = (body['token_transfers'] as List<dynamic>?) ?? const [];
    transfers.addAll(batch);
    if (batch.length < want) break; // short page — nothing further to ask for
    start += batch.length;
  }

  final records = <TxRecord>[];
  // Pages are windows into a list that is still growing at its head: a transfer arriving
  // between two requests shifts everything down by one, and the record on the boundary comes
  // back twice. Deduplicating by transaction id costs a set and removes the possibility.
  final seenHashes = <String>{};
  for (final raw in transfers) {
    try {
      final m = raw as Map<String, dynamic>;
      final id = (m['transaction_id'] as String?) ?? '';
      if (id.isEmpty || !seenHashes.add(id)) continue;
      final from = (m['from_address'] as String?) ?? '';
      final to = (m['to_address'] as String?) ?? '';
      final ts = (m['block_ts'] as int?) ?? 0; // milliseconds
      final info = m['tokenInfo'] as Map<String, dynamic>? ?? {};
      final dec = (info['tokenDecimal'] as int?) ?? 6;
      final sym = (info['tokenAbbr'] as String?) ?? 'TRC20';
      final qty = BigInt.tryParse((m['quant'] as String?) ?? '0') ?? BigInt.zero;
      final amt = qty.toDouble() / BigInt.from(10).pow(dec).toDouble();
      final dir = from == address ? TxDirection.outgoing : TxDirection.incoming;

      records.add(
        TxRecord(
          hash: id,
          from: dir == TxDirection.outgoing ? '' : from,
          to: dir == TxDirection.incoming ? '' : to,
          amount: amt,
          symbol: sym,
          timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
          direction: dir,
          confirmed: (m['confirmed'] as bool?) ?? true,
          blockchain: 'tron',
        ),
      );
    } catch (_) {
      continue;
    }
  }
  return records;
});
