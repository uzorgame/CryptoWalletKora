import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';

/// The screen header: a tracked uppercase title on a hairline. One factory so every screen's
/// top edge is drawn by the same hand.
PreferredSizeWidget koraAppBar(
  BuildContext context,
  String title, {
  VoidCallback? onBack,
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: AppColors.background,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    automaticallyImplyLeading: false,
    leading: onBack == null
        ? null
        : IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppColors.textPrimary),
            onPressed: onBack,
          ),
    title: Text(title.toUpperCase(),
        style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.18)),
    actions: actions,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: AppColors.border),
    ),
  );
}
