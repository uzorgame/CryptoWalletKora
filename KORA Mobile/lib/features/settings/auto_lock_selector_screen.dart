import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/state/providers/settings_provider.dart';
import 'package:kora/core/theme/app_theme.dart';

class AutoLockSelectorScreen extends ConsumerWidget {
  const AutoLockSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTimeout = ref.watch(autoLockTimeoutProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Auto-Lock',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Text(
              'Lock app when returning from background after the selected time.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: AutoLockTimeout.values.length,
              itemBuilder: (context, index) {
                final timeout = AutoLockTimeout.values[index];
                final isSelected = timeout == currentTimeout;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.textPrimary.withValues(alpha: 0.3)
                          : AppColors.border,
                      width: isSelected ? 1.0 : 0.5,
                    ),
                  ),
                  child: ListTile(
                    title: Text(timeout.displayName,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                    subtitle: Text(timeout.description,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded,
                            color: AppColors.textPrimary, size: 22)
                        : null,
                    onTap: () {
                      ref.read(settingsProvider.notifier).setAutoLockTimeout(timeout);
                      Navigator.of(context).pop();
                    },
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
