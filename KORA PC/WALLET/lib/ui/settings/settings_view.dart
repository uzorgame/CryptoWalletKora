import 'package:flutter/material.dart';

import '../common/smooth_scroll.dart';

import '../../core/models/wallet.dart';
import '../../core/services/localization_service.dart';
import '../../core/state/providers/currency_provider.dart';
import '../../core/state/providers/settings_provider.dart' hide currencyProvider;
import '../common/kora_button.dart';
import '../common/segmented_control.dart';
import '../format/currency_format.dart';
import '../format/moment.dart' as moment;
import 'setting_row.dart';
import 'settings_group.dart';

/// Security, display, wallets, about.
///
/// Reads and writes `AppSettings` — the app's own settings object, with its own persistence.
/// An earlier pass invented a parallel one; this screen would then have been the only thing
/// that knew about it, and everything else in the app would have gone on reading the real one.
class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.settings,
    required this.isDark,
    required this.onTheme,
    required this.money,
    required this.wallets,
    required this.activeWalletId,
    required this.walletValueUsd,
    required this.version,
    required this.onSettings,
    required this.onCurrency,
    required this.onChangePin,
    required this.onRevealPhrase,
    required this.onOpenWallet,
    required this.onDeleteWallet,
    required this.onCreateWallet,
  });

  final AppSettings settings;

  /// The theme lives in `ThemeNotifier`, not in `AppSettings` — it is what the app actually
  /// renders from, and one owner per stored key is the only way it survives a restart.
  final bool isDark;
  final ValueChanged<bool> onTheme;

  final CurrencyState money;

  final List<Wallet> wallets;
  final String? activeWalletId;
  final double? Function(Wallet) walletValueUsd;
  final String version;

  final ValueChanged<AppSettings> onSettings;

  /// Currency lives in its own notifier because it carries live exchange rates, so changing
  /// it is a separate call rather than another field on the settings object.
  final ValueChanged<AppCurrency> onCurrency;

  final VoidCallback onChangePin;
  final VoidCallback onRevealPhrase;
  final ValueChanged<Wallet> onOpenWallet;
  final ValueChanged<Wallet> onDeleteWallet;
  final VoidCallback onCreateWallet;

  @override
  Widget build(BuildContext context) => SmoothScrollView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _security(),
            const SizedBox(height: 24),
            _display(),
            const SizedBox(height: 24),
            _wallets(),
            const SizedBox(height: 24),
            _about(),
          ],
        ),
      );

  Widget _security() => SettingsGroup(
        title: 'SECURITY',
        rows: [
          SettingRow(
            title: 'App passphrase',
            description: 'One passphrase unlocks KORA, and KORA holds every wallet — there '
                'is no separate code per wallet.',
            control: KoraButton(label: 'CHANGE PIN', onPressed: onChangePin),
          ),
          // Not a toggle. Every seed is stored encrypted under the passphrase, so signing
          // cannot happen without it — there is no state of this app in which a transaction
          // goes out unprompted. A switch here would imply the protection is a policy that
          // could be turned off, and a switch reading "off" would suggest the funds were less
          // guarded than they are.
          const SettingRow(
            title: 'Passphrase to send',
            description: 'Every recovery phrase is encrypted with it, so nothing can be '
                'signed without it. This cannot be switched off.',
            control: SettingValue('ALWAYS ON'),
          ),
          SettingRow(
            title: 'Auto-lock',
            description: 'How long KORA stays open while unattended',
            control: SegmentedControl(
              options: [for (final t in AutoLockTimeout.values) _lockLabel(t)],
              selected: _lockLabel(settings.autoLockTimeout),
              onSelect: (label) => onSettings(
                settings.copyWith(
                  autoLockTimeout: AutoLockTimeout.values
                      .firstWhere((t) => _lockLabel(t) == label),
                ),
              ),
            ),
          ),
          SettingRow(
            title: 'Recovery phrase',
            description: 'Twelve words per wallet. Shown once, never stored in plain text, '
                'never sent anywhere.',
            control: KoraButton(label: 'REVEAL', onPressed: onRevealPhrase),
            last: true,
          ),
        ],
      );

  Widget _display() => SettingsGroup(
        title: 'DISPLAY',
        rows: [
          SettingRow(
            title: 'Appearance',
            description: 'The window follows this, not the system setting',
            control: SegmentedControl(
              options: const ['DARK', 'LIGHT'],
              selected: isDark ? 'DARK' : 'LIGHT',
              onSelect: (value) => onTheme(value == 'DARK'),
            ),
          ),
          SettingRow(
            title: 'Language',
            description: 'What the interface is written in',
            control: SegmentedControl(
              options: [for (final l in kLanguages) l.code.toUpperCase()],
              selected: LocalizationService.resolve(settings.language).code.toUpperCase(),
              onSelect: (code) => onSettings(
                settings.copyWith(
                  language: kLanguages.firstWhere((l) => l.code.toUpperCase() == code).name,
                ),
              ),
            ),
          ),
          SettingRow(
            title: 'Currency',
            description: 'Every value on screen is converted to this',
            control: SegmentedControl(
              options: [for (final c in _currencies) c.code.toUpperCase()],
              selected: money.currency.code.toUpperCase(),
              onSelect: (code) => onCurrency(
                _currencies.firstWhere((c) => c.code.toUpperCase() == code),
              ),
            ),
            last: true,
          ),
        ],
      );

  Widget _wallets() => SettingsGroup(
        title: 'WALLETS',
        rows: [
          for (final wallet in wallets)
            SettingRow(
              title: wallet.name,
              description: 'Created ${moment.day(wallet.createdAt)}',
              control: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SettingValue(money.format(walletValueUsd(wallet))),
                  const SizedBox(width: 10),
                  if (wallet.id == activeWalletId)
                    const SettingValue('ACTIVE')
                  else
                    KoraButton(label: 'OPEN', onPressed: () => onOpenWallet(wallet)),
                  const SizedBox(width: 10),
                  // Deleting a wallet belongs beside that wallet. A single remove button
                  // somewhere else can only ever mean "the one currently open", and that
                  // ambiguity does not belong next to a key store.
                  KoraButton(
                    label: 'DELETE',
                    tone: KoraButtonTone.danger,
                    onPressed: wallets.length > 1 ? () => onDeleteWallet(wallet) : null,
                  ),
                ],
              ),
            ),
          SettingRow(
            title: 'Add wallet',
            description: 'A new key set under the same app passphrase',
            control: KoraButton(label: 'CREATE', onPressed: onCreateWallet),
            last: true,
          ),
        ],
      );

  Widget _about() => SettingsGroup(
        title: 'ABOUT',
        rows: [
          SettingRow(
            title: 'Version',
            description: 'KORA Wallet for Windows',
            control: SettingValue(version),
            last: true,
          ),
        ],
      );

  /// The five the app carries rates for. `AppCurrency` also lists crypto denominations, which
  /// are a different idea — pricing a portfolio in BTC is not a display currency.
  static const _currencies = [
    AppCurrency.usd,
    AppCurrency.eur,
    AppCurrency.gbp,
    AppCurrency.cad,
    AppCurrency.uah,
  ];

  static String _lockLabel(AutoLockTimeout timeout) => switch (timeout) {
        AutoLockTimeout.immediately => 'NOW',
        AutoLockTimeout.oneMinute => '1 MIN',
        AutoLockTimeout.fiveMinutes => '5 MIN',
        AutoLockTimeout.fifteenMinutes => '15 MIN',
        AutoLockTimeout.onLaunchOnly => 'NEVER',
      };
}
