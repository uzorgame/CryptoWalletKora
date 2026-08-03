import 'api_secrets.dart';

/// Centralized API Configuration
/// All blockchain API endpoints, RPC URLs, and API keys in one place
/// 
/// Usage:
/// - Import this file instead of hardcoding URLs
/// - All API endpoints should reference this config
/// - Update version when adding/removing APIs

class APIConfig {
  // ═══════════════════════════════════════════════════════════════════════════
  // API KEYS (from environment variables)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Etherscan API Keys (separate for each major chain)
  /// Get from: https://etherscan.io/
  /// Username: KoraU | Email: KoraWalletUI@gmail.com
  
  /// Ethereum API Key (for Etherscan V2 - Ethereum mainnet)
  /// Key: VK3HRA4WP41QSW5QGWND5GNKDUKQII9HXX
  static const String etherscanEthKey = String.fromEnvironment(
    'ETHERSCAN_ETH_KEY',
    defaultValue: 'VK3HRA4WP41QSW5QGWND5GNKDUKQII9HXX',
  );
  
  /// BSC API Key (for standalone bscscan.com API)
  /// Key: 2JE1RIERWSQIAJKUQM84HK9KKCQZFRCSB7
  static const String etherscanBscKey = String.fromEnvironment(
    'ETHERSCAN_BSC_KEY',
    defaultValue: '2JE1RIERWSQIAJKUQM84HK9KKCQZFRCSB7',
  );
  
  
  /// Get chain-specific API key
  static String getEtherscanKey(String blockchain) {
    return switch (blockchain) {
      'ethereum' => etherscanEthKey,
      'bsc'      => etherscanBscKey,
      _          => etherscanEthKey, // fallback to ETH key
    };
  }
  
  /// BlockCypher API Token (for Bitcoin, Litecoin)
  /// Get from: https://accounts.blockcypher.com/
  static const String blockcypherToken = String.fromEnvironment(
    'BLOCKCYPHER_TOKEN',
    defaultValue: '',
  );
  
  /// TronGrid API Key (for Tron blockchain)
  /// Get from: https://www.trongrid.io/
  static const String trongridKey = String.fromEnvironment(
    'TRONGRID_API_KEY',
    defaultValue: '',
  );
  
  /// CoinGecko API Key (optional - free tier doesn't need key)
  static const String coingeckoKey = String.fromEnvironment(
    'COINGECKO_API_KEY',
    defaultValue: '',
  );
  
  // ═══════════════════════════════════════════════════════════════════════════
  // EVM CHAINS - RPC ENDPOINTS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// All EVM-compatible chains
  static const evmChains = {
    'ethereum', 'bsc', 'ethereum_classic',
  };

  /// UTXO-based chains
  static const utxoChains = {'bitcoin', 'litecoin', 'bitcoin_cash'};

  /// EVM chains handled via web3dart RPC
  static const evmChainsRpc = {
    'ethereum', 'bsc', 'ethereum_classic',
  };
  
  static const evmRpcEndpoints = {
    'ethereum':          'https://rpc.ankr.com/eth/f039bf0f2ee18732c8dacc3cdad15afcf8abab7f3afd7e1ef03b5738d2ca1d8b',
    'bsc':               'https://bsc-dataseed1.binance.org',
    'ethereum_classic':  'https://etc.rivet.link',
  };

  /// Ordered fallback RPC list per EVM chain (primary first).
  static const evmRpcFallbacks = <String, List<String>>{
    'ethereum': [
      'https://rpc.ankr.com/eth/f039bf0f2ee18732c8dacc3cdad15afcf8abab7f3afd7e1ef03b5738d2ca1d8b',
      'https://ethereum.publicnode.com',   // ✅ tested
      'https://eth.llamarpc.com',          // ✅ tested
    ],
    'bsc': [
      'https://bsc-dataseed1.binance.org',
      'https://bsc-dataseed2.binance.org', // ✅ tested
      'https://bsc-dataseed3.binance.org', // ✅ tested
    ],
    'ethereum_classic': [
      'https://etc.rivet.link',
      'https://etc.etcdesktop.com',        // ✅ tested
    ],
  };
  
  static const evmChainIds = {
    'ethereum':          1,
    'bsc':               56,
    'ethereum_classic':  61,
  };
  
  // ═══════════════════════════════════════════════════════════════════════════
  // TRANSACTION HISTORY APIs
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Etherscan V2 Unified API (supports multiple chains with one API key)
  static const String etherscanV2Url = 'https://api.etherscan.io/v2/api';

  /// Chains that use Etherscan V2 (BSC moved to standalone — ETH key gives 0 results for BSC)
  static const etherscanV2Chains = {
    'ethereum': 1,
  };

  /// BlockScout BSC — primary BSC history explorer (free, no key)
  static const String blockscoutBscApi  = 'https://bsc.blockscout.com/api';
  /// BscScan — BSC history fallback (requires BSC API key)
  static const String bscscanApiUrl     = 'https://api.bscscan.com/api';
  /// BlockScout ETC — ETC history explorer (free, no key)
  static const String blockscoutEtcApi  = 'https://etc.blockscout.com/api';

  /// Standalone explorer APIs per chain (primary URL only; BSC has fallback in tx_history_service)
  static const standaloneExplorerApis = {
    'ethereum_classic': blockscoutEtcApi,
    'bsc':              blockscoutBscApi,
  };
  
  // ═══════════════════════════════════════════════════════════════════════════
  // NON-EVM BLOCKCHAINS - RPC/API ENDPOINTS
  // ═══════════════════════════════════════════════════════════════════════════
  
  // ── UTXO chains (BTC / LTC / BCH): balance, UTXO fetch, broadcast ──────────

  /// mempool.space — BTC balance + UTXO + broadcast
  static const String mempoolSpaceBase  = 'https://mempool.space';
  /// litecoinspace.org — LTC balance + UTXO + broadcast
  static const String litecoinspaceBase = 'https://litecoinspace.org';
  /// Haskoin — BCH balance + UTXO + broadcast
  static const String haskoinBchBase    = 'https://api.haskoin.com/bch';

  /// BTC balance API fallbacks (mempool.space-compatible format, primary first)
  static const btcBalanceApis = <String>[
    'https://mempool.space',
    'https://blockstream.info',
  ];

  /// LTC balance API fallbacks
  static const ltcBalanceApis = <String>[
    'https://litecoinspace.org',
  ];

  /// BCH balance API fallbacks (Haskoin format, primary first)
  static const bchHaskoinApis = <String>[
    'https://api.haskoin.com/bch',
  ];

  /// Blockchair — BTC/LTC/BCH transaction history
  static const String blockchairApiBase = 'https://api.blockchair.com';

  /// BTC transaction history API fallbacks (CORS-compatible, primary first)
  static const btcHistoryApis = <String>[
    'https://mempool.space/api/address',      // ✅ tested - returns array of txs
    'https://blockchain.info/rawaddr',        // ✅ tested - returns {txs: [...]}
    'https://api.blockchair.com/bitcoin/dashboards/address', // fallback (CORS issues on web)
  ];
  /// BlockCypher base — legacy history fallback (requires token)
  static const String blockcypherApiBase = 'https://api.blockcypher.com/v1';

  /// BlockCypher full endpoints (kept for bitcoin_service.dart RPC compatibility)
  static const blockcypherEndpoints = {
    'bitcoin':  '$blockcypherApiBase/btc/main',
    'litecoin': '$blockcypherApiBase/ltc/main',
  };
  static const String blockcypherBtcTestnet = '$blockcypherApiBase/btc/test3';

  /// Blockchair BCH (kept for backward compat)
  static const String blockchairBchBase = '$blockchairApiBase/bitcoin-cash';
  
  /// Solana — Helius (primary, 1M req/month free)
  static const String heliusApiKey = ApiSecrets.heliusApiKey;
  static const String solanaMainnetRpc =
      'https://mainnet.helius-rpc.com/?api-key=$heliusApiKey';
  /// Solana — public mainnet fallback (no key required)
  static const String solanaMainnetRpcDefault = 'https://api.mainnet-beta.solana.com';
  static const String solanaDevnetRpc = 'https://api.devnet.solana.com';
  /// Helius Enhanced Transactions REST API base (parse history without batching)
  static const String heliusEnhancedTxBase =
      'https://api-mainnet.helius-rpc.com/v0/addresses';

  /// Tron
  static const String tronMainnetApi = 'https://api.trongrid.io';
  static const String tronTestnetApi = 'https://api.shasta.trongrid.io';

  /// Tron mainnet API fallbacks (TronGrid REST format, primary first)
  static const tronMainnetApis = <String>[
    'https://api.trongrid.io', // ✅ tested — only reliable public TronGrid REST node
  ];

  /// TronScan history API fallbacks (primary first)
  static const tronscanApis = <String>[
    'https://apilist.tronscan.org/api',  // ✅ tested
    'https://apilist.tronscan.io/api',   // ✅ tested — mirror domain
  ];

  /// ETC history API fallbacks — (baseUrl, keyType) pairs tried in order
  static const etcHistoryApis = <(String, String)>[
    ('https://etc.blockscout.com/api', ''),
    ('https://blockscout.com/etc/mainnet/api', ''),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // PRICE APIs (CoinGecko — current prices, 24h change & price charts)
  // ═══════════════════════════════════════════════════════════════════════════

  /// CoinGecko ID mapping for price charts (symbol → CoinGecko ID)
  static const chartGeckoIds = {
    'BTC':  'bitcoin',
    'SOL':  'solana',
    'ETH':  'ethereum',
    'ETC':  'ethereum-classic',
    'TRX':  'tron',
    'BCH':  'bitcoin-cash',
    'LTC':  'litecoin',
    'BNB':  'binancecoin',
    'USDT': 'tether',                      // USDT on ETH, TRON, BNB
    'USDC': 'usd-coin',                    // USDC on ETH, TRON, BNB, ARB, SOL
    'DAI':  'dai',                         // DAI on ETH, BNB
  };
  
  // ═══════════════════════════════════════════════════════════════════════════
  // COINCAP API (fallback for current prices + primary for price charts)
  // ═══════════════════════════════════════════════════════════════════════════

  // NOTE: api.coincap.io was shut down (DNS n/a as of 2025).
  // CoinCap IDs are kept only for the price-chart history service (coincap_service.dart)
  // which may be migrated separately.
  static const String coincapBaseUrl = 'https://api.coincap.io/v2';
  static const String coincapApiKey  = String.fromEnvironment(
    'COINCAP_API_KEY', defaultValue: '');

  static String coincapHistory(String coinId, String interval, int startMs, int endMs) =>
      '$coincapBaseUrl/assets/$coinId/history?interval=$interval&start=$startMs&end=$endMs';

  /// CoinCap asset IDs for price charts (symbol → CoinCap ID)
  static const coincapIds = <String, String>{
    'BTC':  'bitcoin',
    'ETH':  'ethereum',
    'SOL':  'solana',
    'BNB':  'binance-coin',
    'TRX':  'tron',
    'LTC':  'litecoin',
    'USDT': 'tether',
    'USDC': 'usd-coin',
    'DAI':  'multi-collateral-dai',
    'ETC':  'ethereum-classic',
    'BCH':  'bitcoin-cash',
  };

  // ── CryptoCompare — live price fallback (replaces dead CoinCap) ──────────────
  /// ✅ tested: https://min-api.cryptocompare.com/data/pricemultifull?fsyms=BTC&tsyms=USD
  static const String cryptoCompareUrl =
      'https://min-api.cryptocompare.com/data/pricemultifull';

  /// CoinGecko ID → CryptoCompare symbol mapping
  static const geckoToCryptoCompare = <String, String>{
    'bitcoin':           'BTC',
    'ethereum':          'ETH',
    'solana':            'SOL',
    'binancecoin':       'BNB',
    'tron':              'TRX',
    'litecoin':          'LTC',
    'tether':            'USDT',
    'usd-coin':          'USDC',
    'dai':               'DAI',
    'ethereum-classic':  'ETC',
    'bitcoin-cash':      'BCH',
  };

  /// @deprecated geckoToCoinCap kept for reference; CoinCap API is down
  static const geckoToCoinCap = geckoToCryptoCompare;

  /// CoinGecko API (primary price source)
  static const String coingeckoBaseUrl = 'https://api.coingecko.com/api/v3';
  
  static String coingeckoSimplePrice(String ids, String vsCurrencies) =>
      '$coingeckoBaseUrl/simple/price?ids=$ids&vs_currencies=$vsCurrencies&include_24hr_change=true';
  
  static String coingeckoMarketChart(String coinId, int days) =>
      '$coingeckoBaseUrl/coins/$coinId/market_chart?vs_currency=usd&days=$days';
  
  static String coingeckoSearch(String query) =>
      '$coingeckoBaseUrl/search?query=$query';
  
  static const String coingeckoTrending = '$coingeckoBaseUrl/search/trending';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FEE ESTIMATION APIs
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Etherscan v1 API (gas oracle — different from V2 multi-chain endpoint)
  static const String etherscanEthApiV1 = 'https://api.etherscan.io/api';

  /// Bitcoin/Litecoin Fee Estimation (mempool.space / litecoinspace.org)
  static const String mempoolSpaceBtcFee = '$mempoolSpaceBase/api/v1/fees/recommended';
  static const String mempoolSpaceLtcFee = '$litecoinspaceBase/api/v1/fees/recommended';

  /// Bitcoin Cash Fee Estimation (BlockCypher)
  static const String blockcypherBchFee  = '$blockcypherApiBase/bch/main';

  /// Ethereum Gas Tracker (Etherscan v1 / BscScan)
  static String etherscanGasOracle(String blockchain) {
    final baseUrl = blockchain == 'bsc' ? bscscanApiUrl : etherscanEthApiV1;
    return '$baseUrl?module=gastracker&action=gasoracle&apikey=${getEtherscanKey(blockchain)}';
  }
  
  /// Solana Fee Estimation (backup via Helius)
  static const String heliusSolanaRpc = 'https://mainnet.helius-rpc.com';
  
  /// Tron Fee Estimation (backup via TronScan)
  static const String tronscanApi = 'https://apilist.tronscan.org/api';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // EXPLORER URLs (for UI links)
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const explorerUrls = {
    'ethereum':          'https://etherscan.io',
    'bsc':               'https://bscscan.com',
    'ethereum_classic':  'https://etc.blockscout.com',
    'bitcoin':           'https://blockchair.com/bitcoin',
    'litecoin':          'https://blockchair.com/litecoin',
    'bitcoin_cash':      'https://blockchair.com/bitcoin-cash',
    'solana':            'https://solscan.io',
    'tron':              'https://tronscan.org',
  };

  /// Per-chain TX URL prefix — append tx hash to build a full explorer link
  static const explorerTxUrls = {
    'bitcoin':          '$mempoolSpaceBase/tx/',
    'litecoin':         'https://blockchair.com/litecoin/transaction/',
    'bitcoin_cash':     'https://blockchair.com/bitcoin-cash/transaction/',
    'ethereum':         'https://etherscan.io/tx/',
    'bsc':              'https://bscscan.com/tx/',
    'ethereum_classic': 'https://etc.blockscout.com/tx/',
    'solana':           'https://solscan.io/tx/',
    'tron':             'https://tronscan.org/#/transaction/',
  };

  /// Build a full block-explorer TX URL for [blockchain] + [hash].
  static String explorerTxUrl(String blockchain, String hash) {
    final base = explorerTxUrls[blockchain] ?? '';
    return base.isEmpty ? '' : '$base$hash';
  }

  /// CoinGecko CDN — base URL for coin image assets
  static const String coingeckoCdnBase   = 'https://assets.coingecko.com/coins/images';
  /// cryptocurrency-icons CDN (spothq/cryptocurrency-icons on GitHub)
  static const String cryptoIconsCdnBase = 'https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Get RPC URL for EVM chain
  static String? getEvmRpcUrl(String blockchain) => evmRpcEndpoints[blockchain];
  
  /// Get chain ID for EVM chain
  static int? getEvmChainId(String blockchain) => evmChainIds[blockchain];
  
  /// Get explorer URL for blockchain
  static String? getExplorerUrl(String blockchain) => explorerUrls[blockchain];
  
  /// Check if blockchain uses Etherscan V2 API
  static bool usesEtherscanV2(String blockchain) => 
      etherscanV2Chains.containsKey(blockchain);
  
  /// Get Etherscan V2 chain ID
  static int? getEtherscanV2ChainId(String blockchain) => 
      etherscanV2Chains[blockchain];
  
  /// Get standalone explorer API URL
  static String? getStandaloneExplorerApi(String blockchain) => 
      standaloneExplorerApis[blockchain];
  
  /// Returns (rpcUrl, chainId) for a given EVM blockchain
  /// Single source of truth for all EVM RPC configuration
  static (String, int) evmRpcConfig(String blockchain) {
    final rpcUrl = evmRpcEndpoints[blockchain] ?? evmRpcEndpoints['ethereum']!;
    final chainId = evmChainIds[blockchain] ?? 1;
    return (rpcUrl, chainId);
  }
}
