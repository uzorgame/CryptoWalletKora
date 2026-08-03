import 'package:kora_windows/core/crypto/seed.dart';
import 'package:kora_windows/core/crypto/hd_wallet.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora_windows/core/config/api_config.dart';
import 'package:kora_windows/core/models/asset.dart';
import 'package:kora_windows/core/blockchain/bitcoin/bitcoin_wallet.dart';
import 'package:kora_windows/core/blockchain/bitcoin/bitcoin_transaction.dart';
import 'package:kora_windows/core/blockchain/bitcoin/bitcoin_signer.dart';
import 'package:kora_windows/core/blockchain/bitcoin/bitcoin_service.dart';
import 'package:kora_windows/features/send/services/transaction_executor.dart';
import 'package:kora_windows/features/send/fee/models/fee_estimate.dart';
import 'package:kora_windows/features/send/fee/services/fee_api_service.dart';
import 'package:kora_windows/features/send/fee/bitcoin_fee/bitcoin_fee_service.dart';
import 'package:kora_windows/features/send/fee/litecoin_fee/litecoin_fee_service.dart';
import 'package:kora_windows/features/send/fee/bitcoin_cash_fee/bitcoin_cash_fee_service.dart';

class UtxoExecutor implements TransactionExecutor {
  final String _chain;
  final int? _feeRateOverride;
  UtxoExecutor([this._chain = 'bitcoin', this._feeRateOverride]);

  @override
  String get blockchain => _chain;

  @override
  String? validateAddress(String address) {
    if (_chain == 'bitcoin') {
      return (address.startsWith('bc1') || address.startsWith('1') || address.startsWith('3'))
          ? null : 'Invalid BTC address — must start with bc1, 1, or 3';
    }
    if (_chain == 'litecoin') {
      return (address.startsWith('ltc1') || address.startsWith('L') || address.startsWith('M'))
          ? null : 'Invalid LTC address';
    }
    if (_chain == 'bitcoin_cash') {
      return (address.startsWith('bitcoincash:') || address.startsWith('q') ||
              address.startsWith('1') || address.startsWith('3'))
          ? null : 'Invalid BCH address';
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
      // Derived off the interface thread — see core/crypto/seed.dart.
      final w = BitcoinWallet.fromHdWallet(HDWallet.fromSeed(await mnemonicSeed(mnemonic)));
      privKeyHex = w.privateKey;
      pubKeyHex = w.publicKey;
    } else if (asset.blockchain == 'litecoin') {
      final keys = BitcoinWallet.keysForCoinTypeSegwit(mnemonic, coinType: 2);
      privKeyHex = keys.privateKeyHex;
      pubKeyHex = keys.pubKeyHex;
    } else {
      final keys = BitcoinWallet.keysForCoinType(mnemonic, coinType: coinType);
      privKeyHex = keys.privateKeyHex;
      pubKeyHex = keys.pubKeyHex;
    }

    final utxos = await _fetchUtxos(asset.contractAddress, asset.blockchain);
    final satoshis = toTokenAmount(amount, 8).toInt();

    int satPerVByte;
    if (_feeRateOverride != null) {
      satPerVByte = max(1, _feeRateOverride);
    } else {
      final feeService = _feeServiceFor(asset.blockchain);
      FeeEstimate? est;
      try {
        est = await feeService.fetchFee(speed: FeeSpeed.normal);
      } catch (_) {
        try { est = await feeService.fetchFeeFromBackup(speed: FeeSpeed.normal); } catch (_) {}
      }
      satPerVByte = max(2, (est?.details?['satPerVByte'] as num?)?.toInt() ?? 10);
    }

    final senderAddr = asset.contractAddress;
    final sorted = List<UTXO>.from(utxos)..sort((a, b) => b.value.compareTo(a.value));
    final selected = <UTXO>[];
    var totalIn = 0;
    for (final u in sorted) {
      selected.add(u);
      totalIn += u.value;
      final vb = _calcVBytes(selected.length, senderAddr, toAddress);
      if (totalIn >= satoshis + satPerVByte * vb) break;
    }

    if (totalIn < satoshis) {
      throw Exception('Insufficient balance: need $satoshis sats, have $totalIn sats');
    }

    final vBytes = _calcVBytes(selected.length, senderAddr, toAddress);
    var feeSats = satPerVByte * vBytes;
    var sendSats = satoshis;
    var change = totalIn - sendSats - feeSats;

    const dustLimit = 546;
    if (change < 0 || (change > 0 && change <= dustLimit)) {
      final vBytesNoChange = _calcVBytesNoChange(selected.length, senderAddr, toAddress);
      final feeNoChange = satPerVByte * vBytesNoChange;
      if (totalIn >= sendSats + feeNoChange) {
        feeSats = totalIn - sendSats;
      } else {
        final maxSendable = totalIn - feeNoChange;
        final shortfall = sendSats - maxSendable;
        final autoAdjustLimit = max(1000, sendSats ~/ 100);
        if (maxSendable > 0 && shortfall <= autoAdjustLimit) {
          if (kDebugMode) debugPrint('[UTXO] Adjusting send: $sendSats → $maxSendable sats');
          sendSats = maxSendable;
          feeSats = feeNoChange;
        } else {
          throw Exception('Insufficient balance: need ${sendSats + feeNoChange} sats, have $totalIn sats');
        }
      }
    }

    if (totalIn < sendSats + feeSats) {
      throw Exception('Insufficient balance: need ${sendSats + feeSats} sats, have $totalIn sats');
    }

    final builder = BitcoinTransactionBuilder()
      ..addInputs(selected)
      ..addOutput(toAddress, sendSats);
    final txResult = builder.build(changeAddress: asset.contractAddress, fee: feeSats);

    final addr = asset.contractAddress;
    final txHex = switch (true) {
      _ when addr.startsWith('bc1') || addr.startsWith('ltc1') =>
        BitcoinSigner.signP2WPKH(txResult: txResult, privateKeyHex: privKeyHex, compressedPubKeyHex: pubKeyHex),
      _ when asset.blockchain == 'bitcoin_cash' =>
        BitcoinSigner.signP2PKHBCH(txResult: txResult, privateKeyHex: privKeyHex, compressedPubKeyHex: pubKeyHex),
      _ =>
        BitcoinSigner.signP2PKH(txResult: txResult, privateKeyHex: privKeyHex, compressedPubKeyHex: pubKeyHex),
    };

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

  Future<List<UTXO>> _fetchUtxos(String address, String blockchain) => switch (blockchain) {
        'litecoin'     => _fetchLtcUtxos(address),
        'bitcoin_cash' => _fetchBchUtxos(address),
        _              => _fetchBtcUtxos(address),
      };

  Future<String> _broadcast(String txHex, String blockchain) => switch (blockchain) {
        'litecoin'     => _broadcastLtc(txHex),
        'bitcoin_cash' => _broadcastBch(txHex),
        _              => _broadcastBtc(txHex),
      };

  Future<List<UTXO>> _fetchBtcUtxos(String address) async {
    final resp = await http.get(Uri.parse('${APIConfig.mempoolSpaceBase}/api/address/$address/utxo')).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('BTC UTXO fetch failed: ${resp.statusCode}');
    final list = jsonDecode(resp.body) as List<dynamic>;
    if (list.isEmpty) throw Exception('No spendable UTXOs');
    return list.map((u) {
      final m = u as Map<String, dynamic>;
      final status = m['status'] as Map<String, dynamic>? ?? {};
      return UTXO(txHash: m['txid'] as String, outputIndex: m['vout'] as int, value: m['value'] as int, scriptPubKey: null, confirmations: (status['confirmed'] as bool? ?? false) ? 1 : 0);
    }).toList();
  }

  Future<String> _broadcastBtc(String txHex) async {
    final resp = await http.post(Uri.parse('${APIConfig.mempoolSpaceBase}/api/tx'), headers: {'Content-Type': 'text/plain'}, body: txHex).timeout(const Duration(seconds: 20));
    if (resp.statusCode == 200 || resp.statusCode == 201) { final hash = resp.body.trim(); if (hash.isNotEmpty) return hash; }
    throw Exception('BTC broadcast failed (${resp.statusCode}): ${resp.body}');
  }

  Future<List<UTXO>> _fetchLtcUtxos(String address) async {
    final resp = await http.get(Uri.parse('${APIConfig.litecoinspaceBase}/api/address/$address/utxo')).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('LTC UTXO fetch failed: ${resp.statusCode}');
    final list = jsonDecode(resp.body) as List<dynamic>;
    if (list.isEmpty) throw Exception('No spendable UTXOs');
    return list.map((u) {
      final m = u as Map<String, dynamic>;
      final status = m['status'] as Map<String, dynamic>? ?? {};
      return UTXO(txHash: m['txid'] as String, outputIndex: m['vout'] as int, value: m['value'] as int, scriptPubKey: null, confirmations: (status['confirmed'] as bool? ?? false) ? 1 : 0);
    }).toList();
  }

  Future<String> _broadcastLtc(String txHex) async {
    final resp = await http.post(Uri.parse('${APIConfig.litecoinspaceBase}/api/tx'), headers: {'Content-Type': 'text/plain'}, body: txHex).timeout(const Duration(seconds: 20));
    if (resp.statusCode == 200 || resp.statusCode == 201) { final hash = resp.body.trim(); if (hash.isNotEmpty) return hash; }
    throw Exception('LTC broadcast failed (${resp.statusCode}): ${resp.body}');
  }

  Future<List<UTXO>> _fetchBchUtxos(String address) async {
    final bare = address.startsWith('bitcoincash:') ? address.substring(12) : address;
    final resp = await http.get(Uri.parse('${APIConfig.haskoinBchBase}/address/$bare/unspent')).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('BCH UTXO fetch failed: ${resp.statusCode}');
    final list = jsonDecode(resp.body) as List<dynamic>;
    if (list.isEmpty) throw Exception('No spendable UTXOs');
    return list.map((u) {
      final m = u as Map<String, dynamic>;
      return UTXO(txHash: m['txid'] as String, outputIndex: m['index'] as int, value: m['value'] as int, scriptPubKey: m['pkscript'] as String?, confirmations: (m['confirmations'] as num?)?.toInt() ?? 0);
    }).toList();
  }

  Future<String> _broadcastBch(String txHex) async {
    final resp = await http.post(Uri.parse('${APIConfig.haskoinBchBase}/transactions'), headers: {'Content-Type': 'text/plain'}, body: txHex).timeout(const Duration(seconds: 20));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final body = jsonDecode(resp.body);
      if (body is String && body.isNotEmpty) return body;
      if (body is Map) { final hash = body['txid'] ?? body['transaction_hash'] ?? body['id']; if (hash is String && hash.isNotEmpty) return hash; }
    }
    throw Exception('BCH broadcast failed (${resp.statusCode}): ${resp.body}');
  }

  int _calcVBytes(int inputCount, String senderAddress, String recipientAddress) {
    final isSegWit = senderAddress.startsWith('bc1') || senderAddress.startsWith('ltc1');
    return (isSegWit ? 11 : 10) + (isSegWit ? 68 : 148) * inputCount + _recipientOutputVBytes(recipientAddress) + (isSegWit ? 31 : 34);
  }

  int _calcVBytesNoChange(int inputCount, String senderAddress, String recipientAddress) {
    final isSegWit = senderAddress.startsWith('bc1') || senderAddress.startsWith('ltc1');
    return (isSegWit ? 11 : 10) + (isSegWit ? 68 : 148) * inputCount + _recipientOutputVBytes(recipientAddress);
  }

  int _recipientOutputVBytes(String address) {
    if (address.startsWith('bitcoincash:q') || address.startsWith('bchtest:q')) return 34;
    if (address.startsWith('bitcoincash:p') || address.startsWith('bchtest:p')) return 32;
    final p = address.isEmpty ? '' : address[0];
    if (p == '1' || p == 'm' || p == 'n' || p == 'L' || p == 'C') return 34;
    if (p == '3' || p == '2' || p == 'M') return 32;
    return 31;
  }
}
