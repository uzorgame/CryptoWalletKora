import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';

// What the asset list shows when there is nothing to list.

class EmptyAssets extends StatelessWidget {
  const EmptyAssets({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              color: AppColors.textTertiary, size: 48),
          SizedBox(height: 12),
          Text('No assets yet',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          SizedBox(height: 4),
          Text('Create or import a wallet to get started',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ],
      ),
    );
  }
}
