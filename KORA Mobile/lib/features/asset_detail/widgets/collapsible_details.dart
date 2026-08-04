import 'package:flutter/material.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

// The fold-out block of facts about the asset, under the chart.

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(border: kHairline()),
        child: Column(children: [
          // Header row — always visible
          AnimatedTap(
            onTap: onToggle,
            pressScale: 0.98,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(children: [
                Text('DETAILS',
                    style: kLabel(AppColors.textPrimary, size: 10.5, tracking: 0.16)),
                const Spacer(),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: kControl,
                  curve: kEase,
                  child: Icon(Icons.expand_more_rounded,
                      color: AppColors.textTertiary, size: 18),
                ),
              ]),
            ),
          ),
          // Animated expandable content
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: expanded
                ? Column(children: [
                    Divider(color: AppColors.separator, height: 0.5, thickness: 0.5),
                    _InfoRow(label: 'Network',  value: _networkName(asset.blockchain)),
                    _InfoRow(label: 'Symbol',   value: asset.symbol),
                    _InfoRow(label: 'Decimals', value: asset.decimals.toString()),
                    _InfoRow(
                      label: 'Address',
                      value: _shortenAddress(asset.contractAddress),
                      onCopy: onCopyAddress,
                    ),
                  ])
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  static String _networkName(String b) {
    const names = <String, String>{
      'bitcoin': 'Bitcoin', 'ethereum': 'Ethereum', 'solana': 'Solana',
      'bsc': 'BNB Smart Chain', 'tron': 'Tron',
      'litecoin': 'Litecoin',
      'optimism': 'OP Mainnet', 'avalanche': 'Avalanche C-Chain',
    };
    return names[b] ?? b;
  }

  static String _shortenAddress(String addr) {
    if (addr.length <= 16) return addr;
    return '${addr.substring(0, 8)}...${addr.substring(addr.length - 6)}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.onCopy});
  final String label, value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(top: kHairlineSide())),
      child: Row(children: [
        Text(label.toUpperCase(),
            style: kMonoText(AppColors.textSecondary, size: 9.5)),
        const Spacer(),
        Flexible(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: kMonoText(AppColors.textPrimary, size: 11,
                  weight: FontWeight.w500)),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 8),
          AnimatedTap(
            onTap: onCopy,
            child: Icon(Icons.copy_rounded, color: AppColors.textTertiary, size: 13),
          ),
        ],
      ]),
    ),
  );
}
