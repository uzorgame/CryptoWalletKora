import 'package:flutter/material.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/core/widgets/coin_icon.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/widgets/animated_tap.dart';

// One asset in the wallet tab's list.

class AssetTile extends StatelessWidget {
  const AssetTile({super.key, required this.asset, required this.visible,
      required this.currency, required this.onTap});
  final Asset asset;
  final bool visible;
  final CurrencyState currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.97,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(children: [
            CoinIcon(symbol: asset.symbol, iconUrl: asset.iconUrl, size: 40),
            const SizedBox(width: 12),
            // Symbol + network badge on same row, price per unit below
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(asset.symbol,
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_networkLabel(asset.blockchain),
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w500)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(visible ? currency.formatPrice(asset.priceUsd) : '••••',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ),
            // Balance quantity + total value
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(visible ? _formatAmount(asset.balanceAsDouble) : '••••',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(visible ? currency.formatPrice(asset.balanceInUsd) : '••••',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ]),
        ),
      ),
    );
  }

  static String _formatAmount(double value) {
    if (value == 0) return '0';
    if (value < 0.000001) return '< 0.000001';
    if (value >= 1000000) return value.toStringAsFixed(0);
    if (value >= 1000) return value.toStringAsFixed(2);
    final s = value.toStringAsFixed(6);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _networkLabel(String blockchain) {
    const labels = <String, String>{
      'bitcoin':          'Bitcoin',
      'ethereum':         'Ethereum',
      'solana':           'Solana',
      'bsc':              'BNB Smart Chain',
      'tron':             'Tron',
      'litecoin':         'Litecoin',
      'bitcoin_cash':     'Bitcoin Cash',
      'ethereum_classic': 'ETC',
    };
    return labels[blockchain] ?? blockchain;
  }
}
