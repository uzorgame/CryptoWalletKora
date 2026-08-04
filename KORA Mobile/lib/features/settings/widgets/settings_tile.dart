import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

// One row of the settings list: title, value and where tapping it leads.
//
// A hairline table row like every other list in the wallet. The icon is gone — a column of
// small pictograms is decoration, and the label already says what the row is. [icon] and
// [iconColor] stay in the signature so no caller had to change.

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon, required this.label, required this.onTap,
    this.value, this.iconColor, this.labelColor,
  });
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final Color? iconColor, labelColor;

  @override
  Widget build(BuildContext context) => AnimatedTap(
    onTap: onTap,
    pressScale: 0.98,
    pressOpacity: 0.85,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
      decoration: BoxDecoration(border: Border(bottom: kHairlineSide())),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: kBody(labelColor ?? AppColors.textPrimary, size: 13.5)),
        ),
        if (value != null)
          Text(value!.toUpperCase(),
              style: kMonoText(AppColors.textSecondary, size: 10))
        else
          Text('›', style: kMonoText(AppColors.textTertiary, size: 13)),
      ]),
    ),
  );
}
