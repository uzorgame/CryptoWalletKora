import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';

// The uppercase label above each block of the send form.

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: AppColors.textSecondary,
          fontSize: 13, fontWeight: FontWeight.w500));
}
