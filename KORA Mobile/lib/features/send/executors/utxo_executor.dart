// UTXO chains executor (Bitcoin, Litecoin, Bitcoin Cash)

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/blockchain/bitcoin/bitcoin_wallet.dart';
import 'package:kora/core/blockchain/bitcoin/bitcoin_transaction.dart';
import 'package:kora/core/blockchain/bitcoin/bitcoin_signer.dart';
import 'package:kora/core/blockchain/bitcoin/bitcoin_service.dart';
import 'package:kora/features/send/services/transaction_executor.dart';
import 'package:kora/features/send/fee/models/fee_estimate.dart';
import 'package:kora/features/send/fee/services/fee_api_service.dart';
import 'package:kora/features/send/fee/bitcoin_fee/bitcoin_fee_service.dart';
import 'package:kora/features/send/fee/litecoin_fee/litecoin_fee_service.dart';
import 'package:kora/features/send/fee/bitcoin_cash_fee/bitcoin_cash_fee_service.dart';

class UtxoExecutor implements TransactionExecutor {
  final String _chain;
  final int? _feeRateOverride; // sat/vByte from the UI-selected speed
  UtxoExecutor([this._chain = 'bitcoin', this._feeRateOverride]);

  @override
  String get blockchain => _chain;

  @override
  String? validateAddress(String address) {
    final chain = _chain;
    if (chain == 'bitcoin') {
      return (address.startsWith('bc1') || address.startsWith('1') || address.startsWith('3'))
          ? null
          : 'Invalid BTC address — must start with bc1, 1, or 3';
    }
    if (chain == 'litecoin') {
      return (address.startsWith('ltc1') || address.startsWith('L') || address.startsWith('M'))
          ? null
          : 'Invalid LTC address';
    }
    if (chain == 'bitcoin_cash') {
      return (address.startsWith('bitcoincash:') || address.startsWith('q') ||
              address.startsWith('1') || address.startsWith('3'))
          ? null
          : 'Invalid BCH address';
    }
    return 'Unsupported UTXO chain';
  }

  @override
  Future<String> execute({
    required String mnemonic,
    required Asset asset,
    required String toAddress,
    required String amount,
  }) async {
    final coinType = _utxoCoinType(asset.blockchain);

    final String privKeyHex, pubKeyHex;
    if (asset.blockchain == 'bitcoin') {
      final w = BitcoinWallet.fromMnemonic(mnemonic);
      privKeyHex = w.privateKey;
      pubKeyHex = w.publicKey;
    } else if (asset.blockchain == 'litecoin') {
      // LTC uses BIP84 SegWit (m/84'/2'/0'/0/0) — matches addressForLtcSegwit
      final keys = BitcoinWallet.keysForCoinTypeSegwit(mnemonic, coinType: 2);
      privKeyHex = keys.privateKeyHex;
      pubKeyHex = keys.pubKeyHex;
    } else {
      final keys = BitcoinWallet.keysForCoinType(mnemonic, coinType: coinType);
      privKeyHex = keys.privateKeyHex;
      pubKeyHex = keys.pubKeyHex;
    }

    // ── UTXO fetch ───────────────────────────────────────────────────
    final utxos = await _fetchUtxos(asset.contractAddress, asset.blockchain);

    final satoshis = toTokenAmount(amount, 8).toInt();

    // 1. Determine fee rate (sat/vByte)
    int satPerVByte;
    if (_feeRateOverride != null) {
      // Respect user-selected fee rate; min 1 sat/vByte (BCH regularly uses 1)
      satPerVByte = max(1, _feeRateOverride);
    } else {
      final feeService = _feeServiceFor(asset.blockchain);
      FeeEstimate? est;
      try {
        est = await feeService.fetchFee(speed: FeeSpeed.normal);
      } catch (_) {
        try {
          est = await feeService.fetchFeeFromBackup(speed: FeeSpeed.normal);
        } catch (_) {}
      }
      satPerVByte = max(2, (est?.details?['satPerVByte'] as num?)?.toInt() ?? 10);
    }

    // 2. Select UTXOs largest-first until amount + fee covered
    final senderAddr = asset.contractAddress;
    final sorted = List<UTXO>.from(utxos)
      ..sort((a, b) => b.value.compareTo(a.value));
    final selected = <UTXO>[];
    var totalIn = 0;
    for (final u in sorted) {
      selected.add(u);
      totalIn += u.value;
      final vb = _calcVBytes(selected.length, senderAddr, toAddress);
      if (totalIn >= satoshis + satPerVByte * vb) break;
    }

    // Early guard: if all UTXOs can't even cover the raw amount (ignoring fee)
    if (totalIn < satoshis) {
      throw Exception(
          'Insufficient balance: need $satoshis sats, have $totalIn sats');
    }

    final vBytes = _calcVBytes(selected.length, senderAddr, toAddress);
    var feeSats = satPerVByte * vBytes;
    var sendSats = satoshis;
    var change = totalIn - sendSats - feeSats;

    // ── Handle edge cases: negative change or dust change ──────────────
    //
    // Problem: the fee displayed in the UI is estimated with fewer inputs
    // than the executor may actually need, so amount + realFee > balance.
    //
    // Solution:
    //   1. If change < 0 or change ≤ dust → recalculate fee WITHOUT a
    //      change output (saves 31-34 bytes).
    //   2. If still short by a SMALL margin (≤ 1% of send amount or
    //      ≤ 1000 sats), auto-adjust the send amount down.  This covers
    //      the "send max" case where the fee estimate was slightly off.
    //   3. If the shortfall is large → throw (genuinely insufficient).
    //
    const dustLimit = 546;
    if (change < 0 || (change > 0 && change <= dustLimit)) {
      final vBytesNoChange = _calcVBytesNoChange(selected.length, senderAddr, toAddress);
      final feeNoChange = satPerVByte * vBytesNoChange;

      if (totalIn >= sendSats + feeNoChange) {
        // Requested amount fits without change — remainder goes to miner
        feeSats = totalIn - sendSats;
      } else {
        // Even without change, still short.
        // Auto-adjust ONLY if the shortfall is small (fee estimation error).
        final maxSendable = totalIn - feeNoChange;
        final shortfall = sendSats - maxSendable;
        // Allow auto-adjust up to 1% of send amount or 1000 sats (whichever is larger)
        final autoAdjustLimit = max(1000, sendSats ~/ 100);

        if (maxSendable > 0 && shortfall <= autoAdjustLimit) {
          if (kDebugMode) debugPrint('[UTXO] Adjusting send: $sendSats → $maxSendable sats (fee correction, $shortfall sats difference)');
          sendSats = maxSendable;
          feeSats = feeNoChange;
        } else {
          throw Exception(
              'Insufficient balance: need ${sendSats + feeNoChange} sats, have $totalIn sats');
        }
      }
    }

    if (totalIn < sendSats + feeSats) {
      throw Exception(
          'Insufficient balance: need ${sendSats + feeSats} sats, have $totalIn sats');
    }

    // 3. Build transaction
    final builder = BitcoinTransactionBuilder()
      ..addInputs(selected)
      ..addOutput(toAddress, sendSats);
    final txResult = builder.build(
      changeAddress: asset.contractAddress,
      fee: feeSats,
    );

    // 4. Sign based on address type / chain
    final addr = asset.contractAddress;
    final txHex = switch (true) {
      _ when addr.startsWith('bc1') || addr.startsWith('ltc1') =>
        BitcoinSigner.signP2WPKH(
            txResult: txResult,
            privateKeyHex: privKeyHex,
            compressedPubKeyHex: pubKeyHex),
      _ when asset.blockchain == 'bitcoin_cash' =>
        BitcoinSigner.signP2PKHBCH(
            txResult: txResult,
            privateKeyHex: privKeyHex,
            compressedPubKeyHex: pubKeyHex),
      _ =>
        BitcoinSigner.signP2PKH(
            txResult: txResult,
            privateKeyHex: privKeyHex,
            compressedPubKeyHex: pubKeyHex),
    };

    // 5. Broadcast
    return await _broadcast(txHex, asset.blockchain);
  }

  FeeApiService _feeServiceFor(String blockchain) => switch (blockchain) {
        'litecoin'     => LitecoinFeeService(),
        'bitcoin_cash' => BitcoinCashFeeService(),
        _              => BitcoinFeeService(),
      };

  int _utxoCoinType(String b) => switch (b) {
        'litecoin'     => 2,
        'bitcoin_cash' => 145,
        _              => 0,
      };

  /// Dispatch UTXO fetch to the correct per-chain API.
  Future<List<UTXO>> _fetchUtxos(String address, String blockchain) =>
      switch (blockchain) {
        'litecoin'     => _fetchLtcUtxos(address),
        'bitcoin_cash' => _fetchBchUtxos(address),
        _              => _fetchBtcUtxos(address),
      };

  /// Dispatch broadcast to the correct per-chain API.
  Future<String> _broadcast(String txHex, String blockchain) =>
      switch (blockchain) {
        'litecoin'     => _broadcastLtc(txHex),
        'bitcoin_cash' => _broadcastBch(txHex),
        _              => _broadcastBtc(txHex),
      };

  // ── BTC: mempool.space ───────────────────────────────────────────────────
  Future<List<UTXO>> _fetchBtcUtxos(String address) async {
    final uri  = Uri.parse('${APIConfig.mempoolSpaceBase}/api/address/$address/utxo');
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('BTC UTXO fetch failed: ${resp.statusCode}');
    final list = jsonDecode(resp.body) as List<dynamic>;
    if (list.isEmpty) throw Exception('No spendable UTXOs');
    return list.map((u) {
      final m      = u as Map<String, dynamic>;
      final status = m['status'] as Map<String, dynamic>? ?? {};
      return UTXO(
        txHash:        m['txid']  as String,
        outputIndex:   m['vout']  as int,
        value:         m['value'] as int,
        scriptPubKey:  null,
        confirmations: (status['confirmed'] as bool? ?? false) ? 1 : 0,
      );
    }).toList();
  }

  Future<String> _broadcastBtc(String txHex) async {
    final resp = await http.post(
      Uri.parse('${APIConfig.mempoolSpaceBase}/api/tx'),
      headers: {'Content-Type': 'text/plain'},
      body: txHex,
    ).timeout(const Duration(seconds: 20));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final hash = resp.body.trim();
      if (hash.isNotEmpty) return hash;
    }
    throw Exception('BTC broadcast failed (${resp.statusCode}): ${resp.body}');
  }

  // ── LTC: litecoinspace.org ───────────────────────────────────────────────
  Future<List<UTXO>> _fetchLtcUtxos(String address) async {
    final uri  = Uri.parse('${APIConfig.litecoinspaceBase}/api/address/$address/utxo');
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('LTC UTXO fetch failed: ${resp.statusCode}');
    final list = jsonDecode(resp.body) as List<dynamic>;
    if (list.isEmpty) throw Exception('No spendable UTXOs');
    return list.map((u) {
      final m      = u as Map<String, dynamic>;
      final status = m['status'] as Map<String, dynamic>? ?? {};
      return UTXO(
        txHash:        m['txid']  as String,
        outputIndex:   m['vout']  as int,
        value:         m['value'] as int,
        scriptPubKey:  null,
        confirmations: (status['confirmed'] as bool? ?? false) ? 1 : 0,
      );
    }).toList();
  }

  Future<String> _broadcastLtc(String txHex) async {
    final resp = await http.post(
      Uri.parse('${APIConfig.litecoinspaceBase}/api/tx'),
      headers: {'Content-Type': 'text/plain'},
      body: txHex,
    ).timeout(const Duration(seconds: 20));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final hash = resp.body.trim();
      if (hash.isNotEmpty) return hash;
    }
    throw Exception('LTC broadcast failed (${resp.statusCode}): ${resp.body}');
  }

  // ── BCH: Haskoin ─────────────────────────────────────────────────────────
  Future<List<UTXO>> _fetchBchUtxos(String address) async {
    final bare = address.startsWith('bitcoincash:') ? address.substring(12) : address;
    final uri  = Uri.parse('${APIConfig.haskoinBchBase}/address/$bare/unspent');
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('BCH UTXO fetch failed: ${resp.statusCode}');
    final list = jsonDecode(resp.body) as List<dynamic>;
    if (list.isEmpty) throw Exception('No spendable UTXOs');
    return list.map((u) {
      final m = u as Map<String, dynamic>;
      return UTXO(
        txHash:        m['txid']          as String,
        outputIndex:   m['index']         as int,
        value:         m['value']         as int,
        scriptPubKey:  m['pkscript']      as String?,
        confirmations: (m['confirmations'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<String> _broadcastBch(String txHex) async {
    final resp = await http.post(
      Uri.parse('${APIConfig.haskoinBchBase}/transactions'),
      headers: {'Content-Type': 'text/plain'},
      body: txHex,
    ).timeout(const Duration(seconds: 20));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final body = jsonDecode(resp.body);
      if (body is String && body.isNotEmpty) return body;
      if (body is Map) {
        final hash = body['txid'] ?? body['transaction_hash'] ?? body['id'];
        if (hash is String && hash.isNotEmpty) return hash;
      }
    }
    throw Exception('BCH broadcast failed (${resp.statusCode}): ${resp.body}');
  }

  /// vByte estimate accounting for sender address type (WITH change output).
  /// SegWit sender (bc1/ltc1): 11 overhead + 68 vB/input + change 31 vB.
  /// P2PKH sender (1/L): 10 overhead + 148 B/input + change 34 B.
  int _calcVBytes(int inputCount, String senderAddress, String recipientAddress) {
    final isSegWit = senderAddress.startsWith('bc1') || senderAddress.startsWith('ltc1');
    final overhead   = isSegWit ? 11 : 10;
    final inputBytes = isSegWit ? 68 : 148;
    final changeBytes = isSegWit ? 31 : 34;
    return overhead + inputBytes * inputCount + _recipientOutputVBytes(recipientAddress) + changeBytes;
  }

  /// vByte estimate WITHOUT change output (for send-max / dust-change cases).
  int _calcVBytesNoChange(int inputCount, String senderAddress, String recipientAddress) {
    final isSegWit = senderAddress.startsWith('bc1') || senderAddress.startsWith('ltc1');
    final overhead   = isSegWit ? 11 : 10;
    final inputBytes = isSegWit ? 68 : 148;
    return overhead + inputBytes * inputCount + _recipientOutputVBytes(recipientAddress);
  }

  /// Output script size in bytes:
  ///   P2PKH  (1… / L… / m… / CashAddr q…) = 34 bytes
  ///   P2SH   (3… / 2… / CashAddr p…)         = 32 bytes
  ///   P2WPKH (bc1q / ltc1q)                   = 31 bytes  ← default
  int _recipientOutputVBytes(String address) {
    if (address.startsWith('bitcoincash:q') || address.startsWith('bchtest:q')) return 34;
    if (address.startsWith('bitcoincash:p') || address.startsWith('bchtest:p')) return 32;
    final p = address.isEmpty ? '' : address[0];
    if (p == '1' || p == 'm' || p == 'n' || p == 'L' || p == 'C') return 34;
    if (p == '3' || p == '2' || p == 'M') return 32;
    return 31;
  }

}
