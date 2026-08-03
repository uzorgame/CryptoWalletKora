import 'package:flutter/material.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/features/settings/widgets/settings_tile.dart';

// The theme picker row.

class AppearanceTile extends StatelessWidget {
  const AppearanceTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeNotifier.instance,
      builder: (_, __) {
        final isDark = ThemeNotifier.instance.isDark;
        return SettingsTile(
          icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          label: 'Appearance',
          value: isDark ? 'Dark' : 'Light',
          onTap: () { ThemeNotifier.instance.setTheme(isDark ? 'Light' : 'Dark'); },
        );
      },
    );
  }
}
