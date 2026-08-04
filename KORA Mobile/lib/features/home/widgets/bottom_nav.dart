import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

// The home shell's bottom navigation bar — the desktop rail laid on its side: numbered,
// tracked, iconless. All four entries are real tabs now; the bar never leaves the screen
// while the user moves between Wallet, Send, Receive and Settings.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: kHairlineSide()),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Row(children: [
            for (final (i, label) in const ['WALLET', 'SEND', 'RECEIVE', 'SETTINGS'].indexed)
              _NavItem(
                no: '0${i + 1}',
                label: label,
                active: current == i,
                onTap: () => onTap(i),
              ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.no, required this.label,
      required this.active, required this.onTap});
  final String no;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = active ? AppColors.textPrimary : AppColors.textTertiary;
    return Expanded(
      child: AnimatedTap(
        onTap: onTap,
        pressScale: 0.92,
        pressOpacity: 0.6,
        child: Stack(
          children: [
            // The active item carries a hair of ink on the bar's own hairline.
            if (active)
              Positioned(
                top: 0, left: 0, right: 0,
                child: Center(
                    child: Container(width: 30, height: 1, color: AppColors.textPrimary)),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(no, style: kLabel(ink, size: 8, tracking: 0.14, weight: FontWeight.w400)),
                  const SizedBox(height: 4),
                  Text(label, style: kLabel(ink, size: 9, tracking: 0.12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
