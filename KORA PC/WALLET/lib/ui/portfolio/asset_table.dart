import 'package:flutter/material.dart';

import '../../core/models/asset.dart';
import '../../core/theme/kora_design.dart';
import '../../core/widgets/kora_rise.dart';
import '../../core/state/providers/currency_provider.dart';
import 'asset_row.dart';

/// The holdings, with a heading that shares its geometry with the rows beneath it.
///
/// A box rather than a sliver, unlike the movement table: a wallet holds tens of assets, not
/// hundreds, and the chart above it has to scroll with it either way.
class AssetTable extends StatelessWidget {
  const AssetTable({
    super.key,
    required this.assets,
    required this.money,
    required this.onOpen,
    required this.entrance,
    this.hidden = false,
  });

  final List<Asset> assets;
  final CurrencyState money;
  final ValueChanged<Asset> onOpen;

  /// Bumped when the view is entered, to replay the staggered arrival.
  final int entrance;

  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return Container(
      decoration: BoxDecoration(border: Border.all(color: p.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.bgAlt,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: AssetColumns.row(
              chainCell: _heading(p, 'NETWORK'),
              assetCell: _heading(p, 'ASSET'),
              quantityCell: _heading(p, 'HOLDINGS'),
              priceCell: _heading(p, 'PRICE'),
              valueCell: _heading(p, 'VALUE'),
              changeCell: _heading(p, '24H'),
            ),
          ),
          for (final (i, asset) in assets.indexed)
            if (i >= kStaggeredRows)
              AssetRow(asset: asset, money: money, hidden: hidden, onOpen: () => onOpen(asset))
            else
              Rise(
                generation: entrance,
                delay: kRowStagger * i,
                duration: kRowRise,
                child: AssetRow(
                  asset: asset,
                  money: money,
                  hidden: hidden,
                  onOpen: () => onOpen(asset),
                ),
              ),
        ],
      ),
    );
  }

  Widget _heading(Kora p, String text) =>
      Text(text, style: koraLabel(p.text3, size: 9.5, tracking: 0.12));
}
