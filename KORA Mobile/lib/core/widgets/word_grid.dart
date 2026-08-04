import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

/// The recovery phrase as the prototype draws it: a three-column grid whose cells are
/// separated by one-pixel gaps of the border colour — the same construction as the keypad,
/// because it is the same language — each word numbered 01…12 in mono.
///
/// Until [revealed] the words are blurred behind a veil reading TAP TO REVEAL. One widget
/// for both places a phrase appears: writing it down during creation, and reading it back
/// from settings.
class WordGrid extends StatelessWidget {
  const WordGrid({
    super.key,
    required this.words,
    required this.revealed,
    required this.onReveal,
  });

  final List<String> words;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: revealed ? null : onReveal,
      pressScale: 0.99,
      child: Stack(children: [
        Container(
          decoration: BoxDecoration(color: AppColors.border, border: kHairline()),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.7,
              crossAxisSpacing: 1,
              mainAxisSpacing: 1,
            ),
            itemCount: words.length,
            itemBuilder: (_, i) => Container(
              color: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text((i + 1).toString().padLeft(2, '0'),
                      style: kMonoText(AppColors.textTertiary, size: 9)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(words[i],
                        overflow: TextOverflow.ellipsis,
                        style: kMonoText(AppColors.textPrimary, size: 10.5)),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!revealed)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: AppColors.background.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.visibility_outlined,
                          color: AppColors.textPrimary, size: 20),
                      const SizedBox(height: 10),
                      Text('TAP TO REVEAL',
                          style: kLabel(AppColors.textPrimary, size: 10, tracking: 0.16)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
