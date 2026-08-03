import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kora/features/send/fee/models/fee_estimate.dart';

class TxSuccessScreen extends ConsumerWidget {
  const TxSuccessScreen({
    super.key,
    required this.asset,
    required this.toAddress,
    required this.amount,
    required this.txHash,
    this.feeEstimate,
  });

  final Asset asset;
  final String toAddress;
  final String amount;
  final String txHash;
  final FeeEstimate? feeEstimate;

  String get _explorerUrl {
    return APIConfig.explorerTxUrl(asset.blockchain, txHash);
  }

  String _feeText() {
    final fee = feeEstimate;
    if (fee == null) return '';
    final sym = _feeSymbol(asset.blockchain);
    final n   = fee.feeInNative;
    String native;
    if (n >= 1)           native = n.toStringAsFixed(2);
    else if (n >= 0.001)  native = n.toStringAsFixed(4);
    else if (n >= 0.000001) {
      native = n.toStringAsFixed(6)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    } else                native = n.toStringAsExponential(2);
    String out = '$native $sym';
    if (fee.feeInUsd > 0) {
      final usd = fee.feeInUsd >= 0.01
          ? '\$${fee.feeInUsd.toStringAsFixed(2)}'
          : '\$${fee.feeInUsd.toStringAsFixed(4)}';
      out += '  ($usd)';
    }
    return out;
  }

  static String _feeSymbol(String b) => const {
    'bitcoin': 'BTC',  'ethereum': 'ETH',  'bsc': 'BNB',
    'ethereum_classic': 'ETC',
    'solana': 'SOL',   'tron': 'TRX',      'litecoin': 'LTC',
    'bitcoin_cash': 'BCH',
  }[b] ?? b.toUpperCase();

  static String _shorten(String s) {
    if (s.length <= 16) return s;
    return '${s.substring(0, 8)}…${s.substring(s.length - 6)}';
  }

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label copied'),
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feeText   = _feeText();
    final fromShort = _shorten(asset.contractAddress);
    final toShort   = _shorten(toAddress);
    final txShort   = '${txHash.substring(0, 10)}…${txHash.substring(txHash.length - 8)}';
    final explorerUrl = _explorerUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 56),

              // ── Success animation ──────────────────────────────────────────
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.positive.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.check_rounded,
                      color: AppColors.positive, size: 44),
                ),
              ),
              const SizedBox(height: 20),

              Text('Sent!',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 6),
              Text('Transaction broadcast successfully',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14)),

              const SizedBox(height: 32),

              // ── Details card ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(children: [
                  _SuccessRow('Asset',
                      '${asset.symbol}  ·  ${asset.name}'),
                  _SuccessRow('From',
                      fromShort,
                      onTap: () => _copy(context, asset.contractAddress, 'From address')),
                  _SuccessRow('To',
                      toShort,
                      onTap: () => _copy(context, toAddress, 'To address')),
                  _SuccessRow('Amount',
                      '$amount ${asset.symbol}'),
                  if (feeText.isNotEmpty)
                    _SuccessRow('Network Fee', feeText),
                  _SuccessRow('TX Hash',
                      txShort,
                      mono: true,
                      trailing: Icon(Icons.copy_rounded,
                          size: 14, color: AppColors.textTertiary),
                      onTap: () => _copy(context, txHash, 'TX hash'),
                      last: true),
                ]),
              ),

              const Spacer(),

              // ── Explorer link ──────────────────────────────────────────────
              if (explorerUrl.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final uri = Uri.parse(explorerUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      _copy(context, explorerUrl, 'Explorer link');
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new_rounded,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text('View in Explorer',
                          style: TextStyle(
                              color: AppColors.textTertiary, fontSize: 13)),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // ── Done button ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Row widget ───────────────────────────────────────────────────────────────

class _SuccessRow extends StatelessWidget {
  const _SuccessRow(
    this.label,
    this.value, {
    this.mono   = false,
    this.last   = false,
    this.trailing,
    this.onTap,
  });

  final String  label;
  final String  value;
  final bool    mono;
  final bool    last;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 16),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: mono ? 'monospace' : null,
                      )),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  trailing!,
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        onTap != null ? GestureDetector(onTap: onTap, child: row) : row,
        if (!last)
          Divider(height: 0, thickness: 0.5, color: AppColors.border),
      ],
    );
  }
}
