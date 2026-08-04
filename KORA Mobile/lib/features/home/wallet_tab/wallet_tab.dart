import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/features/add_token/add_token_screen.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/features/asset_detail/asset_detail_screen.dart';
import 'package:kora/core/constants/token_catalog.dart';
import 'package:kora/core/services/storage_service.dart';
import 'package:kora/core/services/balance_service.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/state/providers/price_chart_provider.dart';
import 'package:kora/features/home/wallet_tab/asset_sort.dart';
import 'package:kora/features/home/widgets/balance_header.dart';
import 'package:kora/features/home/widgets/action_row.dart';
import 'package:kora/features/home/wallet_tab/asset_tile.dart';
import 'package:kora/features/home/wallet_tab/empty_assets.dart';
import 'package:kora/features/home/widgets/migration_banner.dart';

// The wallet tab: header, action shortcuts and the asset list, with pull-to-refresh.

class WalletTab extends ConsumerStatefulWidget {
  const WalletTab({super.key, required this.balanceVisible, required this.onToggleBalance});
  final bool balanceVisible;
  final VoidCallback onToggleBalance;

  @override
  ConsumerState<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends ConsumerState<WalletTab> with ThemeAwareMixin {
  SortMode _sortMode = SortMode.popularity;

  @override
  void initState() {
    super.initState();
    // Start background prefetch of price charts for all tokens
    PriceChartPrefetchManager.instance.init(ref);
    StorageService.readString('asset_sort_mode').then((saved) {
      if (saved != null && mounted) {
        final mode = SortMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => SortMode.popularity,
        );
        if (mode != _sortMode) setState(() => _sortMode = mode);
      }
    });
  }

  List<Asset> _sorted(List<Asset> raw) {
    final list = List<Asset>.from(raw);
    switch (_sortMode) {
      case SortMode.popularity:
        list.sort((a, b) {
          final aI = allCatalogTokens.indexWhere((t) => t.id == a.id);
          final bI = allCatalogTokens.indexWhere((t) => t.id == b.id);
          final ai = aI < 0 ? 9999 : aI;
          final bi = bI < 0 ? 9999 : bI;
          return ai.compareTo(bi);
        });
      case SortMode.totalValue:
        list.sort((a, b) => b.balanceInUsd.compareTo(a.balanceInUsd));
      case SortMode.quantity:
        list.sort((a, b) {
          final aQ = double.tryParse(a.balance) ?? 0;
          final bQ = double.tryParse(b.balance) ?? 0;
          return bQ.compareTo(aQ);
        });
      case SortMode.price:
        list.sort((a, b) => b.priceUsd.compareTo(a.priceUsd));
    }
    return list;
  }

  void _showSortSheet() {
    showModalBottomSheet<SortMode>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.zero)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Sort assets',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            SortOption(
              icon: Icons.star_outline_rounded,
              label: 'By popularity',
              subtitle: 'BTC first, then ETH, SOL…',
              selected: _sortMode == SortMode.popularity,
              onTap: () { Navigator.pop(sheetCtx, SortMode.popularity); },
            ),
            SortOption(
              icon: Icons.account_balance_wallet_outlined,
              label: 'By portfolio value',
              subtitle: 'Highest USD value in wallet on top',
              selected: _sortMode == SortMode.totalValue,
              onTap: () { Navigator.pop(sheetCtx, SortMode.totalValue); },
            ),
            SortOption(
              icon: Icons.format_list_numbered_rounded,
              label: 'By quantity',
              subtitle: 'Most token units on top',
              selected: _sortMode == SortMode.quantity,
              onTap: () { Navigator.pop(sheetCtx, SortMode.quantity); },
            ),
            SortOption(
              icon: Icons.trending_up_rounded,
              label: 'By coin price',
              subtitle: 'Most expensive coin on top',
              selected: _sortMode == SortMode.price,
              onTap: () { Navigator.pop(sheetCtx, SortMode.price); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).then((selected) {
      if (selected != null && mounted) {
        setState(() => _sortMode = selected);
        StorageService.writeString('asset_sort_mode', selected.name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(currentWalletProvider);
    final currency    = ref.watch(currencyProvider);

    return walletAsync.when(
      loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.textPrimary, strokeWidth: 1.5)),
      error: (e, _) => Center(
          child: Text('Error: $e', style: TextStyle(color: Colors.red))),
      data: (wallet) {
        final allAssets  = wallet?.assets ?? [];
        final assets     = allAssets.where((a) => a.isVisible).toList();
        final sorted     = _sorted(assets);
        // Total portfolio = ALL assets, regardless of isVisible flag
        final totalUsd   = allAssets.fold<double>(0, (s, a) => s + a.balanceInUsd);
        // Weighted 24h change by USD value (not arithmetic mean)
        final totalChange = totalUsd <= 0 ? 0.0
            : allAssets.fold<double>(0, (s, a) => s + a.priceChange24h * a.balanceInUsd) / totalUsd;

        return RefreshIndicator(
          color: AppColors.textPrimary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            BalanceService.invalidateAll();
            await ref.read(currentWalletProvider.notifier).refreshBalances();
          },
          child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: BalanceHeader(
              walletName: wallet?.name ?? 'My Wallet',
              totalUsd: totalUsd,
              change24h: totalChange,
              visible: widget.balanceVisible,
              onToggleVisibility: widget.onToggleBalance,
              currency: currency,
            )),
            SliverToBoxAdapter(child: ActionRow(assets: assets)),
            SliverToBoxAdapter(child: MigrationBanner(assets: assets)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('ASSETS',
                        style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.18)),
                    const Spacer(),
                    // The aside is the sort control; when a sort other than the default is
                    // active it brightens, which is the whole of its active state.
                    AnimatedTap(
                      onTap: () { _showSortSheet(); },
                      child: Text('${sorted.length} POSITIONS · SORT',
                          style: kLabel(
                              _sortMode != SortMode.popularity
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                              size: 9.5, tracking: 0.1)),
                    ),
                    const SizedBox(width: 14),
                    AnimatedTap(
                      onTap: () { context.pushSlide(const AddTokenScreen()); },
                      child: Text('+ ADD',
                          style: kLabel(AppColors.textTertiary, size: 9.5, tracking: 0.1)),
                    ),
                  ],
                ),
              ),
            ),
            if (sorted.isEmpty)
              SliverFillRemaining(child: EmptyAssets())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => AssetTile(
                    asset: sorted[i],
                    visible: widget.balanceVisible,
                    currency: currency,
                    onTap: () { context.pushSlide(AssetDetailScreen(asset: sorted[i])); },
                  ),
                  childCount: sorted.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
          ),
        );
      },
    );
  }
}
