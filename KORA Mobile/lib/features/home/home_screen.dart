import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/state/providers/asset_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/features/receive/receive_picker_screen.dart';
import 'package:kora/features/send/send_screen.dart';
import 'package:kora/features/settings/settings_screen.dart';
import 'package:kora/features/home/widgets/bottom_nav.dart';
import 'package:kora/features/home/wallet_tab/wallet_tab.dart';

// The shell: four living tabs under one permanent bar. Wallet, Send, Receive and Settings
// are all held in an IndexedStack, so hopping between them is instant — the prototype's
// go() — and each keeps its state: a half-typed send survives a glance at the wallet.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with ThemeAwareMixin {
  int _tab = 0;
  bool _balanceVisible = true;

  /// An address the scanner produced while another tab was frontmost. Handed to the send
  /// tab on the way in, then cleared — it is a message, not state.
  String? _pendingSendAddress;

  void _goTab(int i, {String? sendAddress}) {
    setState(() {
      if (sendAddress != null) _pendingSendAddress = sendAddress;
      _tab = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(assetsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _tab,
          children: [
            WalletTab(
              balanceVisible: _balanceVisible,
              onToggleBalance: () =>
                  setState(() => _balanceVisible = !_balanceVisible),
              onOpenSend: () => _goTab(1),
              onOpenReceive: () => _goTab(2),
              onScanned: (addr) => _goTab(1, sendAddress: addr),
            ),
            SendScreen(
              assets: assets,
              embedded: true,
              initialAddress: _pendingSendAddress,
              onExit: () => _goTab(0),
            ),
            ReceivePickerScreen(
              assets: assets,
              embedded: true,
              onExit: () => _goTab(0),
            ),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: BottomNav(current: _tab, onTap: (i) => _goTab(i)),
      ),
    );
  }
}
