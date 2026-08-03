import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/state/providers/settings_provider.dart' hide currencyProvider;
import 'package:kora/features/settings/auto_lock_selector_screen.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/features/settings/widgets/settings_tile.dart';

// The auto-lock timeout row.

class AutoLockTile extends ConsumerWidget {
  const AutoLockTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(autoLockTimeoutProvider);
    return SettingsTile(
      icon: Icons.timer_outlined,
      label: 'Auto-Lock',
      value: current.displayName,
      onTap: () { debugPrint('[TAP] Auto-Lock picker (settings_screen.dart)'); _showPicker(context, ref, current); },
    );
  }

  void _showPicker(
      BuildContext context, WidgetRef ref, AutoLockTimeout current) {
    context.pushSlide(const AutoLockSelectorScreen());
  }
}
