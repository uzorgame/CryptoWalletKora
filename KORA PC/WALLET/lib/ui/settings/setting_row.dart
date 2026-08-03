import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';

/// One setting: what it is, what it does, and the control that changes it.
///
/// The description is not optional. A row that only names a setting makes the reader guess
/// what turning it on will do, and in a wallet that guess is sometimes about their money.
class SettingRow extends StatefulWidget {
  const SettingRow({
    super.key,
    required this.title,
    required this.description,
    required this.control,
    this.last = false,
  });

  final String title;
  final String description;
  final Widget control;
  final bool last;

  @override
  State<SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<SettingRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: kHoverFast,
        curve: kEase,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: _hover ? p.surfaceHi : p.surface,
          border: widget.last ? null : Border(bottom: BorderSide(color: p.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.title,
                      style: koraBody(p.text, size: 12.5, weight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(widget.description,
                      style: koraBody(p.text3, size: 11).copyWith(height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 24),
            widget.control,
          ],
        ),
      ),
    );
  }
}

/// A read-only value, for rows that state a fact rather than offer a choice.
class SettingValue extends StatelessWidget {
  const SettingValue(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: koraLabel(Kora.of(context).text2, size: 11, tracking: 0));
}
