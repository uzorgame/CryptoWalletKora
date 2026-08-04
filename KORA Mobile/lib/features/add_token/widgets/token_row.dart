import 'package:flutter/material.dart';
import 'package:kora/features/add_token/widgets/network_filter.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/constants/token_catalog.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';

// One token in the search results, with its add / added state — a hairline row like every
// other list in the wallet. The action reads as a word rather than a plus in a box: ADD, or
// ADDED once it is in the wallet.

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
      pressScale: 0.98,
      pressOpacity: 0.85,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: kHairlineSide())),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(token.symbol,
                            style: kLabel(AppColors.textPrimary,
                                size: 12.5, tracking: 0.06)),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(token.name,
                              overflow: TextOverflow.ellipsis,
                              style: kBody(AppColors.textSecondary, size: 11)),
                        ),
                      ]),
                  const SizedBox(height: 5),
                  Text(networkLabel(token.blockchain).toUpperCase(),
                      style: kMonoText(AppColors.textTertiary, size: 9.5)),
                ]),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: kControl,
            curve: kEase,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(
                color: isAdded ? AppColors.border : AppColors.borderHi,
                width: 1,
              ),
            ),
            child: Text(isAdded ? 'ADDED' : 'ADD',
                style: kLabel(
                    isAdded ? AppColors.textTertiary : AppColors.textPrimary,
                    size: 9, tracking: 0.14)),
          ),
        ]),
      ),
    );
  }
}
