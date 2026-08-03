import 'package:flutter/material.dart';

import '../common/smooth_scroll.dart';

import '../../core/theme/kora_design.dart';
import '../../core/widgets/kora_mark.dart';
import '../../core/widgets/kora_rise.dart';
import '../common/kora_button.dart';

/// The frame every onboarding step sits in.
///
/// It covers the whole window rather than floating over it: on a first run there is nothing
/// behind to go back to, and a dialog implies otherwise.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.note,
    required this.step,
    required this.stepCount,
    required this.child,
    this.showMark = false,
    this.actions = const [],
  });

  final String title;
  final String note;

  /// Zero-based position in the flow, for the progress marks.
  final int step;
  final int stepCount;

  final Widget child;

  /// Shown on the first and last steps, where the app is introducing or congratulating
  /// itself rather than asking for something.
  final bool showMark;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return Material(
      color: p.bg,
      child: Column(
        children: [
          Expanded(
            child: SmoothScrollView(
              padding: const EdgeInsets.all(34),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showMark) ...[
                      _MarkIntro(color: p.text),
                      const SizedBox(height: 22),
                    ],
                    Rise(
                      generation: 0,
                      delay: const Duration(milliseconds: 100),
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: koraNumeric(p.text, size: 26, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Rise(
                      generation: 0,
                      delay: const Duration(milliseconds: 180),
                      duration: const Duration(milliseconds: 500),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Text(
                          note,
                          textAlign: TextAlign.center,
                          style: koraLabel(p.text3, size: 10, tracking: 0.1)
                              .copyWith(height: 1.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Rise(
                      generation: 0,
                      delay: const Duration(milliseconds: 260),
                      duration: const Duration(milliseconds: 500),
                      child: child,
                    ),
                    const SizedBox(height: 22),
                    _Progress(step: step, stepCount: stepCount),
                  ],
                ),
              ),
            ),
          ),
          if (actions.isNotEmpty) _Footer(actions: actions),
        ],
      ),
    );
  }
}

class _MarkIntro extends StatefulWidget {
  const _MarkIntro({required this.color});

  final Color color;

  @override
  State<_MarkIntro> createState() => _MarkIntroState();
}

class _MarkIntroState extends State<_MarkIntro> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _in,
        builder: (context, _) {
          final t = kEase.transform(_in.value);
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.86 + 0.14 * t,
              child: KoraMark(size: 54, color: widget.color),
            ),
          );
        },
      );
}

/// How far along the flow is. Short marks rather than "step 2 of 5", because the count
/// matters less than the sense that it is nearly over.
class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.stepCount});

  final int step;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < stepCount; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: kControl,
            curve: kEase,
            width: 22,
            height: 2,
            color: i <= step ? p.text : p.border,
          ),
        ],
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.border,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) const SizedBox(width: 1),
            Expanded(child: action),
          ],
        ],
      ),
    );
  }
}

/// A footer slot that holds no action — keeps the buttons at the ends of the bar rather than
/// bunched in the middle when there is only one of them.
class OnboardingSpacer extends StatelessWidget {
  const OnboardingSpacer({super.key, this.flex = 2});

  final int flex;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Kora.of(context).bg, child: const SizedBox(height: 44));
}

/// The standard pair of footer buttons.
class OnboardingActions {
  const OnboardingActions._();

  static Widget back(VoidCallback onTap) =>
      KoraButton(label: 'BACK', expand: true, onPressed: onTap);

  static Widget next(String label, VoidCallback? onTap) =>
      KoraButton(label: label, expand: true, tone: KoraButtonTone.primary, onPressed: onTap);
}
