import 'dart:async';
import 'dart:convert';
import 'dart:math' show pow;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora_windows/core/blockchain/ethereum/ethereum_service.dart';
import 'package:kora_windows/core/config/api_config.dart';
import 'package:kora_windows/core/blockchain/solana/solana_service.dart';
import 'package:kora_windows/core/blockchain/solana/spl_token.dart';
import 'package:kora_windows/core/blockchain/tron/tron_service.dart';
import 'package:kora_windows/core/constants/token_catalog.dart';
import 'package:kora_windows/core/utils/constants.dart';
import 'package:kora_windows/core/models/asset.dart';
import 'package:kora_windows/core/utils/api_fallback.dart';

// ─── Concurrency semaphore ────────────────────────────────────────────────────
class _Semaphore {
  int _count;
  final _queue = <Completer<void>>[];
  _Semaphore(int max) : _count = max;
  Future<void> acquire() async {
    if (_count > 0) { _count--; return; }
    final c = Completer<void>();
    _queue.add(c);
    await c.future;
  }
  void release() {
    if (_queue.isNotEmpty) _queue.removeAt(0).complete();
    else _count++;
  }
}

// ─── Balance TTL cache (in-memory, 5 min) ─────────────────────────────────────
class _CachedBal {
  final String value;
  final DateTime ts;
  _CachedBal(this.value) : ts = DateTime.now();
  bool get valid => DateTime.now().difference(ts) < AppConstants.balanceCacheExpiration;
}

/// Fetches on-chain balances for all assets in a wallet and returns an
/// updated copy of the list. Any chain that fails is silently skipped so
/// one bad RPC does not break the entire refresh.
class BalanceService {
  static final _semaphore    = _Semaphore(6);          // max 6 concurrent balance fetches
  static final _cache        = <String, _CachedBal>{}; // in-memory TTL=5min

  /// Returns catalog contract address for a given asset id.
  static String? _catalogContract(String assetId) {
    try {
      return allCatalogTokens.firstWhere((t) => t.id == assetId).contractAddress;
    } catch (_) {
      return null;
    }
  }

  /// Fetches on-chain balances and returns updated [assets] list.
  Future<List<Asset>> fetchBalances(List<Asset> assets) async {
    final swTotal = Stopwatch()..start();
    if (kDebugMode) debugPrint('[PERF][Balance] START fetchBalances: ${assets.length} assets (throttled ≤6)');

    final results = await Future.wait(
      assets.map((asset) async {
        await _semaphore.acquire();
        final swAsset = Stopwatch()..start();
        try {
          final newBalance = await _fetchBalanceCached(asset);
          swAsset.stop();
          if (kDebugMode) debugPrint('[PERF][Balance] ${asset.id.padRight(14)} (${asset.blockchain.padRight(16)}) → ${swAsset.elapsedMilliseconds}ms  bal=${newBalance ?? 'skip'}');
          if (newBalance == null) return asset;
          final balDouble = double.tryParse(newBalance) ?? 0.0;
          return asset.copyWith(
            balance:      newBalance,
            balanceInUsd: balDouble * asset.priceUsd,
          );
        } catch (e) {
          swAsset.stop();
          if (kDebugMode) debugPrint('[PERF][Balance] ${asset.id.padRight(14)} (${asset.blockchain.padRight(16)}) → ${swAsset.elapsedMilliseconds}ms  ERROR: $e');
          return asset;
        } finally {
          _semaphore.release();
        }
      }),
    );

    swTotal.stop();
    if (kDebugMode) debugPrint('[PERF][Balance] TOTAL fetchBalances: ${swTotal.elapsedMilliseconds}ms for ${assets.length} assets');
    return results;
  }

  /// Evict a single asset from the balance cache so the next fetch is fresh.
  static void invalidateAsset(Asset asset) {
    final key = '${asset.blockchain}:${asset.id}:${asset.contractAddress}';
    _cache.remove(key);
  }

  /// Evict ALL assets from the balance cache so the next fetch is always fresh.
  static void invalidateAll() => _cache.clear();

  /// Cache wrapper: returns cached balance (TTL 5 min) or fetches fresh.
  Future<String?> _fetchBalanceCached(Asset asset) async {
    final key    = '${asset.blockchain}:${asset.id}:${asset.contractAddress}';
    final cached = _cache[key];
    if (cached != null && cached.valid) {
      if (kDebugMode) debugPrint('[Balance][${asset.symbol}] cache HIT (${asset.blockchain})');
      return cached.value;
    }
    final fresh = await _fetchBalanceString(asset);
    if (fresh != null) _cache[key] = _CachedBal(fresh);
    return fresh;
  }

  /// Returns the balance as a formatted string, or null if unsupported / skip.
  Future<String?> _fetchBalanceString(Asset asset) async {
    final chain = asset.blockchain;
    if (kDebugMode) debugPrint('[Balance][${asset.symbol}] Fetching balance for $chain (${asset.contractAddress.substring(0, 8)}...)');

    // ── EVM ──────────────────────────────────────────────────────────────────
    if (APIConfig.evmChainsRpc.contains(chain)) {
      if (kDebugMode) debugPrint('[Balance][${asset.symbol}] Using EVM service for $chain');
      final rpcs    = APIConfig.evmRpcFallbacks[chain] ?? [APIConfig.evmRpcEndpoints[chain]!];
      final chainId = APIConfig.evmChainIds[chain] ?? 1;
      try {
        return await tryWithFallbacks(rpcs, (rpcUrl) async {
          final svc = EthereumService(rpcUrl: rpcUrl, chainId: chainId);
          try {
            if (asset.type == AssetType.native) {
              final bal = await svc.getBalanceInEther(asset.contractAddress);
              if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✓ Native balance via $rpcUrl: $bal');
              return _fmt(bal, 8);
            } else {
              final contract = _catalogContract(asset.id);
              if (contract == null) return null;
              final raw = await svc.getTokenBalance(
                tokenAddress:  contract,
                walletAddress: asset.contractAddress,
              );
              final bal = raw.toDouble() / pow(10, asset.decimals);
              if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✓ Token balance via $rpcUrl: $bal');
              return _fmt(bal, asset.decimals.clamp(0, 8));
            }
          } finally {
            svc.dispose();
          }
        });
      } catch (e) {
        if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✗ All EVM RPCs failed: $e');
        return null;
      }
    }

    // ── Tron (TRX) via TronGrid ──────────────────────────────────────────────
    if (chain == 'tron') {
      if (kDebugMode) debugPrint('[Balance][${asset.symbol}] Fetching TRX balance');
      final svc = TronService();
      if (asset.type == AssetType.native) {
        final bal = await svc.getBalanceInTRX(asset.contractAddress);
        if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✓ TRX balance: $bal');
        return _fmt(bal, 6);
      } else {
        if (kDebugMode) debugPrint('[Balance][${asset.symbol}] Fetching TRC20 token balance');
        final contract = _catalogContract(asset.id);
        if (contract == null) return null;
        final raw  = await svc.getTRC20Balance(
          contractAddress: contract,
          ownerAddress:    asset.contractAddress,
        );
        final bal = raw.toDouble() / pow(10, asset.decimals);
        if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✓ TRC20 balance: $bal (raw: $raw)');
        return _fmt(bal, asset.decimals.clamp(0, 8));
      }
    }

    // ── Bitcoin via mempool.space → blockstream.info fallback ──────────────
    if (chain == 'bitcoin') {
      if (kDebugMode) debugPrint('[Balance][${asset.symbol}] Fetching BTC balance (${APIConfig.btcBalanceApis.length} endpoints)');
      try {
        return await tryWithFallbacks(APIConfig.btcBalanceApis, (base) async {
          final uri  = Uri.parse('$base/api/address/${asset.contractAddress}');
          final resp = await http.get(uri).timeout(const Duration(seconds: 12));
          if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
          final d            = jsonDecode(resp.body) as Map<String, dynamic>;
          final chainStats   = d['chain_stats']   as Map<String, dynamic>? ?? {};
          final mempoolStats = d['mempool_stats'] as Map<String, dynamic>? ?? {};
          final funded   = (chainStats['funded_txo_sum']   as num?)?.toInt() ?? 0;
          final spent    = (chainStats['spent_txo_sum']    as num?)?.toInt() ?? 0;
          final mFunded  = (mempoolStats['funded_txo_sum'] as num?)?.toInt() ?? 0;
          final mSpent   = (mempoolStats['spent_txo_sum']  as num?)?.toInt() ?? 0;
          final total    = ((funded - spent + mFunded - mSpent).clamp(0, double.maxFinite.toInt())) / 1e8;
          if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✓ BTC via $base: $total');
          return _fmt(total, 8);
        });
      } catch (_) {
        if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✗ All BTC balance APIs failed');
        return null;
      }
    }

    // ── Litecoin via litecoinspace.org → Blockchair fallback ────────────────
    if (chain == 'litecoin') {
      if (kDebugMode) debugPrint('[Balance][${asset.symbol}] Fetching LTC balance');
      try {
        return await tryWithFallbacks(APIConfig.ltcBalanceApis, (base) async {
          final uri  = Uri.parse('$base/api/address/${asset.contractAddress}');
          final resp = await http.get(uri).timeout(const Duration(seconds: 12));
          if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
          final d            = jsonDecode(resp.body) as Map<String, dynamic>;
          final chainStats   = d['chain_stats']   as Map<String, dynamic>? ?? {};
          final mempoolStats = d['mempool_stats'] as Map<String, dynamic>? ?? {};
          final funded   = (chainStats['funded_txo_sum']   as num?)?.toInt() ?? 0;
          final spent    = (chainStats['spent_txo_sum']    as num?)?.toInt() ?? 0;
          final mFunded  = (mempoolStats['funded_txo_sum'] as num?)?.toInt() ?? 0;
          final mSpent   = (mempoolStats['spent_txo_sum']  as num?)?.toInt() ?? 0;
          final total    = ((funded - spent + mFunded - mSpent).clamp(0, double.maxFinite.toInt())) / 1e8;
          if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✓ LTC via $base: $total');
          return _fmt(total, 8);
        });
      } catch (_) {
        // Fallback: Blockchair (different response format)
        if (kDebugMode) debugPrint('[Balance][${asset.symbol}] LTC primary failed — trying Blockchair');
        await Future.delayed(const Duration(seconds: 1));
        try {
          final uri  = Uri.parse('${APIConfig.blockchairApiBase}/litecoin/dashboards/address/${asset.contractAddress}');
          final resp = await http.get(uri).timeout(const Duration(seconds: 15));
          if (resp.statusCode != 200) return null;
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final data = (body['data'] as Map<String, dynamic>?)?.values.firstOrNull as Map<String, dynamic>?;
          if (data == null) return null;
          final addr   = data['address'] as Map<String, dynamic>? ?? {};
          final balSat = (addr['balance'] as num?)?.toInt() ?? 0;
          if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✓ LTC via Blockchair: ${balSat / 1e8}');
          return _fmt(balSat / 1e8, 8);
        } catch (_) {
          if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✗ All LTC balance APIs failed');
          return null;
        }
      }
    }

    // ── Bitcoin Cash via Haskoin → Blockchair fallback ──────────────────────
    if (chain == 'bitcoin_cash') {
      if (kDebugMode) debugPrint('[Balance][${asset.symbol}] Fetching BCH balance');
      final address = asset.contractAddress.startsWith('bitcoincash:')
          ? asset.contractAddress.substring(12)
          : asset.contractAddress;
      try {
        return await tryWithFallbacks(APIConfig.bchHaskoinApis, (base) async {
          final uri  = Uri.parse('$base/address/$address/balance');
          final resp = await http.get(uri).timeout(const Duration(seconds: 12));
          if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
          final d           = jsonDecode(resp.body) as Map<String, dynamic>;
          final confirmed   = (d['confirmed']   as num?)?.toInt() ?? 0;
          final unconfirmed = (d['unconfirmed'] as num?)?.toInt() ?? 0;
          final total       = (confirmed + unconfirmed).clamp(0, double.maxFinite.toInt()) / 1e8;
          if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✓ BCH via $base: $total');
          return _fmt(total, 8);
        });
      } catch (_) {
        // Fallback: Blockchair (different response format)
        if (kDebugMode) debugPrint('[Balance][${asset.symbol}] BCH primary failed — trying Blockchair');
        await Future.delayed(const Duration(seconds: 1));
        try {
          final uri  = Uri.parse('${APIConfig.blockchairApiBase}/bitcoin-cash/dashboards/address/$address');
          final resp = await http.get(uri).timeout(const Duration(seconds: 15));
          if (resp.statusCode != 200) return null;
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final data = (body['data'] as Map<String, dynamic>?)?.values.firstOrNull as Map<String, dynamic>?;
          if (data == null) return null;
          final addr   = data['address'] as Map<String, dynamic>? ?? {};
          final balSat = (addr['balance'] as num?)?.toInt() ?? 0;
          if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✓ BCH via Blockchair: ${balSat / 1e8}');
          return _fmt(balSat / 1e8, 8);
        } catch (_) {
          if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✗ All BCH balance APIs failed');
          return null;
        }
      }
    }


    // ── Solana (SOL + SPL tokens) ────────────────────────────────────────────
    if (chain == 'solana') {
      if (kDebugMode) debugPrint('[Balance][${asset.symbol}] Fetching Solana balance');
      final svc = SolanaService(devnet: false);
      if (asset.type == AssetType.native) {
        final bal = await svc.getBalanceInSOL(asset.contractAddress);
        if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✓ SOL balance: $bal');
        return _fmt(bal, 9);
      } else {
        if (kDebugMode) debugPrint('[Balance][${asset.symbol}] Fetching SPL token balance');
        final mintAddress = _catalogContract(asset.id);
        if (mintAddress == null) return null;
        final splToken = SPLToken(mintAddress: mintAddress, service: svc);
        final bal = await splToken.getBalanceForOwner(asset.contractAddress);
        if (kDebugMode) debugPrint('[Balance][${asset.symbol}] ✓ SPL token balance: $bal');
        return _fmt(bal, asset.decimals.clamp(0, 9));
      }
    }

    return null; // unsupported chain — leave balance unchanged
  }

  static String _fmt(double value, int decimals) =>
      value.toStringAsFixed(decimals.clamp(0, 9));

}
