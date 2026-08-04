import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_button.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const SizedBox(height: 54),

              // The mark arrives on the house curve — no bounce; a wallet's good news should
              // land, not wobble.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 340),
                curve: kEase,
                builder: (_, v, child) => Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
                ),
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.positive, width: 1),
                  ),
                  child: Icon(Icons.check_rounded,
                      color: AppColors.positive, size: 30),
                ),
              ),
              const SizedBox(height: 22),

              Text('Sent!',
                  style: kNum(AppColors.textPrimary, size: 24, weight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text('TRANSACTION BROADCAST SUCCESSFULLY',
                  style: kLabel(AppColors.textTertiary, size: 9.5, tracking: 0.14)),

              const SizedBox(height: 28),

              // ── Details ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(border: kHairline()),
                child: Column(children: [
                  _SuccessRow('Asset',
                      '${asset.symbol} · ${asset.name}'),
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
                      trailing: Icon(Icons.copy_rounded,
                          size: 13, color: AppColors.textTertiary),
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
                      Text('VIEW IN EXPLORER',
                          style: kLabel(AppColors.textSecondary, size: 9.5, tracking: 0.14)),
                      const SizedBox(width: 6),
                      Icon(Icons.open_in_new_rounded,
                          size: 12, color: AppColors.textSecondary),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              KoraCta(
                label: 'Done',
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),

              const SizedBox(height: 28),
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
    this.last   = false,
    this.trailing,
    this.onTap,
  });

  final String  label;
  final String  value;
  final bool    last;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: kMonoText(AppColors.textSecondary, size: 9.5)),
          const SizedBox(width: 16),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(value,
                      textAlign: TextAlign.end,
                      style: kMonoText(AppColors.textPrimary, size: 11,
                          weight: FontWeight.w500)),
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
          Divider(height: 0, thickness: 1, color: AppColors.border),
      ],
    );
  }
}
