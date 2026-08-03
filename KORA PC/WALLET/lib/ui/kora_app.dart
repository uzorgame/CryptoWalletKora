import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/token_catalog.dart';
import '../core/models/asset.dart';
import '../core/models/wallet.dart';
import '../core/services/theme_notifier.dart';
import '../core/theme/kora_design.dart';
import '../core/state/providers/asset_provider.dart';
import '../core/state/providers/currency_provider.dart';
import '../core/state/providers/wallet_provider.dart';
import 'coin/receive_sheet.dart';
import 'portfolio/token_sheet.dart';
import 'common/kora_sheet.dart';
import 'common/passphrase_gate.dart';
import 'common/wallet_actions.dart';
import 'format/chain_display.dart';
import 'format/currency_format.dart';
import 'format/wallet_total.dart';
import 'screens/coin_screen.dart';
import 'screens/history_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/send_screen.dart';
import 'screens/settings_screen.dart';
import 'shell/app_shell.dart';
import 'shell/nav_destination.dart';

/// The whole wallet, once there is a wallet to show.
///
/// This holds the two pieces of state that belong to no single view: which coin is open, and
/// which asset Send should start on. Everything else each screen reads for itself from the
/// providers, so nothing has to be threaded down through the shell.
class KoraApp extends ConsumerStatefulWidget {
  const KoraApp({super.key, required this.version, required this.onLock});

  final String version;
  final VoidCallback onLock;

  @override
  ConsumerState<KoraApp> createState() => _KoraAppState();
}

class _KoraAppState extends ConsumerState<KoraApp> {
  final _shell = GlobalKey<AppShellState>();

  /// The coin page is shown in the portfolio's slot rather than as a fifth destination: it is
  /// a place you go from the portfolio and come back to it from, not a section of the app.
  Asset? _openCoin;

  /// What Send should open on. Set when the user arrives from a coin page, so they do not
  /// have to pick the coin they were just looking at.
  Asset? _sendAsset;

  /// Bumped on every press of SEND from a coin page.
  ///
  /// The asset alone is not enough: pressing SEND twice on the same coin leaves its id
  /// unchanged, so the form — which is never disposed, because the stage keeps visited views
  /// alive — kept whatever coin the user had last picked inside it.
  int _sendRequest = 0;

  /// Bumped on every navigation so the views can stagger their rows in.
  ///
  /// The animation should replay when the user comes back to a screen, which a plain bool
  /// cannot express — it has already been true once.
  int _entrance = 0;

  /// Every way of arriving somewhere, including a click on the rail.
  ///
  /// The counter and the destination have to move in one gesture. The rail used to move the
  /// destination on its own, from inside the shell, and a screen rebuilt that way carried the
  /// entrance it already had — so `Rise` saw nothing change and the rows did not stagger in on
  /// the one path almost all navigation takes.
  void _go(NavDestination destination) {
    setState(() => _entrance++);
    _shell.currentState?.go(destination);
  }

  void _openAsset(Asset asset) => setState(() {
    _openCoin = asset;
    _entrance++;
  });

  void _closeCoin() => setState(() {
    _openCoin = null;
    _entrance++;
  });

  void _sendFrom(Asset asset) {
    setState(() {
      _sendAsset = asset;
      _sendRequest++;
    });
    _go(NavDestination.send);
  }

  Future<void> _receive(Asset asset) {
    final chain = asset.chain;
    return showKoraSheet<void>(
      context,
      builder: (context) => ReceiveSheet(
        symbol: asset.symbol,
        // A token has no address of its own: it is received at the native coin's address on
        // the same chain. Showing the token's contract address here would send the funds to
        // the contract, where they stay.
        address: _receiveAddress(asset),
        chain: chain.tag,
        network: chain.network,
        walletName: ref.read(currentWalletProvider).value?.name ?? 'WALLET',
      ),
    );
  }

  /// Which coins the portfolio shows.
  ///
  /// The list is rebuilt from the live assets on every toggle, so a coin moves between ADD
  /// and REMOVE under the cursor without the sheet closing — the user is usually changing
  /// several at once, and closing after each one would make that tedious.
  Future<void> _chooseTokens() => showKoraSheet<void>(
    context,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final assets = ref.watch(assetsProvider);
        final byId = {for (final a in assets) a.id: a};
        return TokenSheet(
          choices: [
            for (final token in allCatalogTokens)
              TokenChoice(
                token: token,
                shown: byId[token.id]?.isVisible ?? false,
                held: byId[token.id]?.balanceAsDouble ?? 0,
              ),
          ],
          onToggle: (token, shown) {
            final notifier = ref.read(currentWalletProvider.notifier);
            if (shown) {
              notifier.addToken(token);
            } else {
              notifier.removeToken(token.id);
            }
          },
        );
      },
    ),
  );

  String _receiveAddress(Asset asset) {
    if (asset.type == AssetType.native) return asset.contractAddress;
    final assets = ref.read(assetsProvider);
    final native = assets
        .where((a) => a.blockchain == asset.blockchain && a.type == AssetType.native)
        .firstOrNull;
    return native?.contractAddress ?? asset.contractAddress;
  }

  /// Re-derives this wallet's addresses when the app could not do it by itself.
  ///
  /// `_loadWallet` detects stored addresses that do not match the chain they claim to be on —
  /// a Litecoin asset carrying a 0x address, say — and tries to fix them with a legacy
  /// fallback passphrase. When that fails it raises `needsMigrationPinProvider` and hands the
  /// interface the wallet anyway, with the wrong addresses still in it. Nothing anywhere read
  /// that flag, so the prompt it was raised for did not exist and the Receive sheet would go
  /// on printing an address on the wrong chain. Coins sent to it do not come back.
  Future<void> _migrateAddresses() async {
    final passphrase = await askPassphrase(
      context,
      title: 'FINISH SETUP',
      explanation:
          'Some of this wallet’s receiving addresses could not be prepared. They '
          'have to be derived again from the recovery phrase before it is safe to receive.',
      confirmLabel: 'CONTINUE',
    );
    if (passphrase == null || !mounted) return;

    final ok = await ref.read(currentWalletProvider.notifier).refreshWalletAddresses(passphrase);
    if (!mounted) return;
    if (ok) {
      ref.read(needsMigrationPinProvider.notifier).state = false;
    } else {
      await showKoraSheet<void>(
        context,
        builder: (context) => const KoraNotice(
          title: 'NOT FINISHED',
          body:
              'That passphrase does not open this wallet, so the addresses are unchanged. '
              'Do not receive into this wallet until this succeeds.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Raised when the app knows its own addresses are wrong. Asked once, on the frame after
    // it goes up, because a dialog cannot be opened during a build.
    ref.listen<bool>(needsMigrationPinProvider, (_, needed) {
      if (needed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _migrateAddresses();
        });
      }
    });

    final wallets = ref.watch(allWalletsProvider).valueOrNull ?? const <Wallet>[];
    final current = ref.watch(currentWalletProvider).value;
    final money = ref.watch(currencyProvider);
    final assets = ref.watch(visibleAssetsProvider);

    // The open coin is re-read from the live list each build, so a price tick or a balance
    // change reaches the coin page. Holding the object from when it was tapped would freeze
    // the page at the moment it was opened.
    final coin = _openCoin == null
        ? null
        : assets.where((a) => a.id == _openCoin!.id).firstOrNull ?? _openCoin;

    return AppShell(
      key: _shell,
      wallets: wallets,
      activeWalletId: current?.id,
      // Every wallet totals the same way, from the assets stored with it — including the
      // open one, whose stored assets are the live ones. Converted here because the switcher
      // prints this under money.symbol; unconverted it showed dollars labelled as euros.
      walletValue: (wallet) => money.convert(wallet.storedValueUsd),
      currencySymbol: money.symbol,
      onSelectWallet: (wallet) async {
        await switchWalletWithPassphrase(context, ref, wallet);
        // The coin page belongs to the wallet that was open. Left up, it would show the
        // previous wallet's holding under the new wallet's name. Cleared only after a switch
        // actually happened, so a cancelled prompt leaves the page where it was.
        if (mounted && ref.read(currentWalletProvider).value?.id == wallet.id) {
          setState(() => _openCoin = null);
        }
      },
      onCreateWallet: () => addWalletWithPassphrase(context, ref),
      onLock: widget.onLock,
      onToggleTheme: ThemeNotifier.instance.toggleTheme,
      onNavigate: _go,
      views: {
        // The coin page opens inside the portfolio's slot, which means `Stage` never sees it:
        // Stage only animates a change of destination, and this is not one. So the only
        // motion used to come from the movement table staggering its rows in — and a coin
        // with no transactions has no rows, which is exactly why opening a coin you hold none
        // of appeared instantly while opening one you hold animated. The swap gets its own
        // transition here, in the same language Stage uses, so both read the same.
        NavDestination.portfolio: (context) => _PortfolioSlot(
          portfolio: PortfolioScreen(
            entrance: _entrance,
            onOpenAsset: _openAsset,
            onAddToken: _chooseTokens,
            onReceive: _receive,
          ),
          // Keyed by the coin it is for, so opening a different one starts that page over
          // rather than pouring a new asset into the page the last one left behind.
          coin: coin == null
              ? null
              : CoinScreen(
                  key: ValueKey('coin:${coin.id}'),
                  asset: coin,
                  entrance: _entrance,
                  onBack: _closeCoin,
                  onSend: () => _sendFrom(coin),
                  onReceive: () => _receive(coin),
                ),
        ),
        NavDestination.send: (context) => SendScreen(
          initialAsset: _sendAsset,
          request: _sendRequest,
          onSent: (_) => _go(NavDestination.history),
        ),
        NavDestination.history: (context) => HistoryScreen(entrance: _entrance),
        NavDestination.settings: (context) => SettingsScreen(version: widget.version),
      },
    );
  }
}

/// The portfolio slot: the holdings list, with one coin's page over it.
///
/// A short slide and a fade, matching `Stage`'s own transition so moving into a coin feels
/// like moving between destinations rather than like a page reloading.
///
/// The holdings list is hidden while a coin is open, never removed. It was removed once, by an
/// `AnimatedSwitcher` whose reverse ran in no time at all, and an element that leaves the tree
/// takes with it everything the user had built up in it: the scroll offset of a list they had
/// worked their way down, and a chart that had finished drawing itself. Coming back out of a
/// coin put them at the top of the page again and redrew the curve they had already watched
/// draw. `Stage` says the same thing about its own views, and this slot is a change of view in
/// all but name.
///
/// What the switcher was right about is the timing: the page being left goes to nothing in the
/// same frame the new one starts. Anything slower paints both at once, and two dark pages of
/// text at partial opacity read as one page printed twice — the balance of the portfolio
/// showing straight through the balance of the coin.
class _PortfolioSlot extends StatelessWidget {
  const _PortfolioSlot({required this.portfolio, required this.coin});

  final Widget portfolio;

  /// Null when the holdings list is what is being looked at.
  final Widget? coin;

  @override
  Widget build(BuildContext context) => Stack(
    // Keyed because which element belongs to which page is the whole point here: the
    // holdings list has to be recognised as the same layer it was before the coin was put
    // over it, or it is rebuilt and everything this arrangement exists to keep is lost.
    children: [
      _SlotLayer(
        key: const ValueKey('portfolio'),
        active: coin == null,
        rest: -kViewTravel,
        arriving: false,
        child: portfolio,
      ),
      if (coin case final page?)
        _SlotLayer(
          key: const ValueKey('coin'),
          active: true,
          rest: kViewTravel,
          arriving: true,
          child: page,
        ),
    ],
  );
}

/// One page of the slot, laid out to fill it whether or not it is the one showing.
class _SlotLayer extends StatelessWidget {
  const _SlotLayer({
    super.key,
    required this.active,
    required this.rest,
    required this.arriving,
    required this.child,
  });

  final bool active;

  /// Where the page waits while it is not the one showing: the coin off to the right, because
  /// it is the page you go deeper into, the holdings list off to the left, because it is the
  /// page you come back out to.
  final double rest;

  /// Whether this page's first build is an arrival. The coin's is — it enters the tree by
  /// being opened, so it has to travel in from [rest]. The holdings list's is not: it is
  /// already there when the window opens, and would otherwise slide in from nowhere at launch.
  final bool arriving;

  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      // The hidden page is still laid out, which is the point of keeping it, so it is also
      // still a hit-test target. Left alone it would take the hover and the clicks meant
      // for the coin page drawn over it.
      ignoring: !active,
      // Shown or not shown, with nothing in between, and the slide below carries the motion.
      //
      // The way out has to be instant, for the reason the slot above gives: a page that fades
      // out while another fades in is a page printed twice. The way back had been left as a
      // 300ms fade, and there it cost a blank frame — closing a coin removes that layer from
      // the tree in the same build, so the holdings list had nothing to fade up against except
      // the empty background, and going back read as slower and less solid than going in.
      child: Opacity(
        opacity: active ? 1 : 0,
        child: TweenAnimationBuilder<double>(
          // `begin` is read once, on the first build, and ignored on every one after it;
          // from then on it is the change of `end` that moves the page.
          tween: Tween<double>(begin: arriving ? rest : null, end: active ? 0.0 : rest),
          duration: active ? kViewSlide : Duration.zero,
          curve: kEase,
          // The subtree goes through `child`, so the page is built once and only the
          // transform is recomputed per frame.
          builder: (context, dx, inner) => Transform.translate(offset: Offset(dx, 0), child: inner),
          // The boundary means the fade composites a cached raster of the page instead of
          // re-rasterising its whole contents on every frame — the layer an opacity
          // animation forces has to come from somewhere.
          child: RepaintBoundary(child: child),
        ),
      ),
    ),
  );
}
