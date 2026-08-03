import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/features/settings/settings_screen.dart';
import 'package:kora/features/home/widgets/bottom_nav.dart';
import 'package:kora/features/home/wallet_tab/wallet_tab.dart';

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
              ? WalletTab(
                  key: const ValueKey(0),
                  balanceVisible: _balanceVisible,
                  onToggleBalance: () => setState(() => _balanceVisible = !_balanceVisible),
                )
              : const _SettingsTab(key: ValueKey(1)),
        ),
        bottomNavigationBar: BottomNav(current: _tab,
            onTap: (i) => setState(() => _tab = i)),
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

