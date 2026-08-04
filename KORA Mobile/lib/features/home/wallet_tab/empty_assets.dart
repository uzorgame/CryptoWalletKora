import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';

// What the asset list shows when there is nothing to list. Words, not a pictogram: a
// forty-eight-pixel outline of a wallet says nothing the sentence beneath it does not.

class EmptyAssets extends StatelessWidget {
  const EmptyAssets({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('NO ASSETS YET',
                style: kLabel(AppColors.textSecondary, size: 10.5, tracking: 0.16)),
            const SizedBox(height: 10),
            Text('CREATE OR IMPORT A WALLET TO GET STARTED',
                textAlign: TextAlign.center,
                style: kLabel(AppColors.textTertiary, size: 8.5, tracking: 0.1,
                        weight: FontWeight.w400)
                    .copyWith(height: 1.8)),
          ],
        ),
      ),
    );
  }
}
