import 'package:flutter/material.dart';

import '../../core/models/wallet.dart';
import '../../core/theme/kora_design.dart';
import '../format/money.dart';

/// The wallet in use, and the way to change it.
///
/// Labelled for what it does rather than for what is open: which wallet is active is stated
/// on the portfolio itself, beside the balance it explains.
class WalletSwitcher extends StatefulWidget {
  const WalletSwitcher({
    super.key,
    required this.wallets,
    required this.activeId,
    required this.valueOf,
    required this.currencySymbol,
    required this.onSelect,
    required this.onCreate,
    required this.onLock,
  });

  final List<Wallet> wallets;
  final String? activeId;

  /// Total value of a wallet in the display currency, or null while it is unknown.
  final double? Function(Wallet) valueOf;

  final String currencySymbol;
  final ValueChanged<Wallet> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onLock;

  @override
  State<WalletSwitcher> createState() => _WalletSwitcherState();
}

class _WalletSwitcherState extends State<WalletSwitcher> {
  final _link = LayerLink();
  OverlayEntry? _menu;

  @override
  void didUpdateWidget(WalletSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An overlay is not part of this subtree, so it does not rebuild when the wallet list or
    // its values change. Without this the menu keeps showing the balances it opened with.
    _menu?.markNeedsBuild();
  }

  @override
  void dispose() {
    _menu?.remove();
    _menu = null;
    super.dispose();
  }

  void _closeMenu() {
    _menu?.remove();
    _menu = null;
  }

  void _toggleMenu() {
    if (_menu != null) {
      setState(_closeMenu);
      return;
    }
    _menu = OverlayEntry(builder: _buildMenu);
    Overlay.of(context).insert(_menu!);
    setState(() {});
  }

  Widget _buildMenu(BuildContext context) {
    final p = Kora.of(this.context);
    return Stack(
      children: [
        // A full-screen catcher, so clicking anywhere else dismisses the menu.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(_closeMenu),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(8, -8),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: kRailWidth - 16,
              decoration: BoxDecoration(color: p.bg, border: Border.all(color: p.border)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final wallet in widget.wallets)
                    _MenuRow(
                      title: wallet.name,
                      subtitle: money(widget.valueOf(wallet), widget.currencySymbol),
                      active: wallet.id == widget.activeId,
                      onTap: () {
                        setState(_closeMenu);
                        widget.onSelect(wallet);
                      },
                    ),
                  _MenuRow(
                    title: '+ NEW WALLET',
                    active: false,
                    onTap: () {
                      setState(_closeMenu);
                      widget.onCreate();
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: p.border)),
                    ),
                    child: Text(
                      'One passphrase unlocks every wallet in KORA.',
                      style: koraLabel(p.text3, size: 8.5, tracking: 0.08).copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return CompositedTransformTarget(
      link: _link,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: p.border),
          const SizedBox(height: 8),
          _SwitcherButton(open: _menu != null, onTap: _toggleMenu),
          _LockButton(onTap: widget.onLock),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SwitcherButton extends StatefulWidget {
  const _SwitcherButton({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  State<_SwitcherButton> createState() => _SwitcherButtonState();
}

class _SwitcherButtonState extends State<_SwitcherButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: kHover,
          curve: kEase,
          color: _hover ? p.hover : p.hover.withAlpha(0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'WALLET',
                  style: koraLabel(_hover ? p.text : p.text2, size: 10.5, tracking: 0.14),
                ),
              ),
              AnimatedRotation(
                turns: widget.open ? 0.5 : 0,
                duration: kHover,
                curve: kEase,
                child: Icon(Icons.keyboard_arrow_up, size: 14, color: p.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockButton extends StatefulWidget {
  const _LockButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_LockButton> createState() => _LockButtonState();
}

class _LockButtonState extends State<_LockButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Text('—', style: koraLabel(p.text3, size: 9.5)),
              const SizedBox(width: 10),
              Text('LOCK', style: koraLabel(_hover ? p.down : p.text3, size: 10.5, tracking: 0.14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.title,
    this.subtitle,
    required this.active,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        // Animated like every other hoverable row in the app. A plain Container snapped
        // between the two states, so this one row behaved differently from the rail, the
        // tables and the coin list — the kind of inconsistency that reads as unfinished
        // rather than as a decision.
        child: AnimatedContainer(
          duration: kHover,
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: widget.active ? p.selected : (_hover ? p.hover : p.hover.withAlpha(0)),
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: koraLabel(widget.active ? p.text : p.text3, size: 10, tracking: 0.14),
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 3),
                Text(widget.subtitle!, style: koraNumeric(p.text2, size: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
