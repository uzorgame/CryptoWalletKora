import 'package:flutter/material.dart';

import '../../core/theme/kora_design.dart';
import '../common/kora_button.dart';

/// What a wallet with no history shows instead of a chart.
///
/// An empty frame and a dash read as something that failed to load. A wallet that has never
/// been funded has a reason for being empty, and saying it is both kinder and more accurate.
class EmptyWallet extends StatelessWidget {
  const EmptyWallet({super.key, required this.symbol, required this.onReceive});

  /// The coin the receive action will open on — the first the wallet tracks.
  final String symbol;

  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('NOTHING HERE YET', style: koraLabel(p.text2, size: 11, tracking: 0.18)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'This wallet has no transactions. Receive to any of its addresses and the '
              'balance and its history start from there.',
              textAlign: TextAlign.center,
              style: koraBody(p.text3, size: 12).copyWith(height: 1.6),
            ),
          ),
          const SizedBox(height: 18),
          KoraButton(label: 'RECEIVE $symbol', tone: KoraButtonTone.primary, onPressed: onReceive),
        ],
      ),
    );
  }
}
