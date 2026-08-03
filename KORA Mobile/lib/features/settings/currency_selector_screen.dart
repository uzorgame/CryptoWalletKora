import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/core/theme/app_theme.dart';

class CurrencySelectorScreen extends ConsumerWidget {
  const CurrencySelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCurrency = ref.watch(currencyProvider).currency;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Select Currency',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: AppCurrency.values.length,
        itemBuilder: (context, index) {
          final currency = AppCurrency.values[index];
          final isSelected = currency == currentCurrency;

          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.textPrimary.withValues(alpha: 0.3) : AppColors.border,
                width: isSelected ? 1.0 : 0.5,
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              title: Text(currency.name,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
              subtitle: Text('${currency.symbol}  ${currency.code.toUpperCase()}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: AppColors.textPrimary, size: 20)
                  : null,
              onTap: () {
                ref.read(currencyProvider.notifier).setCurrency(currency);
                Navigator.of(context).pop();
              },
            ),
          );
        },
      ),
    );
  }
}
