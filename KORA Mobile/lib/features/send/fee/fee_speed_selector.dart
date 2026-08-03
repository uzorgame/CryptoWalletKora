import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/features/send/fee/models/fee_estimate.dart';

// The slow / normal / fast fee tier picker, for the chains that price them apart.

class FeeSpeedSelector extends StatelessWidget {
  const FeeSpeedSelector({super.key, required this.selected, required this.onSelect});
  final FeeSpeed selected;
  final void Function(FeeSpeed) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(children: FeeSpeed.values.map((spd) {
      final isSelected = spd == selected;
      final label = switch (spd) {
        FeeSpeed.slow   => 'Slow',
        FeeSpeed.normal => 'Normal',
        FeeSpeed.fast   => 'Fast',
      };
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(spd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.only(
              left: spd == FeeSpeed.slow ? 0 : 4,
              right: spd == FeeSpeed.fast ? 0 : 4,
            ),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.textPrimary : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.textPrimary : AppColors.border,
                width: 0.5,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppColors.background : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }).toList());
  }
}
