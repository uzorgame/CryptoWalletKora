import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'smooth_scroll.dart';

import '../../core/theme/kora_design.dart';
import 'kora_button.dart';
import 'tracked_text.dart';

/// A dialog in the system's own shape: square, bordered, and arriving from just below.
///
/// Everything modal in the app goes through here, so a receive code, a transaction and a
/// passphrase prompt cannot end up looking like three different products.
class KoraSheet extends StatelessWidget {
  const KoraSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.actions = const [],
    this.width = 420,
  });

  final String title;
  final String subtitle;

  /// The sheet body. Named for what it is rather than as generic children, which also keeps
  /// it clear that the actions below are not part of it.
  final List<Widget> body;

  /// Laid out as equal columns divided by hairlines, so no action is accidentally weightier
  /// than another by being wider.
  final List<Widget> actions;

  final double width;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    // The body scrolls; the heading and the actions do not.
    //
    // This used to be one Column sized to its contents. A sheet whose body was longer than
    // the window — a transaction with a dozen rows, a recovery phrase — overflowed its own
    // container, and a child laid out past its parent's bounds is painted but not hit-tested.
    // The buttons were visible at the bottom of the screen and dead to the touch, which is
    // why DONE and COPY HASH worked on a short transaction and not on a long one.
    return Center(
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: p.bg,
          border: Border.all(color: p.border),
        ),
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrackedText(title, style: koraLabel(p.text, size: 11, tracking: 0.18)),
            const SizedBox(height: 6),
            TrackedText(subtitle, style: koraLabel(p.text3, size: 9.5, tracking: 0.12)),
            const SizedBox(height: 18),
            // Flexible, not Expanded: a short sheet still hugs its contents rather than
            // stretching to fill the window.
            Flexible(
              child: SmoothScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: body,
                ),
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                color: p.border,
                child: Row(
                  children: [
                    for (final (i, action) in actions.indexed) ...[
                      if (i > 0) const SizedBox(width: 1),
                      Expanded(child: action),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a sheet over the window.
///
/// `barrierDismissible` is off by default: every sheet in this app is either handing over an
/// address or asking for a passphrase, and neither should close because a click landed a
/// little wide.
Future<T?> showKoraSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: const Color(0x9E000000),
    builder: (context) {
      final sheet = Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: _SheetEntrance(child: builder(context)),
      );
      if (!dismissible) return sheet;
      // Escape closes whatever a click outside would have closed, and nothing else. A sheet
      // that can only be dismissed with the mouse is a sheet that traps anyone working from
      // the keyboard — and the one place it must not work is the one place it does not: a
      // passphrase prompt has to be answered or cancelled deliberately.
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
        },
        child: Focus(autofocus: true, child: sheet),
      );
    },
  );
}

class _SheetEntrance extends StatefulWidget {
  const _SheetEntrance({required this.child});

  final Widget child;

  @override
  State<_SheetEntrance> createState() => _SheetEntranceState();
}

class _SheetEntranceState extends State<_SheetEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _in,
    child: widget.child,
    builder: (context, child) {
      final t = kEase.transform(_in.value);
      return Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
      );
    },
  );
}

/// A sheet that only says something and closes.
///
/// Outcomes are reported in the same frame the action was requested in, rather than as a
/// toast that slides away before it has been read. A recovery phrase in particular has to
/// stay on screen until the user chooses to dismiss it.
class KoraNotice extends StatelessWidget {
  const KoraNotice({super.key, required this.title, required this.body, this.mono = false});

  final String title;
  final String body;

  /// Set for anything that must be transcribed exactly — a recovery phrase, an address, a
  /// hash. Proportional type makes those genuinely harder to copy down correctly.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return KoraSheet(
      title: title,
      subtitle: 'KORA',
      body: [
        SelectableText(
          body,
          textAlign: TextAlign.center,
          style: mono
              ? koraNumeric(p.text, size: 13).copyWith(height: 1.9, letterSpacing: 0.6)
              : koraLabel(p.text3, size: 9.5, tracking: 0).copyWith(height: 1.6),
        ),
      ],
      actions: [
        KoraButton(label: 'CLOSE', expand: true, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
