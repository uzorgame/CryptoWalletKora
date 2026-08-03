import 'package:flutter/material.dart';

import '../format.dart';
import '../services/market_service.dart';
import '../theme.dart';
import '../widgets/rise.dart';
import '../widgets/sparkline.dart';

/// Twenty cards in four columns and five rows, sized to fill the stage exactly.
///
/// Laid out by content the grid overran the window by fourteen pixels — enough to put a
/// scrollbar on a view with nothing below the fold, which reads as a page that failed to fit
/// rather than one that was designed to.
class MarketGrid extends StatelessWidget {
  const MarketGrid({
    super.key,
    required this.beat,
    required this.entrance,
    required this.onOpen,
  });

  final int beat;
  final int entrance;
  final void Function(String symbol) onOpen;

  static const _columns = 4;

  /// Twenty-two milliseconds apart, so the grid assembles rather than snapping into place.
  static const _stagger = Duration(milliseconds: 22);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final coins = MarketService.instance.coins.values.toList();
    final rows = (coins.length / _columns).ceil();

    return Container(
      color: p.border, // the one-pixel gaps below let this show through as hairlines
      child: Column(
        children: [
          for (var r = 0; r < rows; r++) ...[
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < _columns; c++) ...[
                    Expanded(
                      child: Builder(builder: (context) {
                        final i = r * _columns + c;
                        if (i >= coins.length) return ColoredBox(color: p.surface);
                        return Rise(
                          generation: entrance,
                          delay: _stagger * i,
                          child: _CoinCard(
                            coin: coins[i],
                            beat: beat,
                            onTap: () => onOpen(coins[i].symbol),
                          ),
                        );
                      }),
                    ),
                    if (c < _columns - 1) const SizedBox(width: 1),
                  ],
                ],
              ),
            ),
            if (r < rows - 1) const SizedBox(height: 1),
          ],
        ],
      ),
    );
  }
}

/// The rank and the open-arrow occupy the same corner, cross-fading as the pointer arrives.
/// The arrow also slides the last two pixels into place, which is what stops it reading as a
/// label that simply swapped.
class _RankOrArrow extends StatelessWidget {
  const _RankOrArrow({required this.hover, required this.rank, required this.ink});

  final Animation<double> hover;
  final int rank;
  final Color ink;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: hover,
        builder: (context, _) {
          final t = kEase.transform(hover.value);
          return SizedBox(
            width: 16,
            height: 12,
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                Opacity(
                  opacity: 1 - t,
                  child: Text(rank.toString().padLeft(2, '0'), style: label(ink, size: 10)),
                ),
                Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(-2 * (1 - t), 2 * (1 - t)),
                    child: Icon(Icons.north_east, size: 11, color: ink),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _CoinCard extends StatefulWidget {
  const _CoinCard({required this.coin, required this.beat, required this.onTap});

  final Coin coin;
  final int beat;
  final VoidCallback onTap;

  @override
  State<_CoinCard> createState() => _CoinCardState();
}

class _CoinCardState extends State<_CoinCard> with TickerProviderStateMixin {
  /// Parked at the end of its travel, because one means "no tint left". Starting at zero
  /// would paint every card fully flashed on its very first frame.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: 1,
  );

  /// Hover is a transition in the prototype, not a switch — the card warms and the arrow
  /// slides in. Snapping between the two states loses the whole feel of the grid.
  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void didUpdateWidget(_CoinCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Comparing the beat rather than the price keeps the decision out of build(), where it
    // would fire again on every unrelated rebuild — a hover, a resize, a theme switch.
    if (widget.beat != oldWidget.beat && widget.coin.changed) {
      _flash.forward(from: 0);
    }
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
    final delta = coin.delta;

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
            final warm = kEase.transform(_hover.value);
            final base = Color.lerp(p.surface, p.surfaceHi, warm)!;
            // A coin that did not move must not flash: a flash on an unchanged number reads
            // as movement that never happened. Stablecoins sit still, and should look it.
            final tint = coin.rising ? p.flashUp : p.flashDown;
            return ColoredBox(
              color: _flash.value < 1
                  ? Color.lerp(tint, base, Curves.easeOut.transform(_flash.value))!
                  : base,
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(coin.symbol, style: label(p.text, size: 13, tracking: 0.06)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(coin.name,
                          style: body(p.text3), overflow: TextOverflow.ellipsis),
                    ),
                    // The rank gives way to an arrow on hover: the whole card is the target,
                    // and twenty permanent icons would be twenty pieces of furniture saying
                    // the same thing.
                    _RankOrArrow(hover: _hover, rank: coin.rank, ink: p.text3),
                  ],
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(money(coin.price), style: numeric(p.text, size: 25)),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(pct(delta), style: label(p.direction(delta), size: 11, tracking: 0)),
                    const Spacer(),
                    // The line and the percentage answer different questions: a month of
                    // direction beside a day of change. Unlabelled they contradict each other
                    // on any coin that fell today inside a rising month.
                    Text('30D', style: label(p.text3, size: 8.5, tracking: 0.1)),
                    const SizedBox(width: 8),
                    Sparkline(values: coin.history, up: p.up, down: p.down),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
