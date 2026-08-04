import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/state/providers/settings_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';

class AutoLockSelectorScreen extends ConsumerWidget {
  const AutoLockSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTimeout = ref.watch(autoLockTimeoutProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: koraAppBar(context, 'Auto-Lock',
          backLabel: 'Settings',
          onBack: () => Navigator.of(context).pop()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Text(
              'Lock app when returning from background after the selected time.',
              style: kBody(AppColors.textSecondary, size: 14).copyWith(height: 1.4),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: AutoLockTimeout.values.length,
              itemBuilder: (context, index) {
                final timeout = AutoLockTimeout.values[index];
                final isSelected = timeout == currentTimeout;

                return GestureDetector(
                  onTap: () {
                    ref.read(settingsProvider.notifier).setAutoLockTimeout(timeout);
                    Navigator.of(context).pop();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    decoration: BoxDecoration(border: Border(bottom: kHairlineSide())),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(timeout.displayName.toUpperCase(),
                                  style: kLabel(
                                      isSelected
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                      size: 12.5, tracking: 0.06)),
                              const SizedBox(height: 4),
                              Text(timeout.description.toUpperCase(),
                                  style: kMonoText(AppColors.textTertiary, size: 9)),
                            ]),
                      ),
                      if (isSelected)
                        Text('✓', style: kMonoText(AppColors.textPrimary, size: 12)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
