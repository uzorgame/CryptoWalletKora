import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/smooth_scroll.dart';

import '../../core/models/asset.dart';
import '../../core/services/tx_history_service.dart';
import '../../core/theme/kora_design.dart';
import '../common/kora_button.dart';
import '../common/section_header.dart';
import '../format/chain_display.dart';
import '../../core/state/providers/currency_provider.dart';
import '../format/currency_format.dart';
import '../format/money.dart';
import '../history/movement_table.dart';
import 'coin_facts.dart';

/// One asset: what is held, what it cost, and everything that ever moved it.
///
/// Send and receive live here rather than on the portfolio, because this is the first place
/// in the app where "which coin?" has an answer.
class CoinView extends StatelessWidget {
  const CoinView({
    super.key,
    required this.asset,
    required this.history,
    required this.walletName,
    required this.money,
    required this.entrance,
    required this.onBack,
    required this.onSend,
    required this.onReceive,
    this.onRetryHistory,
  });

  final Asset asset;

  /// This coin's movements as the provider holds them, handed to the table unopened so that a
  /// chain which refused the request is not shown as a coin that has never moved.
  final AsyncValue<List<TxRecord>> history;

  final String walletName;
  final CurrencyState money;
  final int entrance;

  final VoidCallback onBack;
  final VoidCallback onSend;
  final VoidCallback onReceive;

  final VoidCallback? onRetryHistory;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final a = asset;
    final held = a.balanceAsDouble;
    final chain = a.chain;
    final rows = history.valueOrNull;

    return SmoothScrollView.slivers(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _BackButton(onTap: onBack),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${a.symbol} · ${chain.network}',
                        style: koraLabel(p.text3, size: 9.5, tracking: 0.16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        money.format(a.balanceInUsd),
                        style: koraNumeric(p.text, size: 46, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${quantity(held)} ${a.symbol}',
                      style: koraLabel(p.text2, size: 11, tracking: 0),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '${percent(a.priceChange24h)} · 24H',
                      style: koraLabel(p.direction(a.priceChange24h), size: 12, tracking: 0),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    color: p.border,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KoraButton(
                          label: 'SEND',
                          tone: KoraButtonTone.primary,
                          // Nothing to send is a reason to be unavailable, not a reason to fail
                          // after the form has been filled in.
                          onPressed: held > 0 ? onSend : null,
                        ),
                        const SizedBox(width: 1),
                        KoraButton(label: 'RECEIVE', onPressed: onReceive),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CoinFacts(
                quantityHeld: held,
                price: money.convert(a.priceUsd),
                value: money.convert(a.balanceInUsd),
                network: '${chain.network} (${chain.tag})',
                currencySymbol: money.symbol,
              ),
              const SizedBox(height: 20),
              SectionHeader(
                title: '${a.symbol} TRANSACTIONS',
                // Stated only once the chain has answered. A count is a claim about how many
                // movements there are, and a request that failed supports no such claim.
                aside: rows == null || rows.isEmpty ? null : '${rows.length}',
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        MovementTable(
          history: history,
          walletName: walletName,
          money: money,
          entrance: entrance,
          onRetry: onRetryHistory,
          emptyMessage: 'NO ${a.symbol} TRANSACTIONS YET',
        ),
      ],
    );
  }
}

/// The coin page is reached from the portfolio and returns to it, so the way back is stated
/// rather than left to the rail — the rail never moved.
class _BackButton extends StatefulWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final ink = _hover ? p.text : p.text3;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      opaque: true,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: 0.7854,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: ink),
                    bottom: BorderSide(color: ink),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            AnimatedDefaultTextStyle(
              duration: kControl,
              curve: kEase,
              style: koraLabel(ink, size: 10, tracking: 0.14),
              child: const Text('PORTFOLIO'),
            ),
          ],
        ),
      ),
    );
  }
}
