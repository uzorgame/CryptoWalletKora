import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/widgets/animated_tap.dart';
import 'package:kora/features/home/wallet_switcher/wallet_switcher_sheet.dart';

// The wallet's name, total value and 24h move. Tapping the name opens the wallet switcher.

class BalanceHeader extends ConsumerWidget {
  const BalanceHeader({super.key, required this.walletName, required this.totalUsd,
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
      builder: (_) => const WalletSwitcherSheet(),
    );
  }
}
