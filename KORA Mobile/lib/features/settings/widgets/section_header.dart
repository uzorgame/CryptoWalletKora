import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';

// The heading above each settings section — the prototype's quieter .ksec: 9.5px tracked
// at .18em in tertiary ink, or the negative colour over the wallet-removal group.

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.color});
  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
    child: Text(title.toUpperCase(),
        style: kLabel(color ?? AppColors.textTertiary, size: 9.5, tracking: 0.18)),
  );
}
