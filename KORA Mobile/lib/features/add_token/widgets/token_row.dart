import 'package:flutter/material.dart';
import 'package:kora/features/add_token/widgets/network_filter.dart';
import 'package:kora/core/widgets/animated_tap.dart';
import 'package:kora/core/constants/token_catalog.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/widgets/coin_icon.dart';

// One token in the search results, with its add / added state.

class TokenRow extends StatelessWidget {
  const TokenRow({
    super.key,
    required this.token,
    required this.isAdded,
    required this.onToggle,
  });

  final CatalogToken token;
  final bool isAdded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onToggle,
      pressScale: 0.97,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          CoinIcon(symbol: token.symbol, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(token.symbol,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        networkLabel(token.blockchain),
                        style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ]),
          ),
          // +/- toggle button
          AnimatedTap(
            onTap: onToggle,
            pressScale: 0.85,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAdded
                    ? AppColors.negative.withValues(alpha: 0.12)
                    : Colors.transparent,
                border: Border.all(
                  color: isAdded
                      ? AppColors.negative
                      : AppColors.textTertiary,
                  width: 1.5,
                ),
              ),
              child: Icon(
                isAdded ? Icons.remove_rounded : Icons.add_rounded,
                color:
                    isAdded ? AppColors.negative : AppColors.textSecondary,
                size: 16,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
