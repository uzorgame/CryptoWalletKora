import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/services/tx_history_service.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';
import 'package:kora/core/widgets/kora_rows.dart';

// ─── Explorer URL per blockchain ─── delegated to APIConfig ─────────────────

String explorerTxUrl(String blockchain, String hash) =>
    APIConfig.explorerTxUrl(blockchain, hash);

// ─── Screen ───────────────────────────────────────────────────────────────────

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({
    super.key,
    required this.tx,
    required this.asset,
  });

  final TxRecord tx;
  final Asset    asset;

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label copied'),
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isIn   = tx.direction == TxDirection.incoming;
    final isSelf = tx.direction == TxDirection.self;

    final color = isSelf
        ? AppColors.textSecondary
        : isIn
            ? AppColors.positive
            : AppColors.negative;
    final sign   = isSelf ? '' : isIn ? '+' : '−';
    final amtStr = '$sign${tx.amount.toStringAsFixed(tx.amount < 0.001 ? 6 : 4)} ${tx.symbol}';
    final label  = isSelf ? 'Self-Transfer' : isIn ? 'Received' : 'Sent';
    final dateStr = DateFormat('MMM d, yyyy  HH:mm:ss').format(tx.timestamp);

    final url = explorerTxUrl(tx.blockchain, tx.hash);

    String? feeStr;
    if (tx.feePaid != null && tx.feePaid! > 0) {
      final f   = tx.feePaid!;
      final sym = _nativeSym(tx.blockchain);
      if (f >= 0.001)       feeStr = '${f.toStringAsFixed(4)} $sym';
      else if (f >= 0.000001) {
        feeStr = '${f.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '')} $sym';
      } else                feeStr = '${f.toStringAsExponential(2)} $sym';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: koraAppBar(context, 'Transaction Details',
          backLabel: 'Transactions',
          onBack: () => Navigator.of(context).pop()),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [

          // ── Status header ──────────────────────────────────────────────────
          // What happened, in what state, for how much and when — left-led, as the coin page
          // is, with the state coloured by direction.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(label.toUpperCase(), style: kLabel(color, size: 9.5, tracking: 0.16)),
                Text(' · ', style: kLabel(AppColors.textTertiary, size: 9.5)),
                if (!tx.confirmed) ...[
                  SizedBox(
                    width: 9, height: 9,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.2, color: AppColors.warning),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  tx.confirmed ? 'CONFIRMED' : 'PROCESSING',
                  style: kLabel(
                      tx.confirmed ? color : AppColors.warning,
                      size: 9.5, tracking: 0.16),
                ),
              ]),
              const SizedBox(height: 8),
              Text(amtStr, style: kNum(AppColors.textPrimary, size: 30)),
              const SizedBox(height: 6),
              Text(dateStr.toUpperCase(),
                  style: kMonoText(AppColors.textTertiary, size: 10)),
            ]),
          ),

          // ── Details ────────────────────────────────────────────────────────
          const KoraSection('Details'),
          KoraDataRow('Status', tx.confirmed ? 'CONFIRMED' : 'PROCESSING',
              valueColor: tx.confirmed ? AppColors.positive : AppColors.warning,
              topLine: true),
          KoraDataRow('Network', _networkName(tx.blockchain).toUpperCase()),
          KoraDataRow('Asset', tx.symbol),
          if (tx.from.isNotEmpty)
            KoraDataRow('From', tx.shortFrom,
                copyable: true, onTap: () => _copy(context, tx.from, 'From address')),
          if (tx.to.isNotEmpty)
            KoraDataRow('To', tx.shortTo,
                copyable: true, onTap: () => _copy(context, tx.to, 'To address')),
          if (feeStr != null) KoraDataRow('Network fee', feeStr),
          KoraDataRow('TX hash', tx.shortHash,
              copyable: true, onTap: () => _copy(context, tx.hash, 'TX hash')),

          // ── Explorer ───────────────────────────────────────────────────────
          if (url.isNotEmpty) ...[
            const SizedBox(height: 8),
            KoraLink(
              'View in explorer ↗',
              onTap: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  _copy(context, url, 'Explorer link');
                }
              },
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static String _nativeSym(String b) => const {
    'bitcoin': 'BTC',  'ethereum': 'ETH',  'bsc': 'BNB',
    'ethereum_classic': 'ETC',
    'solana': 'SOL',   'tron': 'TRX',      'litecoin': 'LTC',
    'bitcoin_cash': 'BCH',
  }[b] ?? b.toUpperCase();

  static String _networkName(String b) => const {
    'bitcoin': 'Bitcoin', 'ethereum': 'Ethereum', 'solana': 'Solana',
    'bsc': 'BNB Smart Chain', 'tron': 'Tron',
    'litecoin': 'Litecoin',
    'ethereum_classic': 'Ethereum Classic',
    'bitcoin_cash': 'Bitcoin Cash',
  }[b] ?? b;
}
