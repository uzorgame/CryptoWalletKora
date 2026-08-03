import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kora/core/models/wallet.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/services/storage_service.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:uuid/uuid.dart';

/// Repository for managing wallets
class WalletRepository {
  static const String _walletsKey = 'wallets';
  static const String _currentWalletIdKey = 'current_wallet_id';

  /// In-memory cache — avoids repeated JSON round-trips during balance refresh.
  List<Wallet>? _cachedWallets;

  void _invalidateCache() => _cachedWallets = null;

  /// Get current wallet
  Future<Wallet?> getCurrentWallet() async {
    final currentId = await StorageService.readString(_currentWalletIdKey);
    if (currentId == null) return null;

    final wallets = await getAllWallets();
    try {
      return wallets.firstWhere((w) => w.id == currentId);
    } catch (e) {
      return null;
    }
  }

  /// Set current wallet
  Future<void> setCurrentWallet(String walletId) async {
    await StorageService.writeString(_currentWalletIdKey, walletId);
  }

  /// Get all wallets (uses in-memory cache to avoid repeated deserialization).
  Future<List<Wallet>> getAllWallets() async {
    if (_cachedWallets != null) return List.of(_cachedWallets!);
    final json = await StorageService.readString(_walletsKey);
    if (json == null || json.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(json);
      _cachedWallets = list.map((e) => Wallet.fromJson(e as Map<String, dynamic>)).toList();
      return List.of(_cachedWallets!);
    } catch (e) {
      return [];
    }
  }

  /// Save wallet
  Future<void> saveWallet(Wallet wallet) async {
    final wallets = await getAllWallets();
    
    // Check if wallet already exists
    final index = wallets.indexWhere((w) => w.id == wallet.id);
    if (index >= 0) {
      wallets[index] = wallet;
    } else {
      wallets.add(wallet);
    }

    await _saveWallets(wallets);
  }

  /// Rename wallet
  Future<void> renameWallet(String walletId, String newName) async {
    final wallets = await getAllWallets();
    final index = wallets.indexWhere((w) => w.id == walletId);
    if (index < 0) return;
    wallets[index] = wallets[index].copyWith(name: newName.trim());
    await _saveWallets(wallets);
  }

  /// Delete wallet
  Future<void> deleteWallet(String walletId) async {
    final wallets = await getAllWallets();
    wallets.removeWhere((w) => w.id == walletId);
    await _saveWallets(wallets);

    // Delete wallet-specific seed phrase
    await KeyManager.deleteSeedPhrase(walletId: walletId);

    // If deleted wallet was current, set next available or clear
    final currentId = await StorageService.readString(_currentWalletIdKey);
    if (currentId == walletId) {
      if (wallets.isNotEmpty) {
        await StorageService.writeString(_currentWalletIdKey, wallets.first.id);
      } else {
        await StorageService.delete(_currentWalletIdKey);
      }
    }
  }

  /// Create new wallet from mnemonic
  Future<Wallet> createWallet({
    required String name,
    required String mnemonic,
    required String pin,
  }) async {
    final Stopwatch? swTotal = kDebugMode ? (Stopwatch()..start()) : null;
    final id = const Uuid().v4();
    // Store app-level PIN on first wallet creation
    if (!await KeyManager.hasAppPin()) {
      await KeyManager.storeAppPin(pin);
    }
    // Store seed phrase keyed by wallet ID
    await KeyManager.storeSeedPhrase(mnemonic, pin, walletId: id);
    if (kDebugMode) debugPrint('[PERF][WalletRepo] createWallet crypto done: ${swTotal!.elapsedMilliseconds}ms');

    // Create wallet
    final wallet = Wallet(
      id: id,
      name: name,
      type: WalletType.seedPhrase,
      mainAddress: '', // Will be set when addresses are generated
      addresses: {},
      assets: [],
      createdAt: DateTime.now(),
      isBackedUp: false,
    );

    await saveWallet(wallet);
    await setCurrentWallet(id);

    return wallet;
  }

  /// Import wallet from mnemonic
  Future<Wallet> importWallet({
    required String name,
    required String mnemonic,
    required String pin,
  }) async {
    final Stopwatch? swTotal = kDebugMode ? (Stopwatch()..start()) : null;
    final id = const Uuid().v4();
    // Store app-level PIN on first wallet creation
    if (!await KeyManager.hasAppPin()) {
      await KeyManager.storeAppPin(pin);
    }
    // Store seed phrase keyed by wallet ID
    await KeyManager.storeSeedPhrase(mnemonic, pin, walletId: id);
    if (kDebugMode) debugPrint('[PERF][WalletRepo] importWallet crypto done: ${swTotal!.elapsedMilliseconds}ms');

    // Create wallet
    final wallet = Wallet(
      id: id,
      name: name,
      type: WalletType.imported,
      mainAddress: '',
      addresses: {},
      assets: [],
      createdAt: DateTime.now(),
      isBackedUp: false, // Imported wallets have NOT been verified by this device
    );

    await saveWallet(wallet);
    await setCurrentWallet(id);

    return wallet;
  }

  /// Update wallet backup status
  Future<void> markWalletAsBackedUp(String walletId) async {
    final wallets = await getAllWallets();
    final index = wallets.indexWhere((w) => w.id == walletId);
    
    if (index >= 0) {
      final wallet = wallets[index];
      final updatedWallet = wallet.copyWith(
        isBackedUp: true,
        lastBackup: DateTime.now(),
      );
      wallets[index] = updatedWallet;
      await _saveWallets(wallets);
      
      // Update KeyManager
      await KeyManager.markBackupAsDone();
    }
  }

  /// Update wallet addresses
  Future<void> updateWalletAddresses(
    String walletId,
    Map<String, String> addresses,
  ) async {
    final wallets = await getAllWallets();
    final index = wallets.indexWhere((w) => w.id == walletId);
    
    if (index >= 0) {
      final wallet = wallets[index];
      final updatedWallet = wallet.copyWith(
        addresses: addresses,
        mainAddress: addresses['ethereum'] ?? wallet.mainAddress,
      );
      wallets[index] = updatedWallet;
      await _saveWallets(wallets);
    }
  }

  /// Update wallet assets
  Future<void> updateWalletAssets(String walletId, List<Asset> assets) async {
    final wallets = await getAllWallets();
    final index = wallets.indexWhere((w) => w.id == walletId);
    
    if (index >= 0) {
      final wallet = wallets[index];
      final updatedWallet = wallet.copyWith(assets: assets);
      wallets[index] = updatedWallet;
      await _saveWallets(wallets);
    }
  }

  /// Check if wallet exists
  Future<bool> hasWallets() async {
    final wallets = await getAllWallets();
    return wallets.isNotEmpty;
  }

  /// Delete all wallets (use with caution!)
  Future<void> deleteAllWallets() async {
    _invalidateCache();
    await StorageService.delete(_walletsKey);
    await StorageService.delete(_currentWalletIdKey);
    await KeyManager.deleteAll();
  }

  // Private helper
  Future<void> _saveWallets(List<Wallet> wallets) async {
    _cachedWallets = List.of(wallets); // update cache before async write
    final json = jsonEncode(wallets.map((e) => e.toJson()).toList());
    await StorageService.writeString(_walletsKey, json);
  }
}
