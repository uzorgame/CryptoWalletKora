import 'package:flutter/material.dart';
import 'package:kora/core/widgets/kora_rows.dart';

// One row of the settings list: title, value and where tapping it leads.
//
// The prototype's krow, drawn by the shared primitive so this list and the asset tables
// measure identically. The icon is gone — a column of small pictograms is decoration, and
// the label already says what the row is. [icon] and [iconColor] stay in the signature so
// no caller had to change.

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
  Widget build(BuildContext context) => KoraSettingRow(
        label,
        value: value,
        onTap: onTap,
        labelColor: labelColor,
      );
}
