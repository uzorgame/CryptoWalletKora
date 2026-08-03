import 'package:flutter/material.dart';

import '../../core/models/asset.dart';
import '../../core/theme/kora_design.dart';
import '../format/chain_display.dart';
import '../../core/state/providers/currency_provider.dart';
import '../format/currency_format.dart';
import '../format/money.dart';

/// The column geometry, in one place.
///
/// The header and the rows both read from this, so a column cannot drift out of alignment
/// with its own heading.
class AssetColumns {
  const AssetColumns._();

  static const double chain = 66;
  static const int asset = 5;
  static const int quantity = 4;
  static const int price = 4;
  static const int value = 4;
  static const double change = 74;
  static const double gutter = 12;

  static Widget row({
    required Widget chainCell,
    required Widget assetCell,
    required Widget quantityCell,
    required Widget priceCell,
    required Widget valueCell,
    required Widget changeCell,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        SizedBox(width: chain, child: chainCell),
        const SizedBox(width: gutter),
        Expanded(flex: asset, child: assetCell),
        const SizedBox(width: gutter),
        Expanded(flex: quantity, child: quantityCell),
        const SizedBox(width: gutter),
        Expanded(
          flex: price,
          child: Align(alignment: Alignment.centerRight, child: priceCell),
        ),
        const SizedBox(width: gutter),
        Expanded(
          flex: value,
          child: Align(alignment: Alignment.centerRight, child: valueCell),
        ),
        const SizedBox(width: gutter),
        SizedBox(
          width: change,
          child: Align(alignment: Alignment.centerRight, child: changeCell),
        ),
      ],
    ),
  );
}

/// One asset the wallet holds or watches. Clicking it opens that coin.
class AssetRow extends StatefulWidget {
  const AssetRow({
    super.key,
    required this.asset,
    required this.money,
    required this.onOpen,
    this.hidden = false,
  });

  final Asset asset;
  final CurrencyState money;
  final VoidCallback onOpen;
  final bool hidden;

  static const double height = 54;

  @override
  State<AssetRow> createState() => _AssetRowState();
}

class _AssetRowState extends State<AssetRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final a = widget.asset;
    final held = a.balanceAsDouble;
    // An empty position stays legible but recedes: it is a coin being watched, not held.
    final muted = held <= 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: kHoverFast,
          curve: kEase,
          height: AssetRow.height,
          decoration: BoxDecoration(
            color: _hover ? p.surfaceHi : p.surface,
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: AssetColumns.row(
            chainCell: _ChainTag(label: a.chainTag),
            assetCell: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(a.symbol, style: koraLabel(p.text, size: 12, tracking: 0.06)),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(a.name, style: koraBody(p.text3), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            quantityCell: Text(
              widget.hidden ? '••••' : '${quantity(held)} ${a.symbol}',
              style: koraLabel(muted ? p.text3 : p.text2, size: 11.5, tracking: 0),
              overflow: TextOverflow.ellipsis,
            ),
            priceCell: Text(widget.money.format(a.priceUsd), style: koraNumeric(p.text, size: 14)),
            valueCell: Text(
              widget.hidden ? '••••' : widget.money.format(a.balanceInUsd),
              style: koraNumeric(muted ? p.text3 : p.text, size: 15),
            ),
            changeCell: Text(
              percent(a.priceChange24h),
              style: koraLabel(p.direction(a.priceChange24h), size: 11, tracking: 0),
            ),
          ),
        ),
      ),
    );
  }
}

/// The chain a holding lives on. Small, bordered, and never abbreviated away — it is the
/// difference between an address that works and funds that are gone.
class _ChainTag extends StatelessWidget {
  const _ChainTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(border: Border.all(color: p.border)),
        child: Text(label, style: koraLabel(p.text3, size: 8.5, tracking: 0.1)),
      ),
    );
  }
}
