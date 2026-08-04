import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/features/send/fee/models/fee_estimate.dart';

// The slow / normal / fast fee tier picker, for the chains that price them apart — one
// joined segment divided by one-pixel gaps, the selected tier inverted. The same control
// the receive screen's asset chips use, because a choice-of-one looks the same everywhere.
class FeeSpeedSelector extends StatelessWidget {
  const FeeSpeedSelector({super.key, required this.selected, required this.onSelect});
  final FeeSpeed selected;
  final void Function(FeeSpeed) onSelect;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.border, border: kHairline()),
      child: Row(children: [
        for (final (i, spd) in FeeSpeed.values.indexed) ...[
          if (i > 0) const SizedBox(width: 1),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(spd),
              child: AnimatedContainer(
                duration: kControl,
                curve: kEase,
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: spd == selected ? AppColors.textPrimary : AppColors.background,
                child: Text(
                  switch (spd) {
                    FeeSpeed.slow => 'SLOW',
                    FeeSpeed.normal => 'NORMAL',
                    FeeSpeed.fast => 'FAST',
                  },
                  textAlign: TextAlign.center,
                  style: kLabel(
                    spd == selected ? AppColors.background : AppColors.textTertiary,
                    size: 9,
                    tracking: 0.14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
