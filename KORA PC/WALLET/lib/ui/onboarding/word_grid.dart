import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';

/// Twelve numbered words on a grid — the shape people already expect to copy down.
class WordGrid extends StatelessWidget {
  const WordGrid.display({super.key, required this.words})
      : controllers = null,
        onPaste = null,
        highlight = const {};

  /// The editable variant, for restoring a wallet.
  const WordGrid.input({
    super.key,
    required this.controllers,
    required this.onPaste,
    this.highlight = const {},
  }) : words = const [];

  final List<String> words;
  final List<TextEditingController>? controllers;

  /// Pasting a whole phrase into any box should fill the rest, because that is how a phrase
  /// arrives from a password manager.
  final void Function(int index, String value)? onPaste;

  /// Positions to mark as wrong.
  final Set<int> highlight;

  static const int _columns = 3;
  static const double width = 520;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final count = controllers?.length ?? words.length;
    final rows = (count / _columns).ceil();

    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(color: p.border, border: Border.all(color: p.border)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) const SizedBox(height: 1),
              Row(
                children: [
                  for (var c = 0; c < _columns; c++) ...[
                    if (c > 0) const SizedBox(width: 1),
                    Expanded(
                      child: r * _columns + c < count
                          ? _Word(
                              index: r * _columns + c,
                              word: controllers == null ? words[r * _columns + c] : null,
                              controller: controllers?[r * _columns + c],
                              onPaste: onPaste,
                              wrong: highlight.contains(r * _columns + c),
                            )
                          : ColoredBox(color: p.surface, child: const SizedBox(height: 39)),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({
    required this.index,
    required this.word,
    required this.controller,
    required this.onPaste,
    required this.wrong,
  });

  final int index;
  final String? word;
  final TextEditingController? controller;
  final void Function(int index, String value)? onPaste;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return Container(
      color: wrong ? p.flashDown : p.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 16,
            child: Text(
              (index + 1).toString().padLeft(2, '0'),
              style: koraLabel(p.text3, size: 9, tracking: 0),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: controller == null
                ? Text(word!, style: koraLabel(p.text, size: 12, tracking: 0.04))
                : TextField(
                    controller: controller,
                    style: koraLabel(p.text, size: 12, tracking: 0.04),
                    cursorColor: p.text,
                    cursorWidth: 1,
                    cursorRadius: Radius.zero,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) => onPaste?.call(index, value),
                  ),
          ),
        ],
      ),
    );
  }
}
