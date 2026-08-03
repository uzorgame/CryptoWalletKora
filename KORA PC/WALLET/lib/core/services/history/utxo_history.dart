import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora_windows/core/config/api_config.dart';
import 'package:kora_windows/core/models/tx_record.dart';
import 'package:kora_windows/core/services/history/network_guard.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

// Transaction history for the UTXO chains — Bitcoin, Litecoin, and the rest of the
// Blockchair-served family.
//
// A UTXO transaction has no single sender or recipient, so direction and amount have to be
// worked out from which inputs and outputs are the wallet's own. That reconstruction is the
// bulk of this file, and it is why these chains do not share the EVM client.

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
    if (b == 0) {
      result = '1$result';
    } else {
      break;
    }
  }
  return result;
}

Future<List<TxRecord>> fetchBlockchairUtxoHistory({
  required String address,
  required String blockchain,
  required String symbol,
  int limit = 25,
}) => guardNetwork(() async {
  final slug = switch (blockchain) {
    'bitcoin_cash' => 'bitcoin-cash',
    _ => blockchain,
  };

  // Strip bitcoincash: prefix (Blockchair uses bare q… format)
  final bareAddr = address.startsWith('bitcoincash:') ? address.substring(12) : address;

  // ── Step 1: get the list of TX hashes for this address ──────────────────
  final addrUri = Uri.parse(
    '${APIConfig.blockchairApiBase}/$slug/dashboards/address/$bareAddr',
  ).replace(queryParameters: {'limit': '$limit'});
  final addrResp = await http.get(addrUri).timeout(const Duration(seconds: 12));
  if (addrResp.statusCode != 200) return [];
  final addrBody = jsonDecode(addrResp.body) as Map<String, dynamic>;
  final addrData =
      (addrBody['data'] as Map<String, dynamic>?)?.values.first as Map<String, dynamic>?;
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
      final bUri = Uri.parse('${APIConfig.blockchairApiBase}/$slug/dashboards/transactions/$batch');
      final bResp = await http.get(bUri).timeout(const Duration(seconds: 12));
      if (bResp.statusCode == 200) {
        final bBody = jsonDecode(bResp.body) as Map<String, dynamic>;
        final data = (bBody['data'] as Map<String, dynamic>?) ?? {};
        for (final e in data.entries) {
          if (e.value is Map) {
            txDetails[e.key] = e.value as Map<String, dynamic>;
          }
        }
      }
    } catch (_) {
      continue;
    }
  }

  // ── Step 3: build TxRecord list ─────────────────────────────────────────
  final records = <TxRecord>[];
  for (final hash in hashes) {
    try {
      final detail = txDetails[hash];
      if (detail == null) continue;
      final txInfo = (detail['transaction'] as Map<String, dynamic>?) ?? {};
      final inputs = (detail['inputs'] as List<dynamic>?) ?? [];
      final outputs = (detail['outputs'] as List<dynamic>?) ?? [];

      final time = DateTime.tryParse((txInfo['time'] as String?) ?? '');
      final ts = time ?? DateTime.now();

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
        final o = out as Map<String, dynamic>;
        final addr = o['recipient'] as String?;
        final val = (o['value'] as num?)?.toInt() ?? 0;
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
        dir = TxDirection.outgoing;
        amt = (sentSats - receivedSats).clamp(0, double.maxFinite) / 1e8;
        from = '';
        to = _bchToLegacy(recipient);
      } else {
        dir = TxDirection.incoming;
        amt = receivedSats / 1e8;
        final rawSender = inputs
            .whereType<Map<String, dynamic>>()
            .map((i) => (i['recipient'] as String?) ?? '')
            .firstWhere((a) => a != bareAddr && a.isNotEmpty, orElse: () => '');
        from = _bchToLegacy(rawSender);
        to = '';
      }

      records.add(
        TxRecord(
          hash: hash,
          from: from,
          to: to,
          amount: amt,
          symbol: symbol,
          timestamp: ts,
          direction: dir,
          confirmed: true,
          blockchain: blockchain,
          feePaid: null,
        ),
      );
    } catch (_) {
      continue;
    }
  }
  return records;
});

Future<List<TxRecord>> fetchLitecoinHistory({required String address, int limit = 50}) =>
    guardNetwork(() async {
      // litecoinspace.org returns full TX objects (vin + vout) — gives us exact
      // sent/received amounts, correct direction, and the recipient address.
      final uri = Uri.parse('${APIConfig.litecoinspaceBase}/api/address/$address/txs');
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return [];
      final txList = jsonDecode(resp.body) as List<dynamic>;

      final records = <TxRecord>[];
      for (final raw in txList.take(limit)) {
        try {
          final tx = raw as Map<String, dynamic>;
          final hash = tx['txid'] as String;
          final status = (tx['status'] as Map<String, dynamic>?) ?? {};
          final confirmed = status['confirmed'] as bool? ?? false;
          final blockTime = status['block_time'] as int?;
          final ts = blockTime != null
              ? DateTime.fromMillisecondsSinceEpoch(blockTime * 1000)
              : DateTime.now();

          // Sats we spent (our address in vin[].prevout)
          int sentSats = 0;
          for (final vin in (tx['vin'] as List<dynamic>? ?? [])) {
            final v = vin as Map<String, dynamic>;
            final prevout = v['prevout'] as Map<String, dynamic>?;
            if (prevout?['scriptpubkey_address'] == address) {
              sentSats += (prevout?['value'] as int? ?? 0);
            }
          }

          // Sats we received (our address in vout[]) + first external recipient
          int receivedSats = 0;
          String recipient = '';
          for (final vout in (tx['vout'] as List<dynamic>? ?? [])) {
            final v = vout as Map<String, dynamic>;
            final addr = v['scriptpubkey_address'] as String?;
            final val = v['value'] as int? ?? 0;
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
            dir = TxDirection.outgoing;
            amt = (sentSats - receivedSats).clamp(0, double.maxFinite) / 1e8;
            from = '';
            to = recipient;
          } else {
            dir = TxDirection.incoming;
            amt = receivedSats / 1e8;
            String senderAddr = '';
            for (final vin in (tx['vin'] as List<dynamic>? ?? [])) {
              final v = vin as Map<String, dynamic>;
              final prevout = v['prevout'] as Map<String, dynamic>?;
              final vinAddr = prevout?['scriptpubkey_address'] as String?;
              if (vinAddr != null && vinAddr != address) {
                senderAddr = vinAddr;
                break;
              }
            }
            from = senderAddr;
            to = '';
          }

          records.add(
            TxRecord(
              hash: hash,
              from: from,
              to: to,
              amount: amt,
              symbol: 'LTC',
              timestamp: ts,
              direction: dir,
              confirmed: confirmed,
              blockchain: 'litecoin',
              feePaid: null,
            ),
          );
        } catch (_) {
          continue;
        }
      }
      return records;
    });

Future<List<TxRecord>> fetchBitcoinHistory({required String address, int limit = 50}) =>
    guardNetwork(() async {
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

      records.add(
        TxRecord(
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
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[TxHistory] BTC parse error: $e');
      continue;
    }
  }

  return records;
}
