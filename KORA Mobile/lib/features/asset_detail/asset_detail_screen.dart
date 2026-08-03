import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/services/tx_history_service.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/constants/token_catalog.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/widgets/coin_icon.dart';
import 'package:kora/features/receive/receive_screen.dart';
import 'package:kora/features/send/send_screen.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/core/widgets/animated_tap.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/services/balance_service.dart';
import 'package:kora/features/asset_detail/token_price_chart_widget.dart';
import 'package:kora/features/asset_detail/widgets/collapsible_details.dart';
import 'package:kora/features/asset_detail/widgets/transaction_tile.dart';

// ─── Supported chains for history ─────────────────────────────────────────────
bool _hasHistory(String chain) =>
    APIConfig.evmChains.contains(chain) ||
    chain == 'tron'     || chain == 'solana'      ||
    chain == 'bitcoin'  ||
    chain == 'litecoin' || chain == 'bitcoin_cash';

// ─── Screen ───────────────────────────────────────────────────────────────────

class AssetDetailScreen extends ConsumerStatefulWidget {
  const AssetDetailScreen({super.key, required this.asset});
  final Asset asset;

  @override
  ConsumerState<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends ConsumerState<AssetDetailScreen> with ThemeAwareMixin {
  bool _detailsExpanded = false;
  List<TxRecord> _txRecords = [];
  bool   _txLoading = true;
  bool   _txFetched = false; // true only after a successful API call
  String? _txError;
  bool   _disposed = false;

  @override
  void initState() {
    super.initState();
    if (_hasHistory(widget.asset.blockchain)) _loadHistory();
    else setState(() => _txLoading = false);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ── Resolve the user's wallet address for this chain ──────────────────────
  String _walletAddress(Asset a) {
    final raw = a.type == AssetType.native
        ? a.contractAddress
        : (ref.read(currentWalletProvider).value?.assets ?? [])
            .firstWhere((x) => x.blockchain == a.blockchain && x.type == AssetType.native,
                orElse: () => a)
            .contractAddress;
    return raw;
  }

  // ── Look up the on-chain contract address from the catalog ─────────────────
  // For tokens, asset.contractAddress stores the *wallet* address (set at init).
  // The actual token contract (e.g. TR7NHqje… for USDT-TRX) lives in the catalog.
  static String? _tokenContractAddr(Asset a) {
    if (a.type != AssetType.token) return null;
    try {
      return allCatalogTokens.firstWhere((t) => t.id == a.id).contractAddress;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadHistory({bool force = false}) async {
    if (mounted) setState(() { _txLoading = true; _txError = null; });
    try {
      // Load persisted pending TXs — survive cache clears and app restarts
      final pendingTxs = await PendingTxStore.load(widget.asset.id);
      // Check background-prefetch cache first (skip if force-refreshing)
      if (!force) {
        final cached = getCachedHistory(widget.asset);
        if (cached != null) {
          // Inject any persistent pending txs not yet in the in-memory cache
          final cachedHashes  = cached.map((r) => r.hash).toSet();
          final extraPending  = pendingTxs.where((p) => !cachedHashes.contains(p.hash)).toList();
          final display = extraPending.isEmpty
              ? cached
              : ([...extraPending, ...cached]..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
          if (extraPending.isNotEmpty) setCachedHistory(widget.asset, display);
          if (mounted) setState(() { _txRecords = display; _txLoading = false; _txFetched = true; });
          return;
        }
      } else {
        invalidateCachedHistory(widget.asset);
        // Invalidate balance cache so the next refresh fetches a live value.
        BalanceService.invalidateAsset(widget.asset);
        // Also invalidate the native coin if this is a token (same address).
        final wallet = ref.read(currentWalletProvider).value;
        if (wallet != null) {
          final native = wallet.assets.where((a) =>
              a.blockchain == widget.asset.blockchain && a.type == AssetType.native);
          for (final n in native) BalanceService.invalidateAsset(n);
        }
        unawaited(ref.read(currentWalletProvider.notifier).refreshBalances());
      }

      final chain        = widget.asset.blockchain;
      final userAddress  = _walletAddress(widget.asset);
      final contractAddr = _tokenContractAddr(widget.asset);

      List<TxRecord> records = [];
      if (APIConfig.evmChains.contains(chain)) {
        records = await fetchEvmHistory(
          address: userAddress, blockchain: chain, contractAddress: contractAddr);
      } else if (chain == 'tron') {
        records = await fetchTronHistory(
          address: userAddress, contractAddress: contractAddr);
      } else if (chain == 'solana') {
        if (widget.asset.type == AssetType.token && contractAddr != null) {
          records = await fetchSolanaTokenHistory(
            ownerAddress: userAddress,
            mintAddress:  contractAddr,
            symbol:       widget.asset.symbol,
            decimals:     widget.asset.decimals,
          );
        } else {
          records = await fetchSolanaHistory(address: userAddress);
        }
      } else if (chain == 'bitcoin') {
        records = await fetchBitcoinHistory(address: userAddress);
      } else if (chain == 'litecoin') {
        records = await fetchLitecoinHistory(address: userAddress);
      } else if (chain == 'bitcoin_cash') {
        records = await fetchBlockchairUtxoHistory(
          address: userAddress, blockchain: chain,
          symbol:  widget.asset.symbol);
      }
      if (_disposed) return;
      records = records.where((r) => r.confirmed).toList();
      // Merge: re-attach any pending (optimistic) TXs not yet confirmed on-chain
      final confirmedHashes = records.map((r) => r.hash).toSet();
      final stillPending = pendingTxs.where((p) => !confirmedHashes.contains(p.hash)).toList();
      // Some pending TXs just got confirmed → remove from store + sync balance
      if (pendingTxs.isNotEmpty && stillPending.length < pendingTxs.length) {
        unawaited(PendingTxStore.removeConfirmed(widget.asset.id, confirmedHashes));
        ref.read(currentWalletProvider.notifier).refreshBalances();
      }
      final merged = [...stillPending, ...records]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setCachedHistory(widget.asset, merged);
      if (mounted) setState(() { _txRecords = merged; _txLoading = false; _txFetched = true; });
    } on SocketException {
      if (_disposed || !mounted) return;
      setState(() { _txLoading = false; _txError = 'no_internet'; });
    } on http.ClientException {
      if (_disposed || !mounted) return;
      setState(() { _txLoading = false; _txError = 'no_internet'; });
    } catch (e) {
      if (_disposed || !mounted) return;
      setState(() { _txLoading = false; _txError = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final _widgetAsset = widget.asset;
    // Live asset from provider: balance/price reflect optimistic & real updates
    final asset = ref.watch(currentWalletProvider).value?.assets
        .firstWhere((a) => a.id == _widgetAsset.id, orElse: () => _widgetAsset)
        ?? _widgetAsset;
    final isUp     = asset.priceChange24h >= 0;
    final currency = ref.watch(currencyProvider);

    // Sync displayed records when a pending (optimistic) TX is added to the
    // cache while this screen is already mounted (e.g., user sent and came back)
    ref.listen(currentWalletProvider, (_, __) {
      if (!mounted) return;
      final cached = getCachedHistory(widget.asset);
      if (cached == null) return;
      final newPending = cached.where((tx) =>
          !tx.confirmed && !_txRecords.any((r) => r.hash == tx.hash)).toList();
      if (newPending.isNotEmpty) setState(() { _txRecords = cached; });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(asset.symbol),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () { Navigator.of(context).pop(); },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 20),
            onPressed: () { _loadHistory(force: true); },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadHistory(force: true),
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        child: ListView(padding: EdgeInsets.zero, children: [

          // ── Header card ───────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(children: [
              CoinIcon(symbol: asset.symbol, iconUrl: asset.iconUrl, size: 64),
              const SizedBox(height: 16),
              Text(asset.formattedBalance,
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 28,
                      fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(currency.formatAmount(asset.balanceInUsd),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isUp ? AppColors.positive : AppColors.negative).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: isUp ? AppColors.positive : AppColors.negative, size: 13),
                    const SizedBox(width: 3),
                    Text(asset.formattedPriceChange,
                        style: TextStyle(
                            color: isUp ? AppColors.positive : AppColors.negative,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(width: 8),
                Text('${currency.formatPrice(asset.priceUsd)} per ${asset.symbol}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ]),
          ),

          // ── Price Chart ──────────────────────────────────────────────────
          TokenPriceChartWidget(symbol: asset.symbol),
          const SizedBox(height: 16),

          // ── Action buttons ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _ActionBtn(label: 'Send', icon: Icons.arrow_upward_rounded,
                  onTap: () { context.pushModal(SendScreen(assets: [asset])); }),
              const SizedBox(width: 12),
              _ActionBtn(label: 'Receive', icon: Icons.arrow_downward_rounded,
                  onTap: () { context.pushModal(ReceiveScreen(preselectedAsset: asset)); }),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Collapsible Details ───────────────────────────────────────────
          CollapsibleDetails(
            asset: asset,
            expanded: _detailsExpanded,
            onToggle: () { setState(() => _detailsExpanded = !_detailsExpanded); },
            onCopyAddress: () {
              Clipboard.setData(ClipboardData(text: asset.contractAddress));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied')));
            },
          ),

          const SizedBox(height: 8),

          // ── Transactions ──────────────────────────────────────────────────
          if (_hasHistory(asset.blockchain)) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(children: [
                Text('Transactions',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_txLoading)
                  SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 1.5)),
              ]),
            ),
            if (_txLoading && _txRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
              )
            else if (_txError != null)
              _EmptyState(
                icon: _txError == 'no_internet'
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                title: _txError == 'no_internet'
                    ? 'No internet connection'
                    : 'Failed to load',
                subtitle: _txError == 'no_internet'
                    ? 'Transaction history requires an internet connection.'
                    : _txError!,
              )
            else if (_txFetched && _txRecords.isEmpty)
              const _EmptyState(icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                  subtitle: 'Transactions will appear here once confirmed.')
            else
              ...(_txRecords.map((tx) => TransactionTile(tx: tx, asset: asset))),
          ],

          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

// ─── Collapsible Details section ──────────────────────────────────────────────

// ─── Transaction tile ─────────────────────────────────────────────────────────

// ─── Empty / error state ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
    child: Column(children: [
      Icon(icon, color: AppColors.textTertiary, size: 48),
      const SizedBox(height: 12),
      Text(title,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]),
  );
}

// ─── Action button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: AnimatedTap(
      onTap: onTap,
      pressScale: 0.92,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              spreadRadius: 0,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.textPrimary, size: 20),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(
              color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    ),
  );
}

// ─── Info row ──────────────────────────────────────────────────────────────────

