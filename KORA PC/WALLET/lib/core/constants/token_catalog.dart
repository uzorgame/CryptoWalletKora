  import 'package:kora_windows/core/models/asset.dart';
import 'package:kora_windows/core/constants/coin_icon_url.dart';

/// Represents a token in the catalog (not yet added to wallet).
class CatalogToken {
  const CatalogToken({
    required this.id,
    required this.symbol,
    required this.name,
    required this.blockchain,
    required this.coinGeckoId,
    required this.decimals,
    this.contractAddress,
    this.type = AssetType.native,
  });

  final String id;
  final String symbol;
  final String name;
  final String blockchain;
  final String coinGeckoId;
  final int decimals;
  final String? contractAddress; // null for native coins
  final AssetType type;

  String get iconUrl => coinIconUrl(symbol);
}

// ─────────────────────────── Native coins ────────────────────────────────────

const _natives = <CatalogToken>[
  // ── Tier 1 (already supported with address derivation) ───────────────────
  CatalogToken(id: 'btc',  symbol: 'BTC',  name: 'Bitcoin',          blockchain: 'bitcoin',    coinGeckoId: 'bitcoin',              decimals: 8),
  CatalogToken(id: 'eth',  symbol: 'ETH',  name: 'Ethereum',         blockchain: 'ethereum',   coinGeckoId: 'ethereum',             decimals: 18),
  CatalogToken(id: 'sol',  symbol: 'SOL',  name: 'Solana',           blockchain: 'solana',     coinGeckoId: 'solana',               decimals: 9),
  CatalogToken(id: 'bnb',  symbol: 'BNB',  name: 'BNB',              blockchain: 'bsc',        coinGeckoId: 'binancecoin',          decimals: 18),
  CatalogToken(id: 'trx',  symbol: 'TRX',  name: 'Tron',             blockchain: 'tron',       coinGeckoId: 'tron',                 decimals: 6),
  CatalogToken(id: 'ltc',  symbol: 'LTC',  name: 'Litecoin',         blockchain: 'litecoin',   coinGeckoId: 'litecoin',             decimals: 8),

  // ── Tier 2 — Top-100 native coins ────────────────────────────────────────
  CatalogToken(id: 'bch',  symbol: 'BCH',  name: 'Bitcoin Cash',     blockchain: 'bitcoin_cash',  coinGeckoId: 'bitcoin-cash',     decimals: 8),
  CatalogToken(id: 'etc',  symbol: 'ETC',  name: 'Ethereum Classic', blockchain: 'ethereum_classic', coinGeckoId: 'ethereum-classic', decimals: 18),
];

// ─────────────────────────── Tokens (ERC-20 / TRC-20 / BEP-20 / SPL) ────────

const _tokens = <CatalogToken>[
  // ── Top Binance — Ethereum (2024-2025) ────────────────────────────────────
  // ── Stablecoins ───────────────────────────────────────────────────────────
  CatalogToken(id: 'usdt_eth',  symbol: 'USDT',  name: 'Tether (Ethereum)',     blockchain: 'ethereum',  coinGeckoId: 'tether',                    decimals: 6,  contractAddress: '0xdAC17F958D2ee523a2206206994597C13D831ec7', type: AssetType.token),
  CatalogToken(id: 'usdt_trx',  symbol: 'USDT',  name: 'Tether (Tron)',         blockchain: 'tron',      coinGeckoId: 'tether',                    decimals: 6,  contractAddress: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',         type: AssetType.token),
  CatalogToken(id: 'usdt_bsc',  symbol: 'USDT',  name: 'Tether (BSC)',          blockchain: 'bsc',       coinGeckoId: 'tether',                    decimals: 18, contractAddress: '0x55d398326f99059fF775485246999027B3197955', type: AssetType.token),
  CatalogToken(id: 'usdc_eth',  symbol: 'USDC',  name: 'USD Coin (Ethereum)',   blockchain: 'ethereum',  coinGeckoId: 'usd-coin',                  decimals: 6,  contractAddress: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', type: AssetType.token),
  CatalogToken(id: 'usdc_sol',  symbol: 'USDC',  name: 'USD Coin (Solana)',     blockchain: 'solana',    coinGeckoId: 'usd-coin',                  decimals: 6,  contractAddress: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', type: AssetType.token),
  CatalogToken(id: 'dai',       symbol: 'DAI',   name: 'Dai Stablecoin',        blockchain: 'ethereum',  coinGeckoId: 'dai',                       decimals: 18, contractAddress: '0x6B175474E89094C44Da98b954EedeAC495271d0F', type: AssetType.token),


  // ── BSC tokens ────────────────────────────────────────────────────────────
  CatalogToken(id: 'usdc_bsc',  symbol: 'USDC',  name: 'USD Coin (BSC)',        blockchain: 'bsc',       coinGeckoId: 'usd-coin',                  decimals: 18, contractAddress: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d', type: AssetType.token),

  // ── Tron tokens ───────────────────────────────────────────────────────────
  CatalogToken(id: 'usdc_trx',  symbol: 'USDC',  name: 'USD Coin (Tron)',       blockchain: 'tron',      coinGeckoId: 'usd-coin',                  decimals: 6,  contractAddress: 'TEkxiTehnzSmSe2XqrBj4w32RUN966rdz8',          type: AssetType.token),

];

// ─────────────────────────── Public API ──────────────────────────────────────

/// All catalog tokens (natives + ERC-20/TRC-20/etc.)
final List<CatalogToken> allCatalogTokens = [..._natives, ..._tokens];

/// Default tokens shown immediately after wallet creation (always visible).
final List<String> defaultTokenIds = [
  'btc', 'eth', 'usdt_eth', 'usdt_trx', 'sol', 'bnb', 'trx',
  'usdc_eth', 'ltc',
];
