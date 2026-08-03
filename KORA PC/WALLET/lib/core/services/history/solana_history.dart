import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kora_windows/core/config/api_config.dart';
import 'package:kora_windows/core/models/tx_record.dart';
import 'package:kora_windows/core/services/history/network_guard.dart';

// Transaction history for Solana, for SOL itself and for SPL tokens.

Future<List<TxRecord>> fetchSolanaHistory({required String address, int limit = 25}) =>
    guardNetwork(() async {
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
          final ts = (tx['timestamp'] as num? ?? 0).toInt();
          final fee = (tx['fee'] as num? ?? 0).toDouble() / 1e9;

          final nativeTransfers = (tx['nativeTransfers'] as List<dynamic>?) ?? [];
          for (final transfer in nativeTransfers) {
            final t = transfer as Map<String, dynamic>;
            final from = (t['fromUserAccount'] as String?) ?? '';
            final to = (t['toUserAccount'] as String?) ?? '';
            final amount = (t['amount'] as num? ?? 0).toDouble() / 1e9;
            if (amount <= 0) continue;
            if (from != address && to != address) continue;

            final dir = to == address ? TxDirection.incoming : TxDirection.outgoing;
            records.add(
              TxRecord(
                hash: sig,
                from: from,
                to: to,
                amount: amount,
                symbol: 'SOL',
                timestamp: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
                direction: dir,
                confirmed: true,
                blockchain: 'solana',
                feePaid: fee,
              ),
            );
            break;
          }
        } catch (_) {
          continue;
        }
      }
      return records;
    });

Future<List<TxRecord>> fetchSolanaTokenHistory({
  required String ownerAddress,
  required String mintAddress,
  required String symbol,
  required int decimals,
  int limit = 25,
}) => guardNetwork(() async {
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
      final ts = (tx['timestamp'] as num? ?? 0).toInt();
      final fee = (tx['fee'] as num? ?? 0).toDouble() / 1e9;

      final tokenTransfers = (tx['tokenTransfers'] as List<dynamic>?) ?? [];
      for (final transfer in tokenTransfers) {
        final t = transfer as Map<String, dynamic>;
        if ((t['mint'] as String?) != mintAddress) continue;

        final from = (t['fromUserAccount'] as String?) ?? '';
        final to = (t['toUserAccount'] as String?) ?? '';
        final amount = (t['tokenAmount'] as num? ?? 0).toDouble();
        if (amount <= 0) continue;
        if (from != ownerAddress && to != ownerAddress) continue;

        final dir = to == ownerAddress ? TxDirection.incoming : TxDirection.outgoing;
        records.add(
          TxRecord(
            hash: sig,
            from: from,
            to: to,
            amount: amount,
            symbol: symbol,
            timestamp: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
            direction: dir,
            confirmed: true,
            blockchain: 'solana',
            feePaid: fee,
          ),
        );
        break;
      }
    } catch (_) {
      continue;
    }
  }
  return records;
});
