import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_button.dart';
import 'package:kora/core/widgets/kora_rows.dart';
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
        child: Column(
            children: [
              Expanded(
                child: ListView(padding: EdgeInsets.zero, children: [
              const SizedBox(height: 58),

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
                child: Center(
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.positive, width: 1),
                    ),
                    child: Icon(Icons.check_rounded,
                        color: AppColors.positive, size: 30),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Center(
                child: Text('Sent!',
                    style: kNum(AppColors.textPrimary, size: 24, weight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('TRANSACTION BROADCAST SUCCESSFULLY',
                    style: kLabel(AppColors.textTertiary, size: 10, tracking: 0.14)),
              ),

              // ── Summary ────────────────────────────────────────────────────
              const KoraSection('Summary'),
              KoraDataRow('Asset', '${asset.symbol} · ${asset.name.toUpperCase()}',
                  topLine: true),
              KoraDataRow('From', fromShort,
                  copyable: true,
                  onTap: () => _copy(context, asset.contractAddress, 'From address')),
              KoraDataRow('To', toShort,
                  copyable: true, onTap: () => _copy(context, toAddress, 'To address')),
              KoraDataRow('Amount', '$amount ${asset.symbol}'),
              if (feeText.isNotEmpty) KoraDataRow('Network fee', feeText),
              KoraDataRow('TX hash', txShort,
                  copyable: true, onTap: () => _copy(context, txHash, 'TX hash')),

              if (explorerUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                KoraLink(
                  'View in explorer ↗',
                  onTap: () async {
                    final uri = Uri.parse(explorerUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      _copy(context, explorerUrl, 'Explorer link');
                    }
                  },
                ),
              ],
              const SizedBox(height: 18),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
                child: KoraCta(
                  label: 'Done',
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
        ),
      ),
    );
  }
}
