import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';

/// A tracked uppercase label above a field or a block — ASSET, RECIPIENT, AMOUNT.
class KoraSlabel extends StatelessWidget {
  const KoraSlabel(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(22, 18, 22, 8)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Text(text.toUpperCase(),
            style: kLabel(AppColors.textTertiary, size: 9.5, tracking: 0.16)),
      );
}

/// A hairline input frame. The border brightens while anything inside holds focus — the one
/// sign, in a form of several fields, of where the next keystroke lands. Animated over
/// [kControl] so focus arrives rather than snaps.
class KoraField extends StatefulWidget {
  const KoraField({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    this.margin = const EdgeInsets.symmetric(horizontal: 22),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// The screen's own gutter by default; zero where the field is already inside something
  /// that has its own padding, such as a dialog.
  final EdgeInsetsGeometry margin;

  @override
  State<KoraField> createState() => _KoraFieldState();
}

class _KoraFieldState extends State<KoraField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: AnimatedContainer(
        duration: kControl,
        curve: kEase,
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
              color: _focused ? AppColors.borderHi : AppColors.border, width: 1),
        ),
        child: widget.child,
      ),
    );
  }
}

/// The text style inputs inside a [KoraField] share — mono, slightly spaced.
/// Exactly the prototype's input: 12px mono at .02em.
TextStyle koraInputStyle() =>
    kMonoText(AppColors.textPrimary, size: 12).copyWith(letterSpacing: 0.24);

/// Hint text for those inputs.
TextStyle koraHintStyle() =>
    kMonoText(AppColors.textTertiary, size: 12).copyWith(letterSpacing: 0.24);

/// A bare [InputDecoration] so a TextField inside a [KoraField] brings no Material chrome of
/// its own — the frame is the field's whole appearance.
///
/// Every border state is named explicitly. `border:` alone is only a fallback: the global
/// InputDecorationTheme's enabledBorder and focusedBorder outrank it, which is how every
/// field in the app once wore a second box inside its own frame.
InputDecoration koraInputDecoration(String hint) => const InputDecoration(
      isDense: true,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ).copyWith(hintText: hint, hintStyle: koraHintStyle());
