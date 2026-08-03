import 'package:flutter/material.dart';

import '../../core/models/wallet.dart';
import '../../core/theme/kora_design.dart';
import 'nav_destination.dart';
import 'nav_rail.dart';
import 'stage.dart';
import 'title_bar.dart';
import 'wallet_switcher.dart';

/// The window: title bar across the top, rail down the left, views in the rest.
///
/// It owns navigation and nothing else. Which wallet is open, what a view shows and what any
/// action does are all decided above it and handed in — so this file stays about layout, and
/// stays small.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.wallets,
    required this.activeWalletId,
    required this.walletValue,
    required this.currencySymbol,
    required this.onSelectWallet,
    required this.onCreateWallet,
    required this.onLock,
    required this.onToggleTheme,
    required this.onNavigate,
    required this.views,
  });

  final List<Wallet> wallets;
  final String? activeWalletId;
  final double? Function(Wallet) walletValue;
  final String currencySymbol;

  final ValueChanged<Wallet> onSelectWallet;
  final VoidCallback onCreateWallet;
  final VoidCallback onLock;
  final VoidCallback onToggleTheme;

  /// Where a click on the rail is reported, rather than acted on here.
  ///
  /// The rail used to move `_current` itself, with this state's own setState, which left the
  /// entrance counter that lives above the shell untouched — so the staggered row arrival
  /// replayed on every path into a screen except the rail, which is the path nearly all
  /// navigation takes. Everything that navigates now goes in at the same door and comes back
  /// down as [AppShellState.go].
  final ValueChanged<NavDestination> onNavigate;

  /// One builder per destination. Called at most once each, when first visited.
  final Map<NavDestination, WidgetBuilder> views;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  NavDestination _current = NavDestination.portfolio;

  /// The one place `_current` moves.
  ///
  /// Lets a view send the user somewhere else — the portfolio's coin page opening Send, for
  /// instance — without every view needing to know about the rail. The rail arrives here too,
  /// by way of [AppShell.onNavigate]: a destination and the entrance counter have to move
  /// together, and only the widget above this one holds both.
  void go(NavDestination destination) {
    if (destination == _current) return;
    setState(() => _current = destination);
  }

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          TitleBar(onToggleTheme: widget.onToggleTheme),
          Expanded(
            child: Row(
              children: [
                // The rail repaints on hover and on the marker's travel; the stage beside it
                // has no reason to be dragged into either.
                RepaintBoundary(
                  child: NavRail(
                    current: _current,
                    onSelect: widget.onNavigate,
                    footer: WalletSwitcher(
                      wallets: widget.wallets,
                      activeId: widget.activeWalletId,
                      valueOf: widget.walletValue,
                      currencySymbol: widget.currencySymbol,
                      onSelect: widget.onSelectWallet,
                      onCreate: widget.onCreateWallet,
                      onLock: widget.onLock,
                    ),
                  ),
                ),
                Expanded(
                  child: Stage(current: _current, builders: widget.views),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
