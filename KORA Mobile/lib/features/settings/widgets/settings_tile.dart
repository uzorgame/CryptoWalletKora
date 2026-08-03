import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

// One row of the settings list: icon, title, value and where tapping it leads.

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
    pressScale: 0.97,
    child: Container(
      margin: EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: labelColor ?? AppColors.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w400)),
        ),
        if (value != null)
          Text(value!, style: TextStyle(color: AppColors.textSecondary, fontSize: 14))
        else
          Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
      ]),
    ),
  );
}
