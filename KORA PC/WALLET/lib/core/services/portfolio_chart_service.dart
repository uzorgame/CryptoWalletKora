import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kora_windows/core/config/api_config.dart';
import 'package:kora_windows/core/models/asset.dart';
import 'package:kora_windows/core/services/tx_history_service.dart';

class ChartPoint {
  final DateTime time;
  final double value;
  const ChartPoint(this.time, this.value);
}

enum ChartPeriod { day, week, month, sixMonths, year }

extension ChartPeriodExt on ChartPeriod {
  String get label {
    switch (this) {
      case ChartPeriod.day:       return '1D';
      case ChartPeriod.week:      return '1W';
      case ChartPeriod.month:     return '1M';
      case ChartPeriod.sixMonths: return '6M';
      case ChartPeriod.year:      return '1Y';
    }
  }

  int get days {
    switch (this) {
      case ChartPeriod.day:       return 1;
      case ChartPeriod.week:      return 7;
      case ChartPeriod.month:     return 30;
      case ChartPeriod.sixMonths: return 180;
      case ChartPeriod.year:      return 365;
    }
  }
}

class PortfolioChartService {
  static const _base = APIConfig.coingeckoBaseUrl;

  static final Map<String, _CacheEntry> _cache = {};
  static final Map<String, _TxCacheEntry> _txCache = {};

  /// UTXO chains where outgoing amount already includes the fee.
  static const _feeInAmount = {'bitcoin', 'litecoin', 'bitcoin_cash'};

  /// Build a forward balance timeline from transaction history.
  /// Starts from 0, adds incoming amounts, subtracts outgoing amounts + fees.
  /// Returns sorted list of (timestampMs, cumulativeBalance).
  static List<(int, double)> _buildBalanceTimeline(
      List<TxRecord> txs, bool isNative, String blockchain) {
    final sorted = List<TxRecord>.from(txs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final timeline = <(int, double)>[];
    double balance = 0;

    for (final tx in sorted) {
      if (tx.direction == TxDirection.incoming) {
        balance += tx.amount;
      } else if (tx.direction == TxDirection.outgoing) {
        if (isNative && !_feeInAmount.contains(blockchain)) {
          // Native token on non-UTXO chain: fee is separate from amount
          balance -= tx.amount + (tx.feePaid ?? 0);
        } else {
          // Token (fee paid in native) OR UTXO (fee already in amount)
          balance -= tx.amount;
        }
      }
      // TxDirection.self: no net balance change
      timeline.add((tx.timestamp.millisecondsSinceEpoch,
          balance.clamp(0.0, double.infinity)));
    }
    return timeline;
  }

  /// Find balance at [timestampMs] using binary search on the timeline.
  static double _balanceAtTimestamp(
      List<(int, double)> timeline, int timestampMs) {
    if (timeline.isEmpty) return 0;
    if (timestampMs < timeline.first.$1) return 0; // before first tx
    if (timestampMs >= timeline.last.$1) return timeline.last.$2;

    // Binary search: find last entry with timestamp <= timestampMs
    int lo = 0, hi = timeline.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (timeline[mid].$1 <= timestampMs) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return timeline[lo].$2;
  }

  /// Fetch (and cache for 10 min) transaction history for one asset.
  static Future<List<TxRecord>> _fetchTxHistoryCached(
      Asset asset, List<Asset> allAssets) async {
    final key = '${asset.id}_${asset.contractAddress.substring(0, math.min(8, asset.contractAddress.length))}';
    final cached = _txCache[key];
    if (cached != null && !cached.isExpired) return cached.data;
    try {
      final txs = await fetchHistoryForAsset(
          asset: asset, walletAssets: allAssets, limit: 1000);
      _txCache[key] = _TxCacheEntry(txs);
      if (kDebugMode) debugPrint('[Portfolio] Tx history for ${asset.symbol}: ${txs.length} txs');
      return txs;
    } catch (e) {
      if (kDebugMode) debugPrint('[Portfolio] Tx history failed for ${asset.symbol}: $e');
      return [];
    }
  }

  static Future<List<ChartPoint>> fetchPortfolioHistory({
    required List<Asset> assets,
    required ChartPeriod period,
    String walletId = '',
    List<Asset> allAssets = const [],
  }) async {
    if (kDebugMode) debugPrint('[Portfolio] Fetching chart history for ${period.label} (${assets.length} assets)');
    final relevant = assets.where((a) => a.balanceInUsd > 0 && a.priceUsd > 0).toList();
    if (kDebugMode) debugPrint('[Portfolio] ${relevant.length} assets with non-zero balance');

    if (relevant.isEmpty) {
      if (kDebugMode) debugPrint('[Portfolio] No assets with balance — returning flat synthetic chart');
      return _syntheticFlat(period);
    }

    // Build per-asset data: coinGeckoId + tx history + current coin balance
    // Tx history lets us reconstruct what the balance WAS at each past time point.
    final effectiveAll = allAssets.isNotEmpty ? allAssets : assets;
    final List<({String id, List<TxRecord> txs, double coinBalance, bool isNative, String blockchain})> assetData = [];
    final Set<String> coinGeckoIds = {};

    // Fetch tx histories in parallel
    final txFutures = relevant.map((a) => _fetchTxHistoryCached(a, effectiveAll));
    final txResults = await Future.wait(txFutures);

    for (int i = 0; i < relevant.length; i++) {
      final a  = relevant[i];
      final id = _coinGeckoId(a.symbol, a.blockchain);
      if (id == null) continue;
      final coinBalance = a.balanceAsDouble;
      final isNative = a.type == AssetType.native;
      if (kDebugMode) debugPrint('[Portfolio] ${a.symbol}: coinBalance=${coinBalance.toStringAsFixed(6)}, txs=${txResults[i].length}, native=$isNative');
      assetData.add((id: id, txs: txResults[i], coinBalance: coinBalance, isNative: isNative, blockchain: a.blockchain));
      coinGeckoIds.add(id);
    }

    if (coinGeckoIds.isEmpty) {
      if (kDebugMode) debugPrint('[Portfolio] No CoinGecko IDs found — using synthetic chart');
      return _syntheticFromCurrent(relevant, period, walletId);
    }
    if (kDebugMode) debugPrint('[Portfolio] Grouped into ${coinGeckoIds.length} unique CoinGecko IDs');

    // Fetch price histories (with caching + delay to avoid CoinGecko 429)
    final Map<String, List<List<dynamic>>> histories = {};
    int fetchCount = 0;
    for (final id in coinGeckoIds) {
      try {
        if (kDebugMode) debugPrint('[Portfolio] Fetching price history for $id (${period.days} days)');
        final prices = await _fetchCached(id, period.days);
        if (prices.isNotEmpty) {
          histories[id] = prices;
          if (kDebugMode) debugPrint('[Portfolio] ✓ Got ${prices.length} data points for $id');
        }
        // Delay between uncached requests to respect CoinGecko free-tier rate limit
        fetchCount++;
        if (fetchCount % 3 == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Portfolio] ✗ Failed to fetch $id: $e');
      }
    }

    if (histories.isEmpty) {
      if (kDebugMode) debugPrint('[Portfolio] No price histories fetched — using synthetic chart');
      return _syntheticFromCurrent(relevant, period, walletId);
    }
    if (kDebugMode) debugPrint('[Portfolio] Successfully fetched ${histories.length} price histories');

    // Use the longest history as reference timestamps
    final reference = histories.values.reduce(
        (a, b) => a.length >= b.length ? a : b);
    final timestamps = reference.map((p) => p[0] as int).toList();

    // ── Forward balance reconstruction (per-asset) ──────────────────────
    // Build a cumulative balance timeline per asset (start from 0, apply txs).
    // Validate each asset independently: if forward ≈ actual → use forward,
    // otherwise fall back to simple (currentCoins) for that asset only.
    final Map<int, List<(int, double)>> timelines = {};
    final Map<int, bool> assetUseForward = {};

    for (int j = 0; j < assetData.length; j++) {
      final d = assetData[j];
      final tl = _buildBalanceTimeline(d.txs, d.isNative, d.blockchain);
      timelines[j] = tl;

      // Validate: does forward reconstruction match actual balance?
      final calculated = tl.isEmpty ? 0.0 : tl.last.$2;
      final actual = d.coinBalance;
      bool valid = true;
      if (actual > 0) {
        final diff = (calculated - actual).abs() / actual;
        if (diff > 0.05) {
          valid = false;
          if (kDebugMode) {
            debugPrint('[Portfolio] ⚠ ${d.id}: forward FAILED '
                'calc=${calculated.toStringAsFixed(6)} actual=${actual.toStringAsFixed(6)} '
                'diff=${(diff * 100).toStringAsFixed(1)}% → EXCLUDED from chart');
          }
        } else if (kDebugMode) {
          debugPrint('[Portfolio] ✓ ${d.id}: forward OK '
              'calc=${calculated.toStringAsFixed(6)} actual=${actual.toStringAsFixed(6)}');
        }
      } else if (tl.isEmpty) {
        valid = false; // no txs and no balance — use simple (0)
      }
      assetUseForward[j] = valid;
    }
    if (kDebugMode) {
      final fwd = assetUseForward.values.where((v) => v).length;
      final sim = assetUseForward.values.where((v) => !v).length;
      debugPrint('[Portfolio] Balance method: $fwd FORWARD, $sim SIMPLE');
    }

    final List<ChartPoint> result = [];
    if (kDebugMode) debugPrint('[Portfolio] Calculating ${timestamps.length} portfolio value points');
    for (int i = 0; i < timestamps.length; i++) {
      final ts = timestamps[i];
      double total = 0;
      for (final entry in histories.entries) {
        final history = entry.value;
        final idx = (i * history.length / timestamps.length).round()
            .clamp(0, history.length - 1);
        final priceAtTime = (history[idx][1] as num).toDouble();
        // Sum up all assets sharing this coinGeckoId
        double totalCoinBalance = 0;
        for (int j = 0; j < assetData.length; j++) {
          final d = assetData[j];
          if (d.id == entry.key) {
            if (assetUseForward[j]!) {
              totalCoinBalance += _balanceAtTimestamp(timelines[j]!, ts);
            } else {
              // The fallback the comment above has always promised, and which was never
              // written: hold today's quantity and price it historically. Contributing 0
              // instead meant that when every asset failed validation — which is the normal
              // case, because no explorer returns a complete history from genesis — every
              // point summed to zero and a funded wallet drew a flat $0.00 line.
              //
              // The resulting curve answers "what would what I hold now have been worth
              // then", not "what did I hold then". For a wallet whose quantity has not
              // changed over the window those are the same question, and where they differ
              // this one is at least a true statement about prices.
              totalCoinBalance += d.coinBalance;
            }
          }
        }
        total += priceAtTime * totalCoinBalance;
      }
      result.add(ChartPoint(DateTime.fromMillisecondsSinceEpoch(ts), total));
    }

    if (kDebugMode) {
      final first = result.first.value;
      final last = result.last.value;
      final change = ((last - first) / first * 100);
      debugPrint('[Portfolio] ✓ Chart complete: ${result.length} points, \$${first.toStringAsFixed(2)} → \$${last.toStringAsFixed(2)} (${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%)');
    }

    return result;
  }

  static Future<List<List<dynamic>>> _fetchCached(String coinId, int days) async {
    final key = '${coinId}_$days';
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) return cached.data;

    final url = Uri.parse(
        '$_base/coins/$coinId/market_chart?vs_currency=usd&days=$days');

    http.Response response;
    try {
      response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      if (kDebugMode) debugPrint('[Portfolio] Timeout fetching $coinId — retrying...');
      await Future<void>.delayed(const Duration(seconds: 2));
      response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final prices = (data['prices'] as List).cast<List<dynamic>>();
      _cache[key] = _CacheEntry(prices);
      return prices;
    }
    return [];
  }

  static String? _coinGeckoId(String symbol, String blockchain) {
    const map = {
      'BTC':   'bitcoin',
      'ETH':   'ethereum',
      'SOL':   'solana',
      'BNB':   'binancecoin',
      'TRX':   'tron',
      'USDT':  'tether',
      'USDC':  'usd-coin',
      'DAI':   'dai',
      'LTC':   'litecoin',
      'BCH':   'bitcoin-cash',
      'ETC':   'ethereum-classic',
    };
    return map[symbol.toUpperCase()];
  }

  /// Clear all in-memory caches (price history + tx history).
  /// Called on pull-to-refresh so the chart re-fetches fresh data.
  static void clearCache() {
    _cache.clear();
    _txCache.clear();
  }

  static List<ChartPoint> _syntheticFlat(ChartPeriod period) {
    final now = DateTime.now();
    final count = _pointCount(period);
    return List.generate(count, (i) => ChartPoint(
      now.subtract(Duration(hours: (count - 1 - i) * _hourStep(period))),
      0,
    ));
  }

  static List<ChartPoint> _syntheticFromCurrent(
      List<Asset> assets, ChartPeriod period, String walletId) {
    final currentTotal = assets.fold<double>(0, (s, a) => s + a.balanceInUsd);

    // Weighted average 24h change by USD value
    final totalValue = assets.fold<double>(0, (s, a) => s + a.balanceInUsd);
    final weightedChange = totalValue == 0
        ? 0.0
        : assets.fold<double>(
              0,
              (s, a) => s + a.priceChange24h * (a.balanceInUsd / totalValue),
            );

    final now    = DateTime.now();
    final count  = _pointCount(period);
    // Use wallet-specific seed so different wallets get different noise shapes
    final rng    = math.Random(walletId.hashCode);

    final dailyChange  = weightedChange / 100;
    final totalChange  = dailyChange * period.days;
    final startValue   = currentTotal > 0
        ? currentTotal / (1 + totalChange).clamp(0.1, 10.0)
        : 0.0;

    return List.generate(count, (i) {
      final t     = count > 1 ? i / (count - 1) : 1.0;
      final trend = startValue + (currentTotal - startValue) * t;
      // Mild noise proportional to value and wallet-specific seed
      final noise = currentTotal * 0.006 * (rng.nextDouble() - 0.5);
      return ChartPoint(
        now.subtract(Duration(hours: (count - 1 - i) * _hourStep(period))),
        (trend + noise).clamp(0, double.infinity),
      );
    });
  }

  static int _pointCount(ChartPeriod p) {
    switch (p) {
      case ChartPeriod.day:       return 24;
      case ChartPeriod.week:      return 28;
      case ChartPeriod.month:     return 30;
      case ChartPeriod.sixMonths: return 180;
      case ChartPeriod.year:      return 365;
    }
  }

  static int _hourStep(ChartPeriod p) {
    switch (p) {
      case ChartPeriod.day:       return 1;
      case ChartPeriod.week:      return 6;
      case ChartPeriod.month:     return 24;
      case ChartPeriod.sixMonths: return 24;
      case ChartPeriod.year:      return 24;
    }
  }
}

class _CacheEntry {
  final List<List<dynamic>> data;
  final DateTime _createdAt = DateTime.now();

  _CacheEntry(this.data);

  bool get isExpired =>
      DateTime.now().difference(_createdAt) > const Duration(minutes: 5);
}

class _TxCacheEntry {
  final List<TxRecord> data;
  final DateTime _createdAt = DateTime.now();

  _TxCacheEntry(this.data);

  bool get isExpired =>
      DateTime.now().difference(_createdAt) > const Duration(minutes: 10);
}
