import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';

/// A labelled input with a hint beneath it.
///
/// The hint is where a field says what it will and will not accept, and where it says what
/// went wrong. Keeping both in the same place means an error never appears somewhere the eye
/// was not already looking.
class KoraField extends StatelessWidget {
  const KoraField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.placeholder,
    this.obscure = false,
    this.autofocus = false,
    this.readOnly = false,
    this.error = false,
    this.centred = false,
    this.onSubmitted,
    this.trailing,
  });

  final String label;
  final TextEditingController controller;

  /// Guidance, or the reason the current value is not acceptable.
  final String? hint;

  final String? placeholder;
  final bool obscure;
  final bool autofocus;
  final bool readOnly;

  /// Colours the hint as a problem rather than as advice.
  final bool error;

  /// Centres the label, the value and the hint.
  ///
  /// For a screen built around a single field. Left-aligned parts under two centred headings
  /// read as a block that is out of true even when every element is where it was put — which
  /// is exactly how the lock screen looked.
  final bool centred;

  final ValueChanged<String>? onSubmitted;

  /// An action that belongs to the value rather than to the form — MAX on an amount.
  ///
  /// Inside the frame, so it reads as part of the field it fills in rather than as a control
  /// that happens to sit next to it.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return Column(
      crossAxisAlignment: centred ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          textAlign: centred ? TextAlign.center : TextAlign.start,
          style: koraLabel(p.text3, size: 9.5, tracking: 0.14),
        ),
        const SizedBox(height: 7),
        _FocusFrame(
          child: Row(
            children: [
              Expanded(child: _input(p)),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 7),
          Text(
            hint!,
            textAlign: centred ? TextAlign.center : TextAlign.start,
            style: koraLabel(error ? p.down : p.text3, size: 9.5, tracking: 0),
          ),
        ],
      ],
    );
  }

  Widget _input(Kora p) => TextField(
    controller: controller,
    obscureText: obscure,
    autofocus: autofocus,
    readOnly: readOnly,
    onSubmitted: onSubmitted,
    textAlign: centred ? TextAlign.center : TextAlign.start,
    cursorColor: p.text,
    cursorWidth: 1,
    cursorRadius: Radius.zero,
    style: koraLabel(p.text, size: 12.5, tracking: 0),
    decoration: InputDecoration(
      isDense: true,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      hintText: placeholder,
      hintStyle: koraLabel(p.text3, size: 12.5, tracking: 0),
    ),
  );
}

/// The border brightens on focus. A field that gives no sign of being focused makes a form
/// with several of them a guessing game about where the next keystroke lands.
class _FocusFrame extends StatefulWidget {
  const _FocusFrame({required this.child});

  final Widget child;

  @override
  State<_FocusFrame> createState() => _FocusFrameState();
}

class _FocusFrameState extends State<_FocusFrame> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: AnimatedContainer(
        duration: kControl,
        curve: kEase,
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: _focused ? p.borderHi : p.border),
        ),
        child: widget.child,
      ),
    );
  }
}
