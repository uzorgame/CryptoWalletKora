import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';
import 'package:kora/core/services/storage_service.dart';
import 'package:kora/core/blockchain/bitcoin/bitcoin_wallet.dart';
import 'package:kora/core/blockchain/solana/solana_wallet.dart';
import 'package:kora/core/blockchain/tron/tron_wallet.dart';
import 'package:kora/core/crypto/hd_wallet.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/repositories/price_repository.dart' show PriceRepository, CryptoPrice;
import 'package:kora/core/widgets/coin_icon.dart';
import 'package:kora/core/constants/token_catalog.dart';

// ─── Isolate workers (top-level — required by compute()) ─────────────────────

/// Group 1: all standard BIP32/BIP44 chains.
/// Fast — secp256k1 / ed25519 standard derivation.
Map<String, String> _deriveFastChains(String mnemonic) {
  // Derive BIP39 seed ONCE — avoids ~22 repeated PBKDF2 calls.
  final seedBytes = Uint8List.fromList(bip39.mnemonicToSeed(mnemonic));
  final hd        = HDWallet.fromSeed(seedBytes);
  final ethAddr   = hd.getEthereumAddress(0);
  return {
    'bitcoin':           BitcoinWallet.fromHdWallet(hd).address,
    'ethereum':          ethAddr,
    'solana':            SolanaWallet.fromSeed(seedBytes).address,
    'bsc':               ethAddr,
    'tron':              TronWallet.fromHdWallet(hd).address,
    'ethereum_classic':  hd.getEthereumClassicAddress(0),
    'litecoin':          BitcoinWallet.addressForLtcSegwit(hd),
    'bitcoin_cash':      BitcoinWallet.addressForBCHCashAddr(hd),
  };
}

/// Tier 1 only: the 6 native chains shown immediately on cold start.
Map<String, String> _deriveTier1Chains(String mnemonic) {
  // Derive BIP39 seed ONCE — avoids 5 repeated PBKDF2 calls.
  final seedBytes = Uint8List.fromList(bip39.mnemonicToSeed(mnemonic));
  final hd        = HDWallet.fromSeed(seedBytes);
  final ethAddr   = hd.getEthereumAddress(0);
  return {
    'bitcoin':  BitcoinWallet.fromHdWallet(hd).address,
    'ethereum': ethAddr,
    'solana':   SolanaWallet.fromSeed(seedBytes).address,
    'bsc':      ethAddr,
    'tron':     TronWallet.fromHdWallet(hd).address,
  };
}

/// Service for initializing wallet with all supported blockchains
class WalletInitializationService {
  final PriceRepository _priceRepository = PriceRepository();

  static const String _addrCacheKey = 'addr_cache_v19'; // v19: ETC coin_type 61 (matches Trust Wallet)

  /// Returns cached addresses if the mnemonic fingerprint matches;
  /// otherwise derives in 3 parallel Isolates and persists to SharedPreferences.
  static Future<Map<String, String>> _getOrDeriveAddresses(String mnemonic) async {
    final fingerprint = mnemonic.split(' ').first;
    final cached = await StorageService.readJson(_addrCacheKey);
    if (cached != null && (cached['_fp'] as String?) == fingerprint) {
      if (kDebugMode) debugPrint('[WalletInit] Address cache HIT — skipping derivation');
      return {for (final e in cached.entries) if (e.key != '_fp') e.key: e.value as String};
    }
    if (kDebugMode) debugPrint('[WalletInit] Address cache MISS — deriving in 3 parallel Isolates…');
    final results = await Future.wait([
      compute(_deriveFastChains, mnemonic),
    ]);
    final addr = <String, String>{};
    for (final r in results) addr.addAll(r);
    await StorageService.writeJson(_addrCacheKey, {'_fp': fingerprint, ...addr});
    return addr;
  }

  /// Call this when a wallet is deleted or a new mnemonic is imported.
  static Future<void> clearAddressCache() => StorageService.delete(_addrCacheKey);

  /// Returns true if a full address cache exists for this mnemonic (fast path).
  static Future<bool> hasCachedAddresses(String mnemonic) async {
    final fingerprint = mnemonic.split(' ').first;
    final cached = await StorageService.readJson(_addrCacheKey);
    return cached != null && (cached['_fp'] as String?) == fingerprint;
  }

  /// Fast init: derives only the 7 Tier 1 assets (BTC ETH SOL BNB TRX USDT-TRX USDC-ETH).
  /// Used on cache MISS to show the wallet immediately while Tier 2/3 derive in background.
  Future<List<Asset>> initializeTier1(String mnemonic) async {
    if (kDebugMode) debugPrint('[WalletInit] Tier 1 fast derivation START');
    final sw   = Stopwatch()..start();
    final addr = await compute(_deriveTier1Chains, mnemonic);
    sw.stop();
    if (kDebugMode) debugPrint('[PERF][WalletInit] Tier 1 derivation: ${sw.elapsedMilliseconds}ms');

    final btcAddr  = addr['bitcoin']!;
    final ethAddr  = addr['ethereum']!;
    final solAddr  = addr['solana']!;
    final bscAddr  = addr['bsc']!;
    final tronAddr = addr['tron']!;

    Map<String, CryptoPrice> prices = {};
    try {
      prices = await _priceRepository.getPricesOptimized([
        'bitcoin', 'ethereum', 'solana', 'binancecoin', 'tron', 'tether', 'usd-coin',
      ]);
    } catch (_) {}

    double _p(String id) => prices[id]?.priceUsd ?? 0.0;
    double _c(String id) => prices[id]?.change24h ?? 0.0;

    return [
      Asset(id: 'btc',      symbol: 'BTC',  name: 'Bitcoin',
            blockchain: 'bitcoin',  contractAddress: btcAddr,
            decimals: 8,  balance: '0', balanceInUsd: 0.0,
            priceUsd: _p('bitcoin'),     priceChange24h: _c('bitcoin'),
            iconUrl: coinIconUrl('btc'),  type: AssetType.native, isVisible: true),
      Asset(id: 'eth',      symbol: 'ETH',  name: 'Ethereum',
            blockchain: 'ethereum', contractAddress: ethAddr,
            decimals: 18, balance: '0', balanceInUsd: 0.0,
            priceUsd: _p('ethereum'),    priceChange24h: _c('ethereum'),
            iconUrl: coinIconUrl('eth'),  type: AssetType.native, isVisible: true),
      Asset(id: 'sol',      symbol: 'SOL',  name: 'Solana',
            blockchain: 'solana',   contractAddress: solAddr,
            decimals: 9,  balance: '0', balanceInUsd: 0.0,
            priceUsd: _p('solana'),      priceChange24h: _c('solana'),
            iconUrl: coinIconUrl('sol'),  type: AssetType.native, isVisible: true),
      Asset(id: 'bnb',      symbol: 'BNB',  name: 'BNB',
            blockchain: 'bsc',      contractAddress: bscAddr,
            decimals: 18, balance: '0', balanceInUsd: 0.0,
            priceUsd: _p('binancecoin'), priceChange24h: _c('binancecoin'),
            iconUrl: coinIconUrl('bnb'),  type: AssetType.native, isVisible: true),
      Asset(id: 'trx',      symbol: 'TRX',  name: 'Tron',
            blockchain: 'tron',     contractAddress: tronAddr,
            decimals: 6,  balance: '0', balanceInUsd: 0.0,
            priceUsd: _p('tron'),        priceChange24h: _c('tron'),
            iconUrl: coinIconUrl('trx'),  type: AssetType.native, isVisible: true),
      Asset(id: 'usdt_trx', symbol: 'USDT', name: 'Tether (Tron)',
            blockchain: 'tron',     contractAddress: tronAddr,
            decimals: 6,  balance: '0', balanceInUsd: 0.0,
            priceUsd: _p('tether'),      priceChange24h: _c('tether'),
            iconUrl: coinIconUrl('usdt'), type: AssetType.token,  isVisible: true),
      Asset(id: 'usdc_eth', symbol: 'USDC', name: 'USD Coin (Ethereum)',
            blockchain: 'ethereum', contractAddress: ethAddr,
            decimals: 6,  balance: '0', balanceInUsd: 0.0,
            priceUsd: _p('usd-coin'),    priceChange24h: _c('usd-coin'),
            iconUrl: coinIconUrl('usdc'), type: AssetType.token,  isVisible: true),
    ];
  }

  /// Initialize wallet with all supported cryptocurrencies
  /// Returns list of assets with addresses and initial balances
  Future<List<Asset>> initializeWallet(String mnemonic) async {
    final List<Asset> assets = [];
    final swTotal = Stopwatch()..start();

    try {
      if (kDebugMode) debugPrint('[WalletInit] Resolving addresses…');
      final swAddr = Stopwatch()..start();

      final addr = await _getOrDeriveAddresses(mnemonic);

      swAddr.stop();
      if (kDebugMode) debugPrint('[PERF][WalletInit] Address derivation: ${swAddr.elapsedMilliseconds}ms for all chains');

      // Extract addresses from the computed map
      final btcAddress   = addr['bitcoin']!;
      final ethAddress   = addr['ethereum']!;
      final solAddress   = addr['solana']!;
      final bscAddress   = addr['bsc']!;
      final tronAddress  = addr['tron']!;

      final ltcAddress   = addr['litecoin']!;
      final bchAddress   = addr['bitcoin_cash']!;
      final etcAddress   = addr['ethereum_classic']!;

      if (kDebugMode) {
        debugPrint('[WalletInit] BTC  → $btcAddress');
        debugPrint('[WalletInit] ETH  → $ethAddress');
        debugPrint('[WalletInit] SOL  → $solAddress');
        debugPrint('[WalletInit] BNB  → $bscAddress');
        debugPrint('[WalletInit] TRX  → $tronAddress');
        debugPrint('[WalletInit] LTC  → $ltcAddress');
        debugPrint('[WalletInit] BCH  → $bchAddress');
        debugPrint('[WalletInit] ETC  → $etcAddress');
      }

      if (kDebugMode) debugPrint('[WalletInit] Fetching prices from CoinGecko…');
      final swPrice = Stopwatch()..start();
      Map<String, CryptoPrice> coinPrices = {};
      try {
        coinPrices = await _priceRepository.getPricesOptimized([
          'bitcoin', 'ethereum', 'solana', 'binancecoin', 'tron',
          'tether', 'usd-coin', 'litecoin',
          'ethereum-classic',
          'bitcoin-cash',
        ], forceRefresh: true);
        if (kDebugMode) {
          const requested = [
            'bitcoin', 'ethereum', 'solana', 'binancecoin', 'tron',
            'tether', 'usd-coin', 'litecoin',
            'ethereum-classic',
            'bitcoin-cash',
          ];
          final missing = requested.where((id) => !coinPrices.containsKey(id)).toList();
          final zero    = coinPrices.entries
              .where((e) => e.value.priceUsd == 0.0).map((e) => e.key).toList();
          debugPrint('[PriceAudit] Init: ${coinPrices.length}/${requested.length} prices received');
          if (missing.isNotEmpty) debugPrint('[PriceAudit] ⚠ MISSING from response: $missing');
          if (zero.isNotEmpty)    debugPrint('[PriceAudit] ⚠ ZERO price returned:   $zero');
          if (missing.isEmpty && zero.isEmpty) debugPrint('[PriceAudit] ✓ All prices OK');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[PriceAudit] ✗ Init price fetch failed: $e — all prices will be 0');
      }
      swPrice.stop();
      if (kDebugMode) debugPrint('[PERF][WalletInit] Price fetch: ${swPrice.elapsedMilliseconds}ms');

      double _p(String id) => coinPrices[id]?.priceUsd ?? 0.0;
      double _c(String id) => coinPrices[id]?.change24h ?? 0.0;

      assets.addAll([
        // ── Natives ──────────────────────────────────────────────────────────
        Asset(id: 'btc',  symbol: 'BTC',  name: 'Bitcoin',
              blockchain: 'bitcoin',  contractAddress: btcAddress,
              decimals: 8,  balance: '0', balanceInUsd: 0.0,
              priceUsd: _p('bitcoin'),  priceChange24h: _c('bitcoin'),
              iconUrl: coinIconUrl('btc'),  type: AssetType.native,  isVisible: true),
        Asset(id: 'eth',  symbol: 'ETH',  name: 'Ethereum',
              blockchain: 'ethereum', contractAddress: ethAddress,
              decimals: 18, balance: '0', balanceInUsd: 0.0,
              priceUsd: _p('ethereum'), priceChange24h: _c('ethereum'),
              iconUrl: coinIconUrl('eth'),  type: AssetType.native,  isVisible: true),
        Asset(id: 'sol',  symbol: 'SOL',  name: 'Solana',
              blockchain: 'solana',   contractAddress: solAddress,
              decimals: 9,  balance: '0', balanceInUsd: 0.0,
              priceUsd: _p('solana'),   priceChange24h: _c('solana'),
              iconUrl: coinIconUrl('sol'),  type: AssetType.native,  isVisible: true),
        Asset(id: 'bnb',  symbol: 'BNB',  name: 'BNB',
              blockchain: 'bsc',      contractAddress: bscAddress,
              decimals: 18, balance: '0', balanceInUsd: 0.0,
              priceUsd: _p('binancecoin'), priceChange24h: _c('binancecoin'),
              iconUrl: coinIconUrl('bnb'),  type: AssetType.native,  isVisible: true),
        Asset(id: 'trx',  symbol: 'TRX',  name: 'Tron',
              blockchain: 'tron',     contractAddress: tronAddress,
              decimals: 6,  balance: '0', balanceInUsd: 0.0,
              priceUsd: _p('tron'),     priceChange24h: _c('tron'),
              iconUrl: coinIconUrl('trx'),  type: AssetType.native,  isVisible: true),
        Asset(id: 'ltc',  symbol: 'LTC',  name: 'Litecoin',
              blockchain: 'litecoin', contractAddress: ltcAddress,
              decimals: 8,  balance: '0', balanceInUsd: 0.0,
              priceUsd: _p('litecoin'), priceChange24h: _c('litecoin'),
              iconUrl: coinIconUrl('ltc'),  type: AssetType.native,  isVisible: false),

        // ── Tokens ───────────────────────────────────────────────────────────
        Asset(id: 'usdt_eth', symbol: 'USDT', name: 'Tether (Ethereum)',
              blockchain: 'ethereum', contractAddress: ethAddress,
              decimals: 6,  balance: '0', balanceInUsd: 0.0,
              priceUsd: _p('tether'),  priceChange24h: _c('tether'),
              iconUrl: coinIconUrl('usdt'), type: AssetType.token,   isVisible: false),
        Asset(id: 'usdt_trx', symbol: 'USDT', name: 'Tether (Tron)',
              blockchain: 'tron',     contractAddress: tronAddress,
              decimals: 6,  balance: '0', balanceInUsd: 0.0,
              priceUsd: _p('tether'),  priceChange24h: _c('tether'),
              iconUrl: coinIconUrl('usdt'), type: AssetType.token,   isVisible: true),
        Asset(id: 'usdc_eth', symbol: 'USDC', name: 'USD Coin (Ethereum)',
              blockchain: 'ethereum', contractAddress: ethAddress,
              decimals: 6,  balance: '0', balanceInUsd: 0.0,
              priceUsd: _p('usd-coin'), priceChange24h: _c('usd-coin'),
              iconUrl: coinIconUrl('usdc'), type: AssetType.token,   isVisible: true),

        // EVM-compatible chains
        Asset(id: 'etc',  symbol: 'ETC',  name: 'Ethereum Classic',
              blockchain: 'ethereum_classic', contractAddress: etcAddress,
              decimals: 18, balance: '0', balanceInUsd: 0.0,
              priceUsd: _p('ethereum-classic'), priceChange24h: _c('ethereum-classic'),
              iconUrl: coinIconUrl('etc'),  type: AssetType.native,  isVisible: false),
        // UTXO derivatives
        Asset(id: 'bch',  symbol: 'BCH',  name: 'Bitcoin Cash',
              blockchain: 'bitcoin_cash',     contractAddress: bchAddress,
              decimals: 8,  balance: '0', balanceInUsd: 0.0,
              priceUsd: _p('bitcoin-cash'), priceChange24h: _c('bitcoin-cash'),
              iconUrl: coinIconUrl('bch'),  type: AssetType.native,  isVisible: false),
      ]);

      swTotal.stop();
      if (kDebugMode) debugPrint('[PERF][WalletInit] TOTAL initializeWallet: ${swTotal.elapsedMilliseconds}ms  assets=${assets.length}');

      return assets;
    } catch (e, st) {
      if (kDebugMode) debugPrint('[WalletInit] ERROR: $e\n$st');
      rethrow;
    }
  }

  /// Maps asset symbol → CoinGecko id for price fetching
  static const _symbolToGeckoId = <String, String>{
    'BTC':   'bitcoin',         'ETH':   'ethereum',
    'SOL':   'solana',          'BNB':   'binancecoin',
    'TRX':   'tron',            'LTC':   'litecoin',        'USDT':  'tether',          'USDC':  'usd-coin',
    'DAI':   'dai',
    'ETC':   'ethereum-classic',
    'BCH':   'bitcoin-cash',
  };

  /// Update asset prices for all supported symbols.
  /// Priority: _symbolToGeckoId → catalog lookup by asset.id → skip.
  Future<List<Asset>> updateAssetPrices(List<Asset> assets) async {
    try {
      // Build a map assetId → geckoId using symbol map first, then catalog fallback.
      final geckoIdForAsset = <String, String>{};
      for (final asset in assets) {
        final bySymbol = _symbolToGeckoId[asset.symbol.toUpperCase()];
        if (bySymbol != null) {
          geckoIdForAsset[asset.id] = bySymbol;
        } else {
          try {
            final cat = allCatalogTokens.firstWhere((t) => t.id == asset.id);
            geckoIdForAsset[asset.id] = cat.coinGeckoId;
          } catch (_) {}
        }
      }

      final coinIds = geckoIdForAsset.values.toSet().toList();
      if (coinIds.isEmpty) return assets;

      if (kDebugMode) {
        debugPrint('[PriceAudit] Refresh: requesting ${coinIds.length} IDs for '
            '${assets.length} assets');
      }
      final prices = await _priceRepository.getPricesOptimized(coinIds);

      int updated = 0;
      final noPrice = <String>[];
      final result = assets.map((asset) {
        final geckoId = geckoIdForAsset[asset.id];
        if (geckoId != null && prices.containsKey(geckoId)) {
          final price         = prices[geckoId]!;
          final balanceDouble = double.tryParse(asset.balance) ?? 0.0;
          updated++;
          return asset.copyWith(
            priceUsd:       price.priceUsd,
            priceChange24h: price.change24h,
            balanceInUsd:   balanceDouble * price.priceUsd,
          );
        }
        if (geckoId != null) noPrice.add('${asset.symbol}($geckoId)');
        return asset;
      }).toList();

      if (kDebugMode) {
        debugPrint('[PriceAudit] Refresh: updated $updated/${assets.length} assets');
        if (noPrice.isNotEmpty) {
          debugPrint('[PriceAudit] ⚠ No price for: $noPrice');
        } else {
          debugPrint('[PriceAudit] ✓ All asset prices refreshed');
        }
      }
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[PriceAudit] ✗ updateAssetPrices failed: $e');
      return assets;
    }
  }
}
