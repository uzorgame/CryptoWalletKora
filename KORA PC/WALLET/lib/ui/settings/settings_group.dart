import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';
import '../common/section_header.dart';

/// A titled group of settings.
///
/// The outer border is not decoration. In the light theme the row surface and the page
/// background are both white, so without it a group dissolves into the page and only the
/// hairlines between rows survive.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(border: Border.all(color: p.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
        ),
      ],
    );
  }
}
