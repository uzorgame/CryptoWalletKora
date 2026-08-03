import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';

/// A label, a rule that takes the remaining width, and an optional action or aside.
///
/// The rule is what makes a section read as a section without a box around it, and its
/// reaching the full width is what stops the content below from looking misaligned.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.aside, this.action});

  final String title;

  /// A quiet fact about the section — a count, a date.
  final String? aside;

  /// A control belonging to the section, placed at its end.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: koraLabel(p.text3, size: 10, tracking: 0.18)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: p.border)),
        if (aside != null) ...[
          const SizedBox(width: 12),
          Text(aside!, style: koraLabel(p.text3, size: 9.5, tracking: 0.12)),
        ],
        if (action != null) ...[
          const SizedBox(width: 12),
          action!,
        ],
      ],
    );
  }
}
