import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

/// The primary action: the inverted surface. Full width, square, tracked uppercase mono.
///
/// Disabled it hollows out to a hairline with tertiary ink — still visibly a button, plainly
/// not ready. The colour swap animates over [kControl] so enabling reads as the control
/// waking rather than being replaced.
class KoraCta extends StatelessWidget {
  const KoraCta({super.key, required this.label, required this.onTap, this.busy = false});

  final String label;
  final VoidCallback? onTap;

  /// Shows a working state without moving the layout — the label dims and the button stops
  /// accepting presses, which on a wallet matters more than a spinner.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final button = AnimatedContainer(
      duration: kControl,
      curve: kEase,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? AppColors.textPrimary : Colors.transparent,
        border: Border.all(
            color: enabled ? AppColors.textPrimary : AppColors.border, width: 1),
      ),
      child: AnimatedDefaultTextStyle(
        duration: kControl,
        curve: kEase,
        style: kLabel(
          enabled ? AppColors.background : AppColors.textTertiary,
          size: 11,
          tracking: 0.16,
        ),
        child: Text(busy ? '···' : label.toUpperCase()),
      ),
    );
    if (!enabled) return button;
    return AnimatedTap(onTap: onTap, pressScale: 0.98, pressOpacity: 0.9, child: button);
  }
}

/// The secondary action: a hairline frame around the same tracked label.
class KoraGhost extends StatelessWidget {
  const KoraGhost({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.98,
      pressOpacity: 0.8,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: kHairline()),
        child: Text(label.toUpperCase(),
            style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.16)),
      ),
    );
  }
}
