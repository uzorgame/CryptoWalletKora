import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

/// The screen header: a tracked uppercase title on a hairline. One factory so every screen's
/// top edge is drawn by the same hand.
///
/// Going back is a word, not a chevron alone. `← WALLET` says where the tap lands, reads at
/// a glance, and gives the thumb something the size of a phrase to hit instead of a 20-pixel
/// arrow. [backLabel] names the destination; it defaults to `BACK` where there is nothing
/// more specific to say.
PreferredSizeWidget koraAppBar(
  BuildContext context,
  String title, {
  VoidCallback? onBack,
  String backLabel = 'Back',
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: AppColors.background,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    automaticallyImplyLeading: false,
    leadingWidth: onBack == null ? null : 140,
    leading: onBack == null ? null : KoraBackLink(label: backLabel, onTap: onBack),
    title: Text(title.toUpperCase(),
        style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.18)),
    actions: actions,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: AppColors.border),
    ),
  );
}

/// `← WALLET` — the way back, in the wallet's own voice. Used as an app bar's leading edge
/// and, on screens that scroll without a bar, directly above the content.
class KoraBackLink extends StatelessWidget {
  const KoraBackLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressOpacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('←', style: kMonoText(AppColors.textSecondary, size: 13)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: kLabel(AppColors.textSecondary, size: 10.5, tracking: 0.16)),
          ),
        ]),
      ),
    );
  }
}
