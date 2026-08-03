import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/models/wallet.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/repositories/wallet_repository.dart';
import 'package:kora/core/services/wallet_initialization_service.dart';
import 'package:kora/core/services/token_validation_service.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/constants/token_catalog.dart';
import 'package:kora/core/repositories/price_repository.dart' show PriceRepository;
import 'package:kora/core/services/balance_service.dart';
import 'package:kora/core/services/tx_history_service.dart';
import 'package:kora/core/widgets/chips/coin_icon.dart';

// ==================== REPOSITORY PROVIDER ====================

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository();
});

// ==================== CURRENT WALLET PROVIDER ====================

/// True while background Tier 2/3 address derivation is running.
final isDerivingProvider = StateProvider<bool>((ref) => false);

/// Human-readable progress label shown in the sync banner, e.g. "Syncing 8/45 assets".
final derivingSyncTextProvider = StateProvider<String>((ref) => '');

/// True when a wallet has assets that need address migration but the app
/// could not decrypt the seed with the default fallback — user PIN required.
final needsMigrationPinProvider = StateProvider<bool>((ref) => false);

final currentWalletProvider = StateNotifierProvider<CurrentWalletNotifier, AsyncValue<Wallet?>>((ref) {
  return CurrentWalletNotifier(ref.read(walletRepositoryProvider), ref);
});

class CurrentWalletNotifier extends StateNotifier<AsyncValue<Wallet?>>
    with WidgetsBindingObserver {
  final WalletRepository _repository;
  final Ref _ref;
  int _fetchGeneration = 0;
  Timer? _priceRefreshTimer;
  Timer? _balanceRefreshTimer;
  Timer? _optimisticRefreshTimer;
  // assetId → optimistic balance string; guards against stale-cache overwrite
  final Map<String, String> _optimisticBalances = {};

  void _setDeriving(bool val) {
    if (mounted) _ref.read(isDerivingProvider.notifier).state = val;
    if (!val && mounted) _ref.read(derivingSyncTextProvider.notifier).state = '';
  }

  void _setSyncText(String text) {
    if (mounted) _ref.read(derivingSyncTextProvider.notifier).state = text;
  }

  CurrentWalletNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    WidgetsBinding.instance.addObserver(this);
    _loadWallet();
    _startPriceRefreshTimer();
    _startBalanceRefreshTimer();
    // Run token validation in background (debug only)
    if (kDebugMode) {
      Future.delayed(const Duration(seconds: 1), () {
        TokenValidationService.validateAllTokens();
      });
    }
  }

  /// Refresh all balances every 3 minutes in the background.
  void _startBalanceRefreshTimer() {
    _balanceRefreshTimer?.cancel();
    _balanceRefreshTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (!mounted) return;
      final wallet = state.valueOrNull;
      if (wallet == null) return;
      if (kDebugMode) debugPrint('[BalanceTimer] ⏱ 3-min periodic balance refresh');
      BalanceService.invalidateAll();
      await refreshBalances();
    });
    if (kDebugMode) debugPrint('[BalanceTimer] 🕑 3-minute balance refresh timer started');
  }

  /// Refresh prices every hour in the background (fire-and-forget).
  void _startPriceRefreshTimer() {
    _priceRefreshTimer?.cancel();
    _priceRefreshTimer = Timer.periodic(const Duration(hours: 1), (_) async {
      final wallet = state.valueOrNull;
      if (wallet == null || !mounted) return;
      try {
        final priceSvc = WalletInitializationService();
        final updated  = await priceSvc.updateAssetPrices(wallet.assets);
        await _repository.updateWalletAssets(wallet.id, updated);
        if (mounted) state = AsyncValue.data(await _repository.getCurrentWallet());
        if (kDebugMode) debugPrint('[PriceTimer] ✅ Hourly price refresh done');
      } catch (e) {
        if (kDebugMode) debugPrint('[PriceTimer] ⚠ Hourly price refresh failed: $e');
      }
    });
    if (kDebugMode) debugPrint('[PriceTimer] 🕑 1-hour price refresh timer started');
  }

  Future<void> _loadWallet() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (kDebugMode) debugPrint('[WalletProvider] Loading current wallet…');
      final wallet = await _repository.getCurrentWallet();
      if (wallet == null) {
        if (kDebugMode) debugPrint('[WalletProvider] No wallet found.');
        return null;
      }
      final needsMigration = wallet.assets.isEmpty || _hasAddressMismatch(wallet.assets);
      if (needsMigration) {
        if (kDebugMode) debugPrint('[WalletProvider] Migration needed (assets=${wallet.assets.length}, mismatch=${_hasAddressMismatch(wallet.assets)})…');
        final mnemonic = await KeyManager.getSeedPhrase('000000', walletId: wallet.id);
        if (mnemonic != null) {
          return _initAssets(wallet.id, mnemonic);
        }
        // '000000' fallback failed — signal UI to request the real PIN
        if (kDebugMode) debugPrint('[WalletProvider] Seed phrase not found with fallback PIN — requesting user PIN.');
        if (mounted) _ref.read(needsMigrationPinProvider.notifier).state = true;
      } else {
        if (kDebugMode) debugPrint('[WalletProvider] Wallet "${wallet.name}" loaded with ${wallet.assets.length} assets.');
        // Background: refresh balances so stale DB values are updated after restart
        _fetchAndStoreBalances(wallet.id, wallet.assets, ++_fetchGeneration);
      }
      return wallet;
    });
  }

  /// Returns true when stored addresses need re-derivation.
  bool _hasAddressMismatch(List<Asset> assets) {
    // Only check chains we actually support with proper address derivation.
    // Unsupported chains (bitcoin_cash, etc.) always get an ETH
    // placeholder address — checking them would trigger a false migration that
    // wipes all user-added tokens on every app restart.
    const utxoChains = {'litecoin'};
    // UTXO chains should never have a 0x address
    final utxoWrong = assets.any((a) =>
        utxoChains.contains(a.blockchain) &&
        a.contractAddress.startsWith('0x'));
    // ETC must use coin_type 61 (different address than ETH coin_type 60)
    final ethAddr = assets
        .where((a) => a.blockchain == 'ethereum')
        .map((a) => a.contractAddress)
        .firstOrNull;
    final etcAddr = assets
        .where((a) => a.blockchain == 'ethereum_classic')
        .map((a) => a.contractAddress)
        .firstOrNull;
    final etcWrong = ethAddr != null && etcAddr != null &&
        ethAddr.toLowerCase() == etcAddr.toLowerCase();
    return utxoWrong || etcWrong;
  }

  /// Re-derive all wallet addresses using the user-provided PIN.
  /// Call this when [_hasAddressMismatch] is true and the auto-migration
  /// with the default PIN failed (i.e., user has a non-default PIN).
  Future<bool> refreshWalletAddresses(String pin) async {
    final wallet = state.value;
    if (wallet == null) return false;
    final mnemonic = await KeyManager.getSeedPhrase(pin, walletId: wallet.id);
    if (mnemonic == null) return false;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _initAssets(wallet.id, mnemonic));
    if (state.hasValue && mounted) {
      _ref.read(needsMigrationPinProvider.notifier).state = false;
    }
    return state.hasValue;
  }

  Future<void> createWallet({
    required String name,
    required String mnemonic,
    required String pin,
  }) async {
    if (kDebugMode) debugPrint('[WalletProvider] Creating wallet "$name"…');
    await WalletInitializationService.clearAddressCache();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final wallet = await _repository.createWallet(
        name: name,
        mnemonic: mnemonic,
        pin: pin,
      );
      if (kDebugMode) debugPrint('[WalletProvider] Wallet created: ${wallet.id}');
      return _initAssets(wallet.id, mnemonic);
    });
  }

  Future<void> importWallet({
    required String name,
    required String mnemonic,
    required String pin,
  }) async {
    if (kDebugMode) debugPrint('[WalletProvider] Importing wallet "$name"…');
    await WalletInitializationService.clearAddressCache();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final wallet = await _repository.importWallet(
        name: name,
        mnemonic: mnemonic,
        pin: pin,
      );
      if (kDebugMode) debugPrint('[WalletProvider] Wallet imported: ${wallet.id}');
      return _initAssets(wallet.id, mnemonic);
    });
  }

  Future<Wallet?> _initAssets(String walletId, String mnemonic) async {
    final sw  = Stopwatch()..start();
    final svc = WalletInitializationService();
    if (kDebugMode) debugPrint('[PERF][WalletProvider] _initAssets START');

    // Fast path: full address cache present — load everything at once
    if (await WalletInitializationService.hasCachedAddresses(mnemonic)) {
      if (kDebugMode) debugPrint('[WalletProvider] Cache HIT — loading all assets at once');
      final defaultAssets = await svc.initializeWallet(mnemonic);
      // Merge: preserve user visibility prefs + keep user-added catalog extras
      final existingWallet = await _repository.getCurrentWallet();
      final List<Asset> assets;
      if (existingWallet != null && existingWallet.assets.isNotEmpty) {
        final defaultIds   = {for (final a in defaultAssets) a.id};
        final existingById = {for (final a in existingWallet.assets) a.id: a};
        final base = defaultAssets.map((a) {
          final ex = existingById[a.id];
          if (ex == null) return a;
          return a.copyWith(isVisible: ex.isVisible, balance: ex.balance, balanceInUsd: ex.balanceInUsd);
        }).toList();
        final extras = existingWallet.assets.where((a) => !defaultIds.contains(a.id)).toList();
        assets = [...base, ...extras];
      } else {
        assets = defaultAssets;
      }
      final addresses = {for (final a in assets.where((a) => a.type.name == 'native')) a.blockchain: a.contractAddress};
      await _repository.updateWalletAssets(walletId, assets);
      await _repository.updateWalletAddresses(walletId, addresses);
      sw.stop();
      if (kDebugMode) debugPrint('[PERF][WalletProvider] _initAssets DONE (cache): ${sw.elapsedMilliseconds}ms  assets=${assets.length}');
      _fetchAndStoreBalances(walletId, assets, ++_fetchGeneration);
      return _repository.getCurrentWallet();
    }

    // Slow path (cache MISS = first import/create): Tier 1 now, Tier 2/3 in background
    if (kDebugMode) debugPrint('[WalletProvider] Cache MISS — Tier 1 fast derivation');
    final tier1     = await svc.initializeTier1(mnemonic);
    final tier1Addr = {for (final a in tier1.where((a) => a.type.name == 'native')) a.blockchain: a.contractAddress};
    await _repository.updateWalletAssets(walletId, tier1);
    await _repository.updateWalletAddresses(walletId, tier1Addr);
    sw.stop();
    if (kDebugMode) debugPrint('[PERF][WalletProvider] _initAssets Tier 1 DONE: ${sw.elapsedMilliseconds}ms  assets=${tier1.length}');

    // Show wallet immediately with Tier 1
    state = AsyncValue.data(await _repository.getCurrentWallet());

    // Background: fetch balances for Tier 1, then derive remaining chains
    final gen = ++_fetchGeneration;
    _fetchAndStoreBalances(walletId, tier1, gen);
    _deriveAndAddRemainingAssets(walletId, mnemonic);

    return _repository.getCurrentWallet();
  }

  /// Total assets produced by initializeWallet — used for the progress label.
  static const _totalWalletAssets = 51;

  /// Derives all Tier 2/3 chains in background (called only on cache MISS).
  Future<void> _deriveAndAddRemainingAssets(String walletId, String mnemonic) async {
    if (!mounted) return;
    _setDeriving(true);
    List<Asset>? mergedForFetch; // populated on success, used after finally
    try {
      final tier1Count = state.value?.assets.length ?? 8;
      _setSyncText('Deriving addresses… ($tier1Count/$_totalWalletAssets ready)');
      if (kDebugMode) debugPrint('[WalletProvider] Background: deriving Tier 2/3 assets…');

      final svc       = WalletInitializationService();
      final allAssets = await svc.initializeWallet(mnemonic); // derives all + caches
      if (!mounted) return;

      // Merge: preserve Tier 1 live data (balances already fetched), add Tier 2/3
      final currentWallet = state.value;
      if (currentWallet == null) return;
      final defaultIds   = {for (final a in allAssets) a.id};
      final existingById = {for (final a in currentWallet.assets) a.id: a};
      final base         = allAssets.map((a) => existingById[a.id] ?? a).toList();
      // Preserve user-added catalog tokens not in the default set
      final extras = currentWallet.assets.where((a) => !defaultIds.contains(a.id)).toList();
      final merged = [...base, ...extras];

      final allAddr = {for (final a in merged.where((a) => a.type.name == 'native')) a.blockchain: a.contractAddress};
      await _repository.updateWalletAssets(walletId, merged);
      await _repository.updateWalletAddresses(walletId, allAddr);
      if (mounted) state = AsyncValue.data(await _repository.getCurrentWallet());
      if (kDebugMode) debugPrint('[WalletProvider] Background derivation complete: ${merged.length} assets');
      mergedForFetch = merged;
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletProvider] Background derivation error: $e');
    } finally {
      _setDeriving(false); // banner disappears; skeleton tiles removed
    }
    // Balance fetch starts after the banner closes (fire-and-forget)
    if (mergedForFetch != null && mounted) {
      _fetchAndStoreBalances(walletId, mergedForFetch, ++_fetchGeneration);
    }
  }

  /// Refresh on-chain balances for all assets of the current wallet.
  Future<void> refreshBalances() async {
    final wallet = state.value;
    if (wallet == null) return;
    _fetchGeneration++; // invalidate any concurrent background fetch
    if (kDebugMode) {
      debugPrint('[WalletProvider] Refreshing balances…');
      debugPrint('[WalletProvider] refreshBalances CALLER:\n${StackTrace.current}');
    }
    try {
      final balSvc  = BalanceService();
      var   updated = await balSvc.fetchBalances(wallet.assets);
      // Protect optimistic balances: if fetched (cached) > optimistic, keep optimistic
      if (_optimisticBalances.isNotEmpty) {
        updated = updated.map((a) {
          final optStr = _optimisticBalances[a.id];
          if (optStr == null) return a;
          final optBal     = double.tryParse(optStr) ?? 0;
          final fetchedBal = double.tryParse(a.balance) ?? 0;
          if (fetchedBal > optBal) {
            if (kDebugMode) debugPrint('[WalletProvider] Protecting optimistic ${a.id}: fetched=$fetchedBal > opt=$optBal → keeping $optStr');
            return a.copyWith(balance: optStr);
          }
          // Real on-chain balance confirmed (≤ optimistic) → clear protection
          _optimisticBalances.remove(a.id);
          return a;
        }).toList();
      }
      // Also refresh prices
      final priceSvc = WalletInitializationService();
      updated = await priceSvc.updateAssetPrices(updated);
      await _repository.updateWalletAssets(wallet.id, updated);
      state = AsyncValue.data(await _repository.getCurrentWallet());
      if (kDebugMode) debugPrint('[WalletProvider] Balances refreshed ✓');
      _prefetchHistories(updated); // fire-and-forget
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletProvider] Balance refresh error: $e');
    }
  }

  /// Fire-and-forget: fetch balances then persist without blocking the caller.
  /// [gen] is the generation at call time — stale completions are discarded.
  Future<void> _fetchAndStoreBalances(String walletId, List<Asset> assets, int gen) async {
    final sw = Stopwatch()..start();
    if (kDebugMode) debugPrint('[PERF][WalletProvider] _fetchAndStoreBalances START: ${assets.length} assets gen=$gen');
    try {
      final balSvc  = BalanceService();
      var   updated = await balSvc.fetchBalances(assets);
      if (kDebugMode) debugPrint('[PERF][WalletProvider] _fetchAndStoreBalances after balances: ${sw.elapsedMilliseconds}ms');
      if (!mounted || _fetchGeneration != gen) {
        if (kDebugMode) debugPrint('[WalletProvider] _fetchAndStoreBalances gen=$gen stale (current=$_fetchGeneration) — discarded');
        return;
      }
      // Price update is non-critical — balances always persist even if prices fail
      try {
        final priceSvc = WalletInitializationService();
        updated = await priceSvc.updateAssetPrices(updated);
      } catch (e) {
        if (kDebugMode) debugPrint('[WalletProvider] Price update failed, keeping stale prices: $e');
      }
      // Protect optimistic balances: same guard as refreshBalances()
      if (_optimisticBalances.isNotEmpty) {
        updated = updated.map((a) {
          final optStr = _optimisticBalances[a.id];
          if (optStr == null) return a;
          final optBal     = double.tryParse(optStr) ?? 0;
          final fetchedBal = double.tryParse(a.balance) ?? 0;
          if (fetchedBal > optBal) return a.copyWith(balance: optStr);
          _optimisticBalances.remove(a.id);
          return a;
        }).toList();
      }
      // Auto-show any asset whose balance just became non-zero
      updated = updated.map((a) {
        if (!a.isVisible && (double.tryParse(a.balance) ?? 0) > 0) {
          return a.copyWith(isVisible: true);
        }
        return a;
      }).toList();
      await _repository.updateWalletAssets(walletId, updated);
      sw.stop();
      if (kDebugMode) debugPrint('[PERF][WalletProvider] _fetchAndStoreBalances DONE: ${sw.elapsedMilliseconds}ms');
      if (mounted && state.hasValue && _fetchGeneration == gen) {
        state = AsyncValue.data(await _repository.getCurrentWallet());
      }
      // After balances known: prefetch history for Tier 1 + non-zero balance assets
      _prefetchHistories(updated);
    } catch (e) {
      if (kDebugMode) debugPrint('[WalletProvider] Background balance fetch error: $e');
    }
  }

  // Tier 1 asset IDs — histories fetched proactively
  static const _tier1Ids = {'btc', 'eth', 'sol', 'bnb', 'trx', 'usdt_trx', 'usdc_eth'};

  /// Background prefetch of tx-histories for Tier 1 + non-zero balance assets.
  /// Throttle: 3 concurrent (heavy requests, can be slow).
  Future<void> _prefetchHistories(List<Asset> assets) async {
    const maxConcurrent = 3; // history requests are heavy
    final targets = assets.where((a) =>
        _tier1Ids.contains(a.id) ||
        (double.tryParse(a.balance) ?? 0) > 0).toList();
    if (targets.isEmpty) return;
    if (kDebugMode) debugPrint('[WalletProvider] Prefetching history for ${targets.length} assets (batch ≤3)');
    for (int i = 0; i < targets.length; i += maxConcurrent) {
      if (!mounted) return;
      final batch = targets.skip(i).take(maxConcurrent).toList();
      await Future.wait(batch.map((asset) async {
        if (!mounted) return;
        try {
          final records = await fetchHistoryForAsset(asset: asset, walletAssets: assets);
          if (!mounted) return;
          setCachedHistory(asset, records);
          if (kDebugMode) debugPrint('[WalletProvider] Prefetch history ${asset.id}: ${records.length} txs');
        } catch (_) {}
      }));
    }
  }

  /// Add a token from the catalog to the current wallet.
  Future<void> addToken(CatalogToken token) async {
    final wallet = state.value;
    if (wallet == null) return;

    // Asset already in wallet (e.g. from background derivation) — just make it visible.
    final existingIndex = wallet.assets.indexWhere((a) => a.id == token.id);
    if (existingIndex != -1) {
      if (wallet.assets[existingIndex].isVisible) return;
      final updated = List<Asset>.from(wallet.assets);
      updated[existingIndex] = updated[existingIndex].copyWith(isVisible: true);
      await _repository.updateWalletAssets(wallet.id, updated);
      state = AsyncValue.data(await _repository.getCurrentWallet());
      _fetchAndStoreBalances(wallet.id, updated, ++_fetchGeneration);
      return;
    }

    if (kDebugMode) debugPrint('[WalletProvider] Adding token ${token.id}…');

    // Determine wallet address for this token's blockchain
    final addresses = wallet.addresses;
    final walletAddress = addresses[token.blockchain]
        ?? addresses['ethereum']     // fallback for ERC-20 / BEP-20
        ?? '';

    // Fetch price from CoinGecko
    double priceUsd    = 0.0;
    double change24h   = 0.0;
    try {
      final prices = await PriceRepository().getPricesOptimized([token.coinGeckoId]);
      priceUsd  = prices[token.coinGeckoId]?.priceUsd  ?? 0.0;
      change24h = prices[token.coinGeckoId]?.change24h ?? 0.0;
    } catch (_) {}

    final asset = Asset(
      id: token.id,
      symbol: token.symbol,
      name: token.name,
      blockchain: token.blockchain,
      contractAddress: walletAddress,
      decimals: token.decimals,
      balance: '0',
      balanceInUsd: 0.0,
      priceUsd: priceUsd,
      priceChange24h: change24h,
      iconUrl: coinIconUrl(token.symbol),
      type: token.type,
      isVisible: true,
    );

    final updated = [...wallet.assets, asset];
    await _repository.updateWalletAssets(wallet.id, updated);
    state = AsyncValue.data(await _repository.getCurrentWallet());
    // Immediately fetch balance for the new token so it doesn't stay 0
    _fetchAndStoreBalances(wallet.id, updated, ++_fetchGeneration);
  }

  /// Remove a token from the current wallet by its asset id.
  Future<void> removeToken(String assetId) async {
    final wallet = state.value;
    if (wallet == null) return;
    if (kDebugMode) debugPrint('[WalletProvider] Hiding token $assetId…');
    // Set isVisible: false — preserves derived address for future re-enable.
    final updated = wallet.assets
        .map((a) => a.id == assetId ? a.copyWith(isVisible: false) : a)
        .toList();
    await _repository.updateWalletAssets(wallet.id, updated);
    state = AsyncValue.data(await _repository.getCurrentWallet());
  }

  Future<void> switchWallet(String walletId) async {
    await _repository.setCurrentWallet(walletId);
    await _loadWallet();
  }

  Future<void> updateAddresses(Map<String, String> addresses) async {
    final currentWallet = state.value;
    if (currentWallet == null) return;

    await _repository.updateWalletAddresses(currentWallet.id, addresses);
    await _loadWallet();
  }

  Future<void> updateAssets(List<Asset> assets) async {
    final currentWallet = state.value;
    if (currentWallet == null) return;

    await _repository.updateWalletAssets(currentWallet.id, assets);
    await _loadWallet();
  }

  Future<void> markAsBackedUp() async {
    final currentWallet = state.value;
    if (currentWallet == null) return;

    await _repository.markWalletAsBackedUp(currentWallet.id);
    await _loadWallet();
  }

  Future<void> renameWallet(String walletId, String newName) async {
    await _repository.renameWallet(walletId, newName);
    await _loadWallet();
  }

  Future<void> deleteWallet(String walletId) async {
    await WalletInitializationService.clearAddressCache();
    await _repository.deleteWallet(walletId);
    await _loadWallet();
  }

  void refresh() {
    _loadWallet();
  }

  /// Immediately apply an optimistic balance for [assetId] (after a send),
  /// then schedule a real blockchain balance refresh after [refreshDelay].
  Future<void> applyOptimisticBalance(
    String assetId,
    String newBalance, {
    Duration refreshDelay = const Duration(minutes: 4),
  }) async {
    final wallet = state.value;
    if (wallet == null) return;
    final updatedAssets = wallet.assets.map((a) {
      if (a.id == assetId) return a.copyWith(balance: newBalance);
      return a;
    }).toList();
    await _repository.updateWalletAssets(wallet.id, updatedAssets);
    if (mounted) state = AsyncValue.data(wallet.copyWith(assets: updatedAssets));
    _optimisticBalances[assetId] = newBalance;
    _optimisticRefreshTimer?.cancel();
    _optimisticRefreshTimer = Timer(refreshDelay, () {
      if (mounted) {
        _optimisticBalances.remove(assetId); // allow real balance to overwrite
        BalanceService.invalidateAll();       // force fresh fetch, not cached
        refreshBalances();
      }
    });
    if (kDebugMode) debugPrint('[WalletProvider] Optimistic balance $assetId → $newBalance (refresh in ${refreshDelay.inMinutes}m)');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      final wallet = state.valueOrNull;
      if (wallet == null || !mounted) return;
      if (kDebugMode) debugPrint('[WalletProvider] App resumed — invalidating cache and refreshing balances');
      BalanceService.invalidateAll();
      refreshBalances();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _priceRefreshTimer?.cancel();
    _balanceRefreshTimer?.cancel();
    _optimisticRefreshTimer?.cancel();
    super.dispose();
  }
}

// ==================== ALL WALLETS PROVIDER ====================

final allWalletsProvider = FutureProvider<List<Wallet>>((ref) async {
  ref.watch(currentWalletProvider); // re-fetch whenever wallet state changes
  final repository = ref.read(walletRepositoryProvider);
  return repository.getAllWallets();
});

// ==================== HAS WALLETS PROVIDER ====================

final hasWalletsProvider = FutureProvider<bool>((ref) async {
  final repository = ref.read(walletRepositoryProvider);
  return repository.hasWallets();
});
