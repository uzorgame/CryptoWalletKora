import 'package:flutter/material.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/widgets/kora_rows.dart';

// The facts about the asset, under the chart.
//
// Not a fold-out any more. Three lines — the network, the address and the decimals — are
// what a user opens this page to check, and hiding them behind a chevron only means one
// more tap before every check. The prototype has them plainly on the page, under a Details
// heading, and so does this. The [expanded] and [onToggle] arguments remain so no caller
// had to change; nothing reads them.

class CollapsibleDetails extends StatelessWidget {
  const CollapsibleDetails({
    super.key,
    required this.asset,
    required this.expanded,
    required this.onToggle,
    required this.onCopyAddress,
  });
  final Asset asset;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onCopyAddress;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const KoraSection('Details'),
      KoraDataRow('Network', _networkName(asset.blockchain).toUpperCase(), topLine: true),
      KoraDataRow('Address', _shortenAddress(asset.contractAddress),
          copyable: true, onTap: onCopyAddress),
      KoraDataRow('Decimals', asset.decimals.toString()),
    ]);
  }

  static String _networkName(String b) {
    const names = <String, String>{
      'bitcoin': 'Bitcoin', 'ethereum': 'Ethereum', 'solana': 'Solana',
      'bsc': 'BNB Smart Chain', 'tron': 'Tron',
      'litecoin': 'Litecoin', 'bitcoin_cash': 'Bitcoin Cash',
      'ethereum_classic': 'Ethereum Classic',
      'optimism': 'OP Mainnet', 'avalanche': 'Avalanche C-Chain',
    };
    return names[b] ?? b;
  }

  static String _shortenAddress(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }
}
