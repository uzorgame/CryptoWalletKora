import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

// The orders the asset list can be shown in, and the sheet row that picks one.

enum SortMode { popularity, totalValue, quantity, price }

class SortOption extends StatelessWidget {
  const SortOption({super.key, 
    required this.icon, required this.label, required this.subtitle,
    required this.selected, required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.97,
      child: ListTile(
        leading: Icon(icon,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary, size: 22),
        title: Text(label,
            style: kBody(AppColors.textPrimary, size: 15)),
        subtitle: Text(subtitle,
            style: kBody(AppColors.textTertiary, size: 12)),
        trailing: selected
            ? Icon(Icons.check_rounded, color: AppColors.textPrimary, size: 20)
            : null,
      ),
    );
  }
}
