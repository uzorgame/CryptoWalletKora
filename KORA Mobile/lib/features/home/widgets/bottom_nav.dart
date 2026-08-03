import 'package:flutter/material.dart';
import 'package:kora/features/receive/open_receive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/state/providers/asset_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/features/send/send_screen.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/core/widgets/animated_tap.dart';

// The home shell's bottom navigation bar.

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.current, required this.onTap});
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
                      openReceivePicker(context, assets);
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
