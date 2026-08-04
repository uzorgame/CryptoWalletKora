import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/widgets/kora_mark.dart';
import 'package:kora/core/widgets/kora_mask.dart';
import 'package:kora/features/home/wallet_switcher/wallet_switcher_sheet.dart';

// The wallet's name, total value and 24h move. Tapping the name opens the wallet switcher.
//
// Left-aligned, unlike the old centred header: the desktop wallet leads from the left edge,
// and the approved prototype keeps that on the phone.
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
    final sign = isUp ? '+' : '−';

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const KoraMark(size: 30),
            const SizedBox(width: 12),
            AnimatedTap(
              onTap: multiWallet
                  ? () { _showWalletSwitcher(context, ref); }
                  : null,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(walletName.toUpperCase(),
                    style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.14)),
                if (multiWallet) ...[
                  const SizedBox(width: 7),
                  Text('▾', style: kLabel(AppColors.textSecondary, size: 9)),
                ],
              ]),
            ),
            const Spacer(),
            ListenableBuilder(
              listenable: ThemeNotifier.instance,
              builder: (context, _) => _SquareButton(
                onTap: () { ThemeNotifier.instance.toggleTheme(); },
                icon: ThemeNotifier.instance.isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
            const SizedBox(width: 8),
            _SquareButton(
              onTap: onToggleVisibility,
              icon: visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            ),
          ]),
          const SizedBox(height: 26),
          Text('TOTAL BALANCE',
              style: kLabel(AppColors.textTertiary, size: 9.5, tracking: 0.16)),
          const SizedBox(height: 8),
          AnimatedTap(
            onTap: onToggleVisibility,
            pressScale: 0.97,
            pressOpacity: 0.85,
            child: visible
                ? Text(currency.formatTotal(totalUsd),
                    style: kNum(AppColors.textPrimary, size: 40))
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: KoraMask(count: 6, size: 13),
                  ),
          ),
          const SizedBox(height: 8),
          Text('$sign${change24h.abs().toStringAsFixed(2)}% · 24H',
              style: kLabel(isUp ? AppColors.positive : AppColors.negative,
                  size: 11, tracking: 0.08, weight: FontWeight.w400)),
        ],
      ),
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

/// A hairline square holding one small control — the theme and eye toggles.
class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.onTap, required this.icon});
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.9,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(border: kHairline()),
        child: Icon(icon, color: AppColors.textSecondary, size: 15),
      ),
    );
  }
}
