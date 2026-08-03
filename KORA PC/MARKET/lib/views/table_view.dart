import 'package:flutter/material.dart';

import '../format.dart';
import '../services/market_service.dart';
import '../theme.dart';
import '../widgets/rise.dart';

/// The same market as a table. A row is a way into the chart; that is the only thing anyone
/// wants from a price they have just noticed moving.
class TableView extends StatelessWidget {
  const TableView({
    super.key,
    required this.beat,
    required this.entrance,
    required this.onOpen,
  });

  final int beat;
  final int entrance;
  final void Function(String symbol) onOpen;

  /// Tighter and shorter than the grid's: rows are closer together, so the same interval
  /// would read as a slow crawl down the page rather than one gesture.
  static const _stagger = Duration(milliseconds: 16);
  static const _riseDuration = Duration(milliseconds: 420);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final coins = MarketService.instance.coins.values.toList();

    return Column(
      children: [
        Container(
          height: 34,
          decoration: BoxDecoration(
            color: p.bgAlt,
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: _Row(
            index: Text('#', style: label(p.text3, size: 10)),
            coin: Text('COIN', style: label(p.text3, size: 10)),
            price: Text('PRICE', style: label(p.text3, size: 10)),
            delta: Text('24H', style: label(p.text3, size: 10)),
            volume: Text('VOLUME 24H', style: label(p.text3, size: 10)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: coins.length,
            itemExtent: 44,
            itemBuilder: (context, i) => Rise(
              generation: entrance,
              delay: _stagger * i,
              duration: _riseDuration,
              child: _CoinRow(
                coin: coins[i],
                beat: beat,
                onTap: () => onOpen(coins[i].symbol),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One place that decides the column geometry, so the header can never drift off the body.
class _Row extends StatelessWidget {
  const _Row({
    required this.index,
    required this.coin,
    required this.price,
    required this.delta,
    required this.volume,
  });

  final Widget index, coin, price, delta, volume;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            SizedBox(width: 40, child: index),
            Expanded(flex: 5, child: coin),
            Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: price)),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: delta)),
            Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: volume)),
          ],
        ),
      );
}

class _CoinRow extends StatefulWidget {
  const _CoinRow({required this.coin, required this.beat, required this.onTap});

  final Coin coin;
  final int beat;
  final VoidCallback onTap;

  @override
  State<_CoinRow> createState() => _CoinRowState();
}

class _CoinRowState extends State<_CoinRow> with TickerProviderStateMixin {
  /// Parked at one — the end of the fade — so a row is not painted fully tinted on its first
  /// frame, before anything has actually moved.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    value: 1,
  );

  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  @override
  void didUpdateWidget(_CoinRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.beat != oldWidget.beat && widget.coin.changed) _flash.forward(from: 0);
  }

  @override
  void dispose() {
    _flash.dispose();
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final coin = widget.coin;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => _hover.forward(),
      onExit: (_) => _hover.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_flash, _hover]),
          builder: (context, child) {
            final base = Color.lerp(p.bg, p.surfaceHi, kEase.transform(_hover.value))!;
            final tint = coin.rising ? p.flashUp : p.flashDown;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: _flash.value < 1
                    ? Color.lerp(tint, base, Curves.easeOut.transform(_flash.value))!
                    : base,
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              child: child,
            );
          },
          child: _Row(
            index: Text(coin.rank.toString().padLeft(2, '0'), style: label(p.text3, size: 10)),
            coin: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(coin.symbol, style: label(p.text, size: 12, tracking: 0.06)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(coin.name, style: body(p.text3), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            price: Text(money(coin.price), style: numeric(p.text, size: 14)),
            delta: Text(pct(coin.delta),
                style: label(p.direction(coin.delta), size: 11, tracking: 0)),
            volume: Text('\$${compact(coin.volume)}', style: label(p.text2, size: 11, tracking: 0)),
          ),
        ),
      ),
    );
  }
}
