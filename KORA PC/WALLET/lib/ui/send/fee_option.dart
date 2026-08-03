import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';
import '../../core/state/providers/currency_provider.dart';
import '../format/currency_format.dart';
import '../format/money.dart';

/// Where a tier's estimate has got to.
///
/// Three states, not two. Collapsing "still asking" and "the chain would not say" into one
/// empty value is how a fee ends up as a permanent dash that nobody can tell from a slow
/// network — which is exactly what happened here.
enum FeeStatus { loading, ready, unavailable }

/// One fee choice, as offered to the user.
///
/// The estimate and the wait are shown together because neither means much alone: a cheap fee
/// that confirms tomorrow and an instant one that costs more are the same decision seen from
/// two sides.
@immutable
class FeeOption {
  const FeeOption({
    required this.id,
    required this.label,
    required this.wait,
    required this.cost,
    this.status = FeeStatus.ready,
    this.native,
    this.symbol,
  });

  final String id;
  final String label;

  /// How long this tier is expected to take, in words — "~10 min".
  final String wait;

  /// The estimate in USD, or null where the chain cannot say yet.
  final double? cost;

  final FeeStatus status;

  /// The fee in the chain's own coin, which is what actually leaves the wallet. The converted
  /// figure is the one people compare; this is the one that is true.
  final double? native;

  /// Ticker for [native] — 'TRX', 'ETH'.
  final String? symbol;
}

/// The fee tiers, side by side.
class FeePicker extends StatelessWidget {
  const FeePicker({
    super.key,
    required this.options,
    required this.selectedId,
    required this.money,
    required this.onSelect,
  });

  final List<FeeOption> options;
  final String selectedId;
  final CurrencyState money;
  final ValueChanged<FeeOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return Container(
      color: p.border,
      child: Row(
        children: [
          for (final (i, option) in options.indexed) ...[
            if (i > 0) const SizedBox(width: 1),
            Expanded(
              child: _FeeCell(
                option: option,
                selected: option.id == selectedId,
                money: money,
                onTap: () => onSelect(option),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeeCell extends StatefulWidget {
  const _FeeCell({
    required this.option,
    required this.selected,
    required this.money,
    required this.onTap,
  });

  final FeeOption option;
  final bool selected;
  final CurrencyState money;
  final VoidCallback onTap;

  @override
  State<_FeeCell> createState() => _FeeCellState();
}

class _FeeCellState extends State<_FeeCell> {
  bool _hover = false;

  /// What the cell says under its label, in each of the three states.
  ///
  /// "Estimating…" is a promise that a number is coming; "Unavailable" says it is not. Both
  /// beat a dash, which says nothing and looks identical to a bug.
  String _value(FeeOption o) => switch (o.status) {
        FeeStatus.loading => 'Estimating…',
        FeeStatus.unavailable => 'Unavailable',
        // A fee of exactly zero is not a free transaction — it is a converted figure whose
        // price lookup came back empty, and `feeInUsd` defaults to 0 when that happens.
        // Printing "$0.00" beside a signing button states something about the user's money
        // that nobody checked. The chain's own amount is shown underneath either way.
        FeeStatus.ready => switch (o.cost) {
            null => o.wait.isEmpty ? '—' : o.wait,
            0 => o.wait.isEmpty ? 'Price unknown' : '${o.wait} · price unknown',
            _ => '${o.wait} · ${widget.money.format(o.cost)}',
          },
      };

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final o = widget.option;
    final background = widget.selected ? p.text : (_hover ? p.surfaceHi : p.surface);
    final labelInk = widget.selected ? p.bg : p.text3;
    final valueInk = widget.selected ? p.bg : p.text2;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: kControl,
          curve: kEase,
          color: background,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: kControl,
                curve: kEase,
                style: koraLabel(labelInk, size: 9.5, tracking: 0.12),
                child: Text(o.label),
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: kControl,
                curve: kEase,
                style: koraLabel(valueInk, size: 11, tracking: 0),
                child: Text(_value(o)),
              ),
              if (o.status == FeeStatus.ready && o.native != null && o.symbol != null) ...[
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: kControl,
                  curve: kEase,
                  style: koraLabel(
                    widget.selected ? p.bg.withValues(alpha: 0.62) : p.text3,
                    size: 9,
                    tracking: 0,
                  ),
                  child: Text('${quantity(o.native!)} ${o.symbol}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
