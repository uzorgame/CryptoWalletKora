import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';

// The heading above each settings section.

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.color});
  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Text(title,
        style: TextStyle(
            color: color ?? AppColors.textSecondary,
            fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
  );
}
