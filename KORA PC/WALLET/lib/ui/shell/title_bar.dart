import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/kora_design.dart';
import '../../core/widgets/kora_mark.dart';
import 'window_controls.dart';

/// The window's own bar: the mark, the product name, and the controls.
///
/// The drag region stops where the controls begin. Wrapping the whole bar in a drag area made
/// every control a drag handle — the same trap `-webkit-app-region: no-drag` exists to solve.
class TitleBar extends StatelessWidget {
  const TitleBar({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return Container(
      height: kTitlebarHeight,
      decoration: BoxDecoration(
        color: p.bgAlt,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  KoraMark(size: 18, color: p.text),
                  const SizedBox(width: 10),
                  Text('KORA WALLET', style: koraLabel(p.text, size: 11, tracking: 0.18)),
                ],
              ),
            ),
          ),
          WindowControls(onToggleTheme: onToggleTheme),
        ],
      ),
    );
  }
}
