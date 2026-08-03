import 'package:flutter/foundation.dart';
import 'package:kora_windows/core/constants/token_catalog.dart';
import 'package:kora_windows/core/models/asset.dart';

/// Service that validates all supported tokens/blockchains at app startup.
/// Checks: Send, Recv, Hist, Bal, Price capabilities.
/// Only runs in debug mode.
class TokenValidationService {
  /// Supported executors for Send functionality
  static const _sendExecutors = {
    'bitcoin', 'ethereum', 'solana', 'tron', 'litecoin',
    'bsc',
    'ethereum_classic', 'bitcoin_cash',
    // 'monero' intentionally omitted — ring sigs require libmonero-wallet-rpc
  };

  /// Blockchains with address derivation (Recv capability)
  static const _recvSupported = {
    'bitcoin', 'ethereum', 'solana', 'tron', 'litecoin',
    'bsc',
    'ethereum_classic', 'bitcoin_cash',
  };

  /// Blockchains with history fetching
  static const _histSupported = {
    'bitcoin', 'ethereum', 'solana', 'tron', 'litecoin',
    'bsc',
    'ethereum_classic', 'bitcoin_cash',
  };

  /// Blockchains intentionally unsupported for Send (complex crypto, no public signing API)
  static const _intentionallyUnsupported = <String>{};

  /// Blockchains with balance fetching
  static const _balSupported = {
    'bitcoin', 'ethereum', 'solana', 'tron', 'litecoin',
    'bsc',
    'ethereum_classic', 'bitcoin_cash',
  };

  /// Run comprehensive validation of all tokens at startup.
  /// Only runs in debug mode.
  static Future<void> validateAllTokens() async {
    if (!kDebugMode) return;

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════════════════════');
    debugPrint('                    TOKEN VALIDATION REPORT                                 ');
    debugPrint('═══════════════════════════════════════════════════════════════════════════');
    debugPrint('');

    final tokens = allCatalogTokens;
    final uniqueBlockchains = tokens.map((t) => t.blockchain).toSet().toList()..sort();

    debugPrint('📊 Total tokens: ${tokens.length}');
    debugPrint('🔗 Unique blockchains: ${uniqueBlockchains.length}');
    debugPrint('');

    // Validate each blockchain
    int sendOk = 0, recvOk = 0, histOk = 0, balOk = 0, priceOk = 0;
    int sendFail = 0, recvFail = 0, histFail = 0, balFail = 0, priceFail = 0;

    for (final blockchain in uniqueBlockchains) {
      final tokensOnChain = tokens.where((t) => t.blockchain == blockchain).toList();
      final nativeToken = tokensOnChain.firstWhere(
        (t) => t.type == AssetType.native,
        orElse: () => tokensOnChain.first,
      );

      final send = _sendExecutors.contains(blockchain);
      final recv = _recvSupported.contains(blockchain);
      final hist = _histSupported.contains(blockchain);
      final bal = _balSupported.contains(blockchain);
      final price = _hasCoinGeckoId(nativeToken.coinGeckoId);

      if (send) sendOk++; else sendFail++;
      if (recv) recvOk++; else recvFail++;
      if (hist) histOk++; else histFail++;
      if (bal) balOk++; else balFail++;
      if (price) priceOk++; else priceFail++;

      final sendIcon = send ? '✅' : '❌';
      final recvIcon = recv ? '✅' : '❌';
      final histIcon = hist ? '✅' : '❌';
      final balIcon = bal ? '✅' : '❌';
      final priceIcon = price ? '✅' : '❌';

      final symbol = nativeToken.symbol.padRight(8);
      final chain = blockchain.padRight(20);
      
      debugPrint('$symbol $chain  Send:$sendIcon  Recv:$recvIcon  Hist:$histIcon  Bal:$balIcon  Price:$priceIcon');
    }

    debugPrint('');
    debugPrint('───────────────────────────────────────────────────────────────────────────');
    debugPrint('                           SUMMARY                                          ');
    debugPrint('───────────────────────────────────────────────────────────────────────────');
    debugPrint('Send:   ✅ $sendOk  ❌ $sendFail  (${_percentage(sendOk, uniqueBlockchains.length)}%)');
    debugPrint('Recv:   ✅ $recvOk  ❌ $recvFail  (${_percentage(recvOk, uniqueBlockchains.length)}%)');
    debugPrint('Hist:   ✅ $histOk  ❌ $histFail  (${_percentage(histOk, uniqueBlockchains.length)}%)');
    debugPrint('Bal:    ✅ $balOk  ❌ $balFail  (${_percentage(balOk, uniqueBlockchains.length)}%)');
    debugPrint('Price:  ✅ $priceOk  ❌ $priceFail  (${_percentage(priceOk, uniqueBlockchains.length)}%)');
    debugPrint('');

    // Check for missing implementations (split real gaps from intentional)
    final missingSend = uniqueBlockchains.where((b) => !_sendExecutors.contains(b)).toList();
    final missingRecv = uniqueBlockchains.where((b) => !_recvSupported.contains(b)).toList();
    final missingHist = uniqueBlockchains.where((b) => !_histSupported.contains(b)).toList();
    final missingBal  = uniqueBlockchains.where((b) => !_balSupported.contains(b)).toList();

    _reportMissing('Send',    missingSend);
    _reportMissing('Recv',    missingRecv);
    _reportMissing('History', missingHist);
    _reportMissing('Balance', missingBal);

    // Check for tokens with missing CoinGecko IDs
    final missingPrice = tokens.where((t) => !_hasCoinGeckoId(t.coinGeckoId)).toList();
    if (missingPrice.isNotEmpty) {
      debugPrint('');
      debugPrint('⚠️  Tokens with missing/invalid CoinGecko IDs:');
      for (final token in missingPrice) {
        debugPrint('   - ${token.symbol} (${token.blockchain}): "${token.coinGeckoId}"');
      }
    }

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════════════════════');
    debugPrint('');
  }

  /// Validate a specific token and return detailed report
  static Map<String, bool> validateToken(CatalogToken token) {
    return {
      'send': _sendExecutors.contains(token.blockchain),
      'recv': _recvSupported.contains(token.blockchain),
      'hist': _histSupported.contains(token.blockchain),
      'bal': _balSupported.contains(token.blockchain),
      'price': _hasCoinGeckoId(token.coinGeckoId),
    };
  }

  static void _reportMissing(String aspect, List<String> missing) {
    if (missing.isEmpty) return;
    final real       = missing.where((b) => !_intentionallyUnsupported.contains(b)).toList();
    final intentional = missing.where((b) =>  _intentionallyUnsupported.contains(b)).toList();
    if (real.isNotEmpty) {
      debugPrint('⚠️  Missing $aspect: ${real.join(", ")}');
    }
    if (intentional.isNotEmpty) {
      debugPrint('ℹ️  Intentionally unsupported $aspect: ${intentional.join(", ")}');
    }
  }

  static bool _hasCoinGeckoId(String id) {
    return id.isNotEmpty && id != 'unknown' && id != 'n/a';
  }

  static String _percentage(int value, int total) {
    if (total == 0) return '0';
    return ((value / total) * 100).toStringAsFixed(0);
  }
}
