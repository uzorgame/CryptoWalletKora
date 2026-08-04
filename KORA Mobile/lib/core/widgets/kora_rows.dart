import 'package:flutter/material.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

/// The prototype's table, as widgets.
///
/// Every screen in this wallet is built from the same four pieces — a section heading, a
/// hairline row, a label-and-value row, and an edged warning bar. Their measurements live
/// here once, taken straight from the prototype's stylesheet, so no screen can drift from
/// its neighbour by a pixel:
///
///   .ksec   padding 24 / 22 / 10, heading mono 11px at .18em, aside mono 9.5px at .1em
///   .krow   padding 13 / 22, one hairline under each
///   .krsym  mono 12.5px w500 at .06em      .krsub  mono 10px, 4px below
///   .krqty  display 13.5px                 .krval  mono 10px, 4px below
///   .kwarn  margin 22, 2px coloured left edge, mono 9.5px at .08em, line 1.8

// ─── Section heading ────────────────────────────────────────────────────────────────────

/// `Assets`, `Details`, `Transactions` — the heading over a table, with an optional aside
/// at the right edge (`16 POSITIONS · SORT`, `3 TOTAL`).
class KoraSection extends StatelessWidget {
  const KoraSection(
    this.title, {
    super.key,
    this.aside,
    this.onAsideTap,
    this.asideBright = false,
    this.trailing,
    this.dim = false,
  });

  final String title;
  final String? aside;
  final VoidCallback? onAsideTap;

  /// An aside that is doing something — an active sort — carries full ink.
  final bool asideBright;

  /// An extra control after the aside, e.g. `+ ADD`.
  final Widget? trailing;

  /// Settings' group headings sit quieter than a table's: 9.5px in tertiary ink.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final heading = dim
        ? kLabel(AppColors.textTertiary, size: 9.5, tracking: 0.18)
        : kLabel(AppColors.textPrimary, size: 11, tracking: 0.18);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title.toUpperCase(), style: heading),
          const Spacer(),
          if (aside != null)
            AnimatedTap(
              onTap: onAsideTap,
              child: Text(aside!.toUpperCase(),
                  style: kLabel(
                      asideBright ? AppColors.textPrimary : AppColors.textTertiary,
                      size: 9.5, tracking: 0.1)),
            ),
          if (trailing != null) ...[
            const SizedBox(width: 14),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ─── The row ────────────────────────────────────────────────────────────────────────────

/// One line of a hairline table. Everything else in this file is a particular filling of it.
class KoraRow extends StatelessWidget {
  const KoraRow({
    super.key,
    required this.children,
    this.onTap,
    this.topLine = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
  });

  final List<Widget> children;
  final VoidCallback? onTap;

  /// The first row of a table closes its top edge; the rest inherit the one above.
  final bool topLine;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border(
          top: topLine ? kHairlineSide() : BorderSide.none,
          bottom: kHairlineSide(),
        ),
      ),
      child: Row(children: children),
    );
    if (onTap == null) return row;
    return AnimatedTap(onTap: onTap, pressScale: 0.98, pressOpacity: 0.85, child: row);
  }
}

/// `NETWORK … BITCOIN` — a name at the left, its value in mono at the right. The whole of
/// the Details tables on the asset, transaction and success screens.
class KoraDataRow extends StatelessWidget {
  const KoraDataRow(
    this.label,
    this.value, {
    super.key,
    this.valueColor,
    this.onTap,
    this.copyable = false,
    this.topLine = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  /// Appends the copy glyph the prototype puts after hashes and addresses.
  final bool copyable;
  final bool topLine;

  @override
  Widget build(BuildContext context) {
    return KoraRow(
      onTap: onTap,
      topLine: topLine,
      children: [
        Text(label.toUpperCase(), style: kMonoText(AppColors.textSecondary, size: 10)),
        const Spacer(),
        Flexible(
          child: Text(
            copyable ? '$value ⧉' : value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: kMonoText(valueColor ?? AppColors.textPrimary, size: 11),
          ),
        ),
      ],
    );
  }
}

/// A settings line: a sentence at the left, a value or chevron at the right.
class KoraSettingRow extends StatelessWidget {
  const KoraSettingRow(
    this.label, {
    super.key,
    this.value,
    this.onTap,
    this.chevron = true,
    this.labelColor,
    this.valueColor,
    this.topLine = false,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool chevron;
  final Color? labelColor;
  final Color? valueColor;
  final bool topLine;

  @override
  Widget build(BuildContext context) {
    return KoraRow(
      onTap: onTap,
      topLine: topLine,
      children: [
        Text(label, style: kBody(labelColor ?? AppColors.textPrimary, size: 13.5)),
        const Spacer(),
        if (value != null)
          Text(value!.toUpperCase(),
              style: kMonoText(valueColor ?? AppColors.textSecondary, size: 10)),
        if (chevron) ...[
          if (value != null) const SizedBox(width: 8),
          Text('›', style: kMonoText(AppColors.textSecondary, size: 13)),
        ],
      ],
    );
  }
}

// ─── The warning bar ────────────────────────────────────────────────────────────────────

/// The edged bar every caution in this wallet wears: amber by default, red when the warning
/// is about losing money.
class KoraWarn extends StatelessWidget {
  const KoraWarn(this.text, {super.key, this.danger = false, this.margin});

  final String text;
  final bool danger;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final ink = danger ? AppColors.negative : AppColors.warning;
    return Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.fromLTRB(22, 16, 22, 0),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: ink, width: 2),
          top: kHairlineSide(), right: kHairlineSide(), bottom: kHairlineSide(),
        ),
      ),
      child: Text(text.toUpperCase(),
          style: kLabel(ink, size: 9.5, tracking: 0.08, weight: FontWeight.w400)
              .copyWith(height: 1.8)),
    );
  }
}

// ─── Small parts ────────────────────────────────────────────────────────────────────────

/// A hairline square holding a letter — the avatar in the address book and wallet lists.
///
/// The prototype's `.kmark.kbox`: 36 by 36 with a 1px border, the letter set in the display
/// face at 700 and 14px. Not a circle with a coloured fill; a square with a hairline, like
/// everything else here.
class KoraBox extends StatelessWidget {
  const KoraBox(this.letter, {super.key, this.size = 36, this.dim = false});

  final String letter;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(border: kHairline()),
      child: Text(letter.toUpperCase(),
          style: TextStyle(
            fontFamily: kDisplay,
            fontFamilyFallback: const [kSans],
            fontWeight: FontWeight.w700,
            fontSize: size * (14 / 36) * kTextScale,
            height: 1,
            color: dim ? AppColors.textTertiary : AppColors.textPrimary,
          )),
    );
  }
}

/// A hairline caption — the network beside a saved address.
class KoraTag extends StatelessWidget {
  const KoraTag(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(border: kHairline()),
        child: Text(text.toUpperCase(),
            style: kLabel(AppColors.textTertiary, size: 8, tracking: 0.1,
                weight: FontWeight.w400)),
      );
}

/// The centred, tappable link the prototype puts under a summary — `VIEW IN EXPLORER ↗`.
class KoraLink extends StatelessWidget {
  const KoraLink(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedTap(
        onTap: onTap,
        pressOpacity: 0.7,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(label.toUpperCase(),
                style: kLabel(AppColors.textSecondary, size: 10, tracking: 0.14)),
          ),
        ),
      );
}

/// The joined segment — one choice of several, the chosen cell inverted. Receive's asset
/// chips, add-token's networks, the fee tiers.
class KoraSegment extends StatelessWidget {
  const KoraSegment({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.scrollable = true,
    this.margin = const EdgeInsets.fromLTRB(22, 14, 22, 0),
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool scrollable;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (final (i, label) in labels.indexed) {
      if (i > 0) cells.add(const SizedBox(width: 1));
      final on = i == selected;
      final cell = AnimatedTap(
        onTap: () => onSelect(i),
        pressScale: 0.96,
        child: AnimatedContainer(
          duration: kControl,
          curve: kEase,
          constraints: const BoxConstraints(minWidth: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          alignment: Alignment.center,
          color: on ? AppColors.textPrimary : AppColors.background,
          child: Text(label.toUpperCase(),
              style: kLabel(on ? AppColors.background : AppColors.textTertiary,
                  size: 9.5, tracking: 0.1)),
        ),
      );
      cells.add(scrollable ? cell : Expanded(child: cell));
    }

    final strip = Container(
      margin: margin,
      decoration: BoxDecoration(color: AppColors.border, border: kHairline()),
      child: scrollable
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(child: Row(children: cells)),
            )
          : IntrinsicHeight(child: Row(children: cells)),
    );
    return strip;
  }
}
