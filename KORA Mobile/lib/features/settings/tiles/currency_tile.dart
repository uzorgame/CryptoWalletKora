import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/features/settings/currency_selector_screen.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/features/settings/widgets/settings_tile.dart';

// The display currency row.

class CurrencyTile extends ConsumerWidget {
  const CurrencyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(currencyProvider);
    return SettingsTile(
      icon: Icons.currency_exchange_rounded,
      label: 'Currency',
      value: '${cur.currency.symbol}  ${cur.currency.code.toUpperCase()}',
      onTap: () => _showPicker(context, ref, cur.currency),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref, AppCurrency selected) {
    debugPrint('[TAP] Currency picker (settings_screen.dart)');
    context.pushSlide(const CurrencySelectorScreen());
  }
}
