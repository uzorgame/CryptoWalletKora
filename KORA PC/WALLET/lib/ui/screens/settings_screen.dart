import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/key_manager.dart';
import '../../core/models/wallet.dart';
import '../../core/services/theme_notifier.dart';
import '../../core/state/providers/asset_provider.dart';
import '../../core/state/providers/currency_provider.dart';
import '../../core/state/providers/settings_provider.dart' hide currencyProvider;
import '../../core/state/providers/wallet_provider.dart';
import '../common/kora_sheet.dart';
import '../common/wallet_actions.dart';
import '../format/wallet_total.dart';
import '../common/passphrase_gate.dart';
import '../settings/settings_view.dart';

/// Connects settings to the notifiers that own each piece of state.
///
/// There is no single settings object behind this screen: currency carries live rates, the
/// theme is a `ChangeNotifier` the whole app renders from, and the rest is `AppSettings`.
/// Each one is written through its own owner rather than copied into a fourth place.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.version});

  final String version;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    ThemeNotifier.instance.addListener(_onTheme);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onTheme);
    super.dispose();
  }

  void _onTheme() {
    if (mounted) setState(() {});
  }

  Future<void> _changePin() async {
    final current = await askPassphrase(
      context,
      title: 'CHANGE PASSPHRASE',
      explanation: 'Enter the passphrase you use now.',
      confirmLabel: 'CONTINUE',
    );
    if (current == null || !mounted) return;

    final replacement = await askPassphrase(
      context,
      title: 'NEW PASSPHRASE',
      explanation: 'Every wallet is re-encrypted under this. Losing it loses the wallets, '
          'because nothing else can decrypt them.',
      confirmLabel: 'CHANGE',
    );
    if (replacement == null || !mounted) return;

    // Every wallet is re-encrypted in one operation. Passing the whole list is what makes it
    // atomic: a per-wallet loop that failed halfway would leave some wallets on the old
    // passphrase and some on the new, with nothing recording which was which.
    final wallets = await ref.read(allWalletsProvider.future);
    final ok = await KeyManager.changePin(
      current,
      replacement,
      walletIds: [for (final w in wallets) w.id],
    );
    if (!mounted) return;
    await _tell(
      ok ? 'PASSPHRASE CHANGED' : 'NOT CHANGED',
      ok
          ? 'Every wallet is now encrypted under the new passphrase.'
          : 'The current passphrase was not correct, so nothing was changed.',
    );
  }

  Future<void> _revealPhrase() async {
    final wallet = ref.read(currentWalletProvider).value;
    if (wallet == null) return;

    final passphrase = await askPassphrase(
      context,
      title: 'RECOVERY PHRASE',
      explanation: 'Twelve words that are the wallet. Anyone who reads them can spend from '
          'it — make sure nobody is watching the screen.',
      confirmLabel: 'REVEAL',
    );
    if (passphrase == null || !mounted) return;

    final mnemonic = await KeyManager.getSeedPhrase(passphrase, walletId: wallet.id);
    if (!mounted) return;
    if (mnemonic == null) {
      await _tell('NOT SHOWN', 'That passphrase does not open this wallet.');
      return;
    }
    await _tell(wallet.name.toUpperCase(), mnemonic, mono: true);
  }

  Future<void> _deleteWallet(Wallet wallet) async {
    final passphrase = await askPassphrase(
      context,
      title: 'DELETE ${wallet.name.toUpperCase()}',
      explanation: 'The keys go with it. Without the recovery phrase written down elsewhere, '
          'anything held in this wallet becomes unreachable.',
      confirmLabel: 'DELETE WALLET',
      danger: true,
    );
    if (passphrase == null || !mounted) return;

    // The passphrase is checked against this wallet's own seed rather than against a stored
    // hash: proving the wallet can still be opened is the only check that means anything
    // here, and it is the same proof the user would need to restore it.
    final mnemonic = await KeyManager.getSeedPhrase(passphrase, walletId: wallet.id);
    if (!mounted) return;
    if (mnemonic == null) {
      await _tell('NOT DELETED', 'That passphrase does not open this wallet.');
      return;
    }

    await ref.read(currentWalletProvider.notifier).deleteWallet(wallet.id);
  }

  Future<void> _tell(String title, String body, {bool mono = false}) => showKoraSheet<void>(
        context,
        builder: (context) => KoraNotice(title: title, body: body, mono: mono),
      );

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final money = ref.watch(currencyProvider);
    final wallets = ref.watch(allWalletsProvider).valueOrNull ?? const <Wallet>[];
    final current = ref.watch(currentWalletProvider).value;
    final assets = ref.watch(visibleAssetsProvider);

    return SettingsView(
      settings: settings,
      isDark: ThemeNotifier.instance.isDark,
      onTheme: (dark) => ThemeNotifier.instance.setTheme(dark ? 'Dark' : 'Light'),
      money: money,
      wallets: wallets,
      activeWalletId: current?.id,
      walletValueUsd: (wallet) => wallet.storedValueUsd,
      version: widget.version,
      onSettings: (next) {
        final notifier = ref.read(settingsProvider.notifier);
        if (next.language != settings.language) notifier.setLanguage(next.language);
        if (next.autoLockTimeout != settings.autoLockTimeout) {
          notifier.setAutoLockTimeout(next.autoLockTimeout);
        }
      },
      onCurrency: (currency) => ref.read(currencyProvider.notifier).setCurrency(currency),
      onChangePin: _changePin,
      onRevealPhrase: _revealPhrase,
      onOpenWallet: (wallet) => switchWalletWithPassphrase(context, ref, wallet),
      onDeleteWallet: _deleteWallet,
      onCreateWallet: () => addWalletWithPassphrase(context, ref),
    );
  }
}
