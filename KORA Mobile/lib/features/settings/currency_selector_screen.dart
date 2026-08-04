import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';

class CurrencySelectorScreen extends ConsumerWidget {
  const CurrencySelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCurrency = ref.watch(currencyProvider).currency;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: koraAppBar(context, 'Select Currency',
          backLabel: 'Settings',
          onBack: () => Navigator.of(context).pop()),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: AppCurrency.values.length,
        itemBuilder: (context, index) {
          final currency = AppCurrency.values[index];
          final isSelected = currency == currentCurrency;

          return GestureDetector(
            onTap: () {
              ref.read(currencyProvider.notifier).setCurrency(currency);
              Navigator.of(context).pop();
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(border: Border(bottom: kHairlineSide())),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(currency.name,
                        style: kBody(
                            isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                            size: 13.5,
                            weight: isSelected ? FontWeight.w500 : FontWeight.w400)),
                    const SizedBox(height: 4),
                    Text('${currency.symbol}  ${currency.code.toUpperCase()}',
                        style: kMonoText(AppColors.textTertiary, size: 9.5)),
                  ]),
                ),
                if (isSelected)
                  Text('✓', style: kMonoText(AppColors.textPrimary, size: 12)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
