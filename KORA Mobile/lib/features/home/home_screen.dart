import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/core/widgets/coin_icon.dart';
import 'package:kora/core/models/wallet.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/state/providers/asset_provider.dart';
import 'package:kora/features/add_token/add_token_screen.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/features/asset_detail/asset_detail_screen.dart';
import 'package:kora/features/receive/receive_picker_screen.dart';
import 'package:kora/features/receive/receive_screen.dart';
import 'package:kora/features/send/send_screen.dart';
import 'package:kora/features/settings/settings_screen.dart';
import 'package:kora/features/onboarding/create_wallet_screen.dart';
import 'package:kora/features/onboarding/import_wallet_screen.dart';
import 'package:kora/features/scan/qr_scanner_screen.dart';
import 'package:kora/core/constants/token_catalog.dart';
import 'package:kora/core/services/storage_service.dart';
import 'package:kora/core/services/balance_service.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/core/widgets/animated_tap.dart';
import 'package:kora/core/state/providers/price_chart_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with ThemeAwareMixin {
  int _tab = 0;
  bool _balanceVisible = true;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: _tab == 0
              ? _WalletTab(
                  key: const ValueKey(0),
                  balanceVisible: _balanceVisible,
                  onToggleBalance: () => setState(() => _balanceVisible = !_balanceVisible),
                )
              : const _SettingsTab(key: ValueKey(1)),
        ),
        bottomNavigationBar: _BottomNav(current: _tab,
            onTap: (i) => setState(() => _tab = i)),
      ),
    );
  }
}

// ─── Bottom Navigation ────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.separator, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Consumer(
            builder: (context, ref, _) {
              final assets = ref.watch(assetsProvider);
              return Row(children: [
                _NavItem(icon: Icons.account_balance_wallet_outlined,
                    activeIcon: Icons.account_balance_wallet_rounded,
                    label: 'Wallet', active: current == 0, onTap: () { debugPrint('[TAP] BottomNav: Wallet (home_screen.dart)'); onTap(0); }),
                _NavItem(icon: Icons.arrow_upward_rounded,
                    activeIcon: Icons.arrow_upward_rounded,
                    label: 'Send', active: false, onTap: () { 
                      debugPrint('[TAP] BottomNav: Send (home_screen.dart)'); 
                      context.pushFade(SendScreen(assets: assets));
                    }),
                _NavItem(icon: Icons.arrow_downward_rounded,
                    activeIcon: Icons.arrow_downward_rounded,
                    label: 'Receive', active: false, onTap: () { 
                      debugPrint('[TAP] BottomNav: Receive (home_screen.dart)'); 
                      _openReceivePicker(context, assets);
                    }),
                _NavItem(icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    label: 'Settings', active: current == 1, onTap: () { debugPrint('[TAP] BottomNav: Settings (home_screen.dart)'); onTap(1); }),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  _NavItem({required this.icon, required this.activeIcon,
      required this.label, required this.active, required this.onTap});
  final IconData icon, activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedTap(
        onTap: onTap,
        pressScale: 0.88,
        pressOpacity: 0.6,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon,
                color: active ? AppColors.textPrimary : AppColors.textTertiary,
                size: 22),
            SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                  color: active ? AppColors.textPrimary : AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Sort mode ────────────────────────────────────────────────────────────────

enum _SortMode { popularity, totalValue, quantity, price }

// ─── Wallet Tab ───────────────────────────────────────────────────────────────

class _WalletTab extends ConsumerStatefulWidget {
  const _WalletTab({super.key, required this.balanceVisible, required this.onToggleBalance});
  final bool balanceVisible;
  final VoidCallback onToggleBalance;

  @override
  ConsumerState<_WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends ConsumerState<_WalletTab> with ThemeAwareMixin {
  _SortMode _sortMode = _SortMode.popularity;

  @override
  void initState() {
    super.initState();
    // Start background prefetch of price charts for all tokens
    PriceChartPrefetchManager.instance.init(ref);
    StorageService.readString('asset_sort_mode').then((saved) {
      if (saved != null && mounted) {
        final mode = _SortMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => _SortMode.popularity,
        );
        if (mode != _sortMode) setState(() => _sortMode = mode);
      }
    });
  }

  List<Asset> _sorted(List<Asset> raw) {
    final list = List<Asset>.from(raw);
    switch (_sortMode) {
      case _SortMode.popularity:
        list.sort((a, b) {
          final aI = allCatalogTokens.indexWhere((t) => t.id == a.id);
          final bI = allCatalogTokens.indexWhere((t) => t.id == b.id);
          final ai = aI < 0 ? 9999 : aI;
          final bi = bI < 0 ? 9999 : bI;
          return ai.compareTo(bi);
        });
      case _SortMode.totalValue:
        list.sort((a, b) => b.balanceInUsd.compareTo(a.balanceInUsd));
      case _SortMode.quantity:
        list.sort((a, b) {
          final aQ = double.tryParse(a.balance) ?? 0;
          final bQ = double.tryParse(b.balance) ?? 0;
          return bQ.compareTo(aQ);
        });
      case _SortMode.price:
        list.sort((a, b) => b.priceUsd.compareTo(a.priceUsd));
    }
    return list;
  }

  void _showSortSheet() {
    showModalBottomSheet<_SortMode>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Sort assets',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            _SortOption(
              icon: Icons.star_outline_rounded,
              label: 'By popularity',
              subtitle: 'BTC first, then ETH, SOL…',
              selected: _sortMode == _SortMode.popularity,
              onTap: () { debugPrint('[TAP] Sort: By popularity (home_screen.dart)'); Navigator.pop(sheetCtx, _SortMode.popularity); },
            ),
            _SortOption(
              icon: Icons.account_balance_wallet_outlined,
              label: 'By portfolio value',
              subtitle: 'Highest USD value in wallet on top',
              selected: _sortMode == _SortMode.totalValue,
              onTap: () { debugPrint('[TAP] Sort: By portfolio value (home_screen.dart)'); Navigator.pop(sheetCtx, _SortMode.totalValue); },
            ),
            _SortOption(
              icon: Icons.format_list_numbered_rounded,
              label: 'By quantity',
              subtitle: 'Most token units on top',
              selected: _sortMode == _SortMode.quantity,
              onTap: () { debugPrint('[TAP] Sort: By quantity (home_screen.dart)'); Navigator.pop(sheetCtx, _SortMode.quantity); },
            ),
            _SortOption(
              icon: Icons.trending_up_rounded,
              label: 'By coin price',
              subtitle: 'Most expensive coin on top',
              selected: _sortMode == _SortMode.price,
              onTap: () { debugPrint('[TAP] Sort: By coin price (home_screen.dart)'); Navigator.pop(sheetCtx, _SortMode.price); },
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
            debugPrint('[TAP] PullToRefresh (home_screen.dart)');
            BalanceService.invalidateAll();
            await ref.read(currentWalletProvider.notifier).refreshBalances();
          },
          child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(
              walletName: wallet?.name ?? 'My Wallet',
              totalUsd: totalUsd,
              change24h: totalChange,
              visible: widget.balanceVisible,
              onToggleVisibility: widget.onToggleBalance,
              currency: currency,
            )),
            SliverToBoxAdapter(child: _ActionRow(assets: assets)),
            SliverToBoxAdapter(child: _MigrationBanner(assets: assets)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Assets',
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    // Sort button
                    AnimatedTap(
                      onTap: () { debugPrint('[TAP] Sort Assets button (home_screen.dart)'); _showSortSheet(); },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _sortMode != _SortMode.popularity
                            ? AppColors.cardElevated
                            : AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _sortMode != _SortMode.popularity
                                  ? AppColors.textPrimary.withValues(alpha: 0.3)
                                  : AppColors.border,
                              width: _sortMode != _SortMode.popularity ? 1.0 : 0.5),
                        ),
                        child: Icon(Icons.sort_rounded,
                            color: _sortMode != _SortMode.popularity
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add token button
                    AnimatedTap(
                      onTap: () { debugPrint('[TAP] Add Token button (home_screen.dart)'); context.pushSlide(const AddTokenScreen()); },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.border, width: 0.5),
                        ),
                        child: Icon(Icons.add_rounded,
                            color: AppColors.textSecondary, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (sorted.isEmpty)
              SliverFillRemaining(child: _EmptyAssets())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _AssetTile(
                    asset: sorted[i],
                    visible: widget.balanceVisible,
                    currency: currency,
                    onTap: () { debugPrint('[TAP] Asset tile: ${sorted[i].symbol} / ${sorted[i].blockchain} (home_screen.dart)'); context.pushSlide(AssetDetailScreen(asset: sorted[i])); },
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

// ─── Sort option tile ─────────────────────────────────────────────────────────

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.icon, required this.label, required this.subtitle,
    required this.selected, required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.97,
      child: ListTile(
        leading: Icon(icon,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary, size: 22),
        title: Text(label,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 15)),
        subtitle: Text(subtitle,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        trailing: selected
            ? Icon(Icons.check_rounded, color: AppColors.textPrimary, size: 20)
            : null,
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.walletName, required this.totalUsd,
      required this.change24h, required this.visible, required this.onToggleVisibility,
      required this.currency});
  final String walletName;
  final double totalUsd, change24h;
  final bool visible;
  final VoidCallback onToggleVisibility;
  final CurrencyState currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUp = change24h >= 0;
    final allWallets = ref.watch(allWalletsProvider);
    final multiWallet = allWallets.value != null && allWallets.value!.length > 1;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: AppColors.textPrimary),
            child: Icon(Icons.person_rounded, color: AppColors.background, size: 18),
          ),
          SizedBox(width: 10),
          AnimatedTap(
            onTap: multiWallet
                ? () { debugPrint('[TAP] Wallet name (open switcher) (home_screen.dart)'); _showWalletSwitcher(context, ref); }
                : null,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(walletName,
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              if (multiWallet) ...[
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary, size: 18),
              ],
            ]),
          ),
          const Spacer(),
          ListenableBuilder(
            listenable: ThemeNotifier.instance,
            builder: (context, _) => AnimatedTap(
              onTap: () {
                debugPrint('[TAP] Toggle theme (home_screen.dart)');
                ThemeNotifier.instance.toggleTheme();
              },
              child: Icon(
                ThemeNotifier.instance.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          AnimatedTap(
            onTap: () { debugPrint('[TAP] Toggle balance visibility (home_screen.dart)'); onToggleVisibility(); },
            child: Icon(
              visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AppColors.textSecondary, size: 20),
          ),
        ]),
        const SizedBox(height: 28),
        AnimatedTap(
          onTap: onToggleVisibility,
          pressScale: 0.96,
          pressOpacity: 0.85,
          child: Text(
            visible ? currency.formatTotal(totalUsd) : '••••••',
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 42, fontWeight: FontWeight.w700,
                letterSpacing: -1.5),
          ),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isUp ? AppColors.positive : AppColors.negative).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isUp ? AppColors.positive : AppColors.negative, size: 12),
              const SizedBox(width: 3),
              Text('${change24h.abs().toStringAsFixed(2)}% today',
                  style: TextStyle(
                    color: isUp ? AppColors.positive : AppColors.negative,
                    fontSize: 13, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      ]),
    );
  }

  void _showWalletSwitcher(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _WalletSwitcherSheet(),
    );
  }
}

// ─── Wallet Switcher Sheet ────────────────────────────────────────────────────

class _WalletSwitcherSheet extends ConsumerStatefulWidget {
  const _WalletSwitcherSheet();

  @override
  ConsumerState<_WalletSwitcherSheet> createState() => _WalletSwitcherSheetState();
}

const int _kMaxWallets = 5;

class _WalletSwitcherSheetState extends ConsumerState<_WalletSwitcherSheet> with ThemeAwareMixin {
  void _onAddWallet(int currentCount) {
    if (currentCount >= _kMaxWallets) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum of $_kMaxWallets wallets reached'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pop(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _AddWalletSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allWallets = ref.watch(allWalletsProvider);
    final currentWallet = ref.watch(currentWalletProvider).value;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My Wallets',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  allWallets.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (wallets) {
                      final atLimit = wallets.length >= _kMaxWallets;
                      return AnimatedTap(
                        onTap: () => _onAddWallet(wallets.length),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: atLimit ? AppColors.cardElevated : AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_rounded,
                                color: atLimit ? AppColors.textTertiary : AppColors.textPrimary,
                                size: 16),
                            const SizedBox(width: 4),
                            Text(
                              atLimit ? '${wallets.length}/$_kMaxWallets' : 'Add',
                              style: TextStyle(
                                  color: atLimit ? AppColors.textTertiary : AppColors.textPrimary,
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            allWallets.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 1.5),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (wallets) => ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: wallets.length,
                itemBuilder: (_, i) {
                  final w = wallets[i];
                  final isActive = w.id == currentWallet?.id;
                  return AnimatedTap(
                    onTap: isActive ? null : () async {
                      debugPrint('[TAP] Switch wallet: ${w.name} (${w.id}) (home_screen.dart)');
                      Navigator.pop(context);
                      await ref.read(currentWalletProvider.notifier).switchWallet(w.id);
                    },
                    pressScale: 0.97,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.cardElevated
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isActive
                              ? AppColors.textPrimary.withValues(alpha: 0.3)
                              : AppColors.border,
                          width: isActive ? 1.0 : 0.5,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? AppColors.textPrimary : AppColors.cardElevated),
                          child: Icon(Icons.account_balance_wallet_rounded,
                              color: isActive ? AppColors.background : AppColors.textSecondary,
                              size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.name,
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(w.type.displayName,
                                    style: TextStyle(
                                        color: AppColors.textSecondary, fontSize: 12)),
                              ]),
                        ),
                        if (isActive)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Active',
                                style: TextStyle(
                                    color: AppColors.textPrimary, fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        // Rename button
                        AnimatedTap(
                          onTap: () { debugPrint('[TAP] Rename wallet: ${w.name} (home_screen.dart)'); _showRenameDialog(w.id, w.name); },
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border, width: 0.5),
                            ),
                            child: Icon(Icons.edit_rounded,
                                color: AppColors.textTertiary, size: 15),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(String walletId, String currentName) async {
    String nameValue = currentName;
    bool confirmed = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename Wallet',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: TextFormField(
          initialValue: currentName,
          autofocus: true,
          maxLength: 32,
          style: TextStyle(color: AppColors.textPrimary),
          onChanged: (v) => nameValue = v,
          onFieldSubmitted: (_) {
            confirmed = true;
            Navigator.of(ctx).pop();
          },
          decoration: InputDecoration(
            hintText: 'Wallet name',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            counterStyle: TextStyle(color: AppColors.textTertiary),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.accent, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              confirmed = true;
              Navigator.of(ctx).pop();
            },
            child: Text('Save',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    debugPrint('[Rename] confirmed=$confirmed nameValue="$nameValue" mounted=$mounted');
    if (!confirmed || nameValue.trim().isEmpty || !mounted) {
      debugPrint('[Rename] Skipped: confirmed=$confirmed empty=${nameValue.trim().isEmpty} unmounted=${!mounted}');
      return;
    }
    Navigator.of(context).pop(); // close sheet
    // Wait for both dialog + sheet dismiss animations before triggering
    // provider updates — otherwise _dependents.isEmpty assertion fires.
    await Future.delayed(const Duration(milliseconds: 350));
    debugPrint('[Rename] Calling renameWallet($walletId, "${nameValue.trim()}")');
    if (mounted) {
      await ref
          .read(currentWalletProvider.notifier)
          .renameWallet(walletId, nameValue.trim());
      debugPrint('[Rename] Done');
    } else {
      debugPrint('[Rename] unmounted after delay — skipped renameWallet');
    }
  }
}

// ─── Add Wallet Sheet ─────────────────────────────────────────────────────────

class _AddWalletSheet extends StatelessWidget {
  const _AddWalletSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Add Wallet',
              style: TextStyle(
                color: AppColors.textPrimary, fontSize: 17,
                fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Create a brand-new wallet or restore one from a recovery phrase.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              _AddWalletOption(
                icon: Icons.add_circle_outline_rounded,
                title: 'Create New Wallet',
                subtitle: 'Generate a fresh wallet with a new recovery phrase',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateWalletScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _AddWalletOption(
                icon: Icons.file_download_outlined,
                title: 'Import Existing Wallet',
                subtitle: 'Restore a wallet using your 12-word recovery phrase',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ImportWalletScreen(),
                    ),
                  );
                },
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AddWalletOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AddWalletOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary, size: 20),
        ]),
      ),
    );
  }
}

// ─── Action Buttons ───────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.assets});
  final List<Asset> assets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        _ActionBtn(label: 'Send', icon: Icons.arrow_upward_rounded,
            onTap: () { debugPrint('[TAP] Action: Send (home_screen.dart)'); context.pushModal(SendScreen(assets: assets)); }),
        const SizedBox(width: 12),
        _ActionBtn(label: 'Receive', icon: Icons.arrow_downward_rounded,
            onTap: () { debugPrint('[TAP] Action: Receive (home_screen.dart)'); _openReceivePicker(context, assets); }),
        const SizedBox(width: 12),
        _ActionBtn(label: 'Scan', icon: Icons.qr_code_scanner_rounded,
            onTap: () async { debugPrint('[TAP] Action: Scan QR (home_screen.dart)');
              final addr = await context.pushModal<String>(const QrScannerScreen());
              if (addr != null && addr.isNotEmpty && context.mounted) {
                context.pushModal(SendScreen(
                      assets: assets,
                      initialAddress: addr,
                    ));
              }
            }),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedTap(
        onTap: onTap,
        pressScale: 0.92,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(children: [
            Icon(icon, color: AppColors.textPrimary, size: 22),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

// ─── Receive asset picker ─────────────────────────────────────────────────────

void _openReceivePicker(BuildContext context, List<Asset> assets) {
  if (assets.isEmpty) return;
  if (assets.length == 1) {
    context.pushModal(ReceiveScreen(preselectedAsset: assets.first));
    return;
  }
  context.pushModal(ReceivePickerScreen(assets: assets));
}

// ─── Asset Tile ───────────────────────────────────────────────────────────────

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset, required this.visible,
      required this.currency, required this.onTap});
  final Asset asset;
  final bool visible;
  final CurrencyState currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.97,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(children: [
            CoinIcon(symbol: asset.symbol, iconUrl: asset.iconUrl, size: 40),
            const SizedBox(width: 12),
            // Symbol + network badge on same row, price per unit below
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(asset.symbol,
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_networkLabel(asset.blockchain),
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w500)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(visible ? currency.formatPrice(asset.priceUsd) : '••••',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ),
            // Balance quantity + total value
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(visible ? _formatAmount(asset.balanceAsDouble) : '••••',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(visible ? currency.formatPrice(asset.balanceInUsd) : '••••',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ]),
        ),
      ),
    );
  }

  static String _formatAmount(double value) {
    if (value == 0) return '0';
    if (value < 0.000001) return '< 0.000001';
    if (value >= 1000000) return value.toStringAsFixed(0);
    if (value >= 1000) return value.toStringAsFixed(2);
    final s = value.toStringAsFixed(6);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _networkLabel(String blockchain) {
    const labels = <String, String>{
      'bitcoin':          'Bitcoin',
      'ethereum':         'Ethereum',
      'solana':           'Solana',
      'bsc':              'BNB Smart Chain',
      'tron':             'Tron',
      'litecoin':         'Litecoin',
      'bitcoin_cash':     'Bitcoin Cash',
      'ethereum_classic': 'ETC',
    };
    return labels[blockchain] ?? blockchain;
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyAssets extends StatelessWidget {
  const _EmptyAssets();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              color: AppColors.textTertiary, size: 48),
          SizedBox(height: 12),
          Text('No assets yet',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          SizedBox(height: 4),
          Text('Create or import a wallet to get started',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Settings Tab (stub) ─────────────────────────────────────────────────────

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}

// ─── Migration Banner ──────────────────────────────────────────────────────────────────────────────

class _MigrationBanner extends ConsumerStatefulWidget {
  const _MigrationBanner({required this.assets});
  final List<Asset> assets;
  @override
  ConsumerState<_MigrationBanner> createState() => _MigrationBannerState();
}

class _MigrationBannerState extends ConsumerState<_MigrationBanner> with ThemeAwareMixin {
  bool _dismissed = false;
  bool _autoDialogShown = false;

  bool _needsAddressFix() {
    const utxoWrong = {'litecoin'};
    return widget.assets.any((a) =>
        (utxoWrong.contains(a.blockchain) && a.contractAddress.startsWith('0x')) ||
        false);
  }

  bool _needsMigration() => _needsAddressFix() || ref.watch(needsMigrationPinProvider);

  void _showPinDialog() {
    final pinCtrl  = TextEditingController();
    String? errMsg;
    bool    obscure = true;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('Re-derive Addresses',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Enter your wallet PIN to re-derive correct addresses for LTC.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: obscure,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textPrimary, letterSpacing: 4),
              decoration: InputDecoration(
                hintText: '• • • • • •',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                errorText: errMsg,
                errorStyle: TextStyle(color: AppColors.negative, fontSize: 11),
                filled: true, fillColor: AppColors.background,
                border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.textSecondary)),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textTertiary, size: 18),
                  onPressed: () => setS(() => obscure = !obscure),
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final pin = pinCtrl.text.trim();
                final ok  = await ref.read(currentWalletProvider.notifier)
                    .refreshWalletAddresses(pin);
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.of(ctx).pop();
                  if (mounted) setState(() => _dismissed = true);
                } else {
                  setS(() => errMsg = 'Incorrect PIN');
                }
              },
              child: Text('Update', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsFullMigration = ref.watch(needsMigrationPinProvider);
    // Auto-show PIN dialog once when full migration requires the real PIN
    if (needsFullMigration && !_autoDialogShown) {
      _autoDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPinDialog();
      });
    }
    if (_dismissed || !_needsMigration()) return const SizedBox.shrink();
    final label = needsFullMigration
        ? 'Wallet initialisation requires your PIN.'
        : 'LTC addresses need to be updated.';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(children: [
        Icon(Icons.update_rounded, color: AppColors.warning, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.warning, fontSize: 12),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedTap(
          onTap: _showPinDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Fix', style: TextStyle(color: AppColors.warning,
                fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedTap(
          onTap: () => setState(() => _dismissed = true),
          child: Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 16),
        ),
      ]),
    );
  }
}
