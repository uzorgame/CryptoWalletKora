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
import 'package:kora/core/widgets/kora_button.dart';

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
          onBack: () => Navigator.of(context).pop()),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        children: [

          // ── Status header ──────────────────────────────────────────────────
          // What happened, in what state, and for how much — left-led, as the coin page is.
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 22, 0, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(label.toUpperCase(), style: kLabel(color, size: 10.5, tracking: 0.14)),
                Text('  ·  ', style: kLabel(AppColors.textTertiary, size: 10.5)),
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
                      tx.confirmed ? AppColors.textTertiary : AppColors.warning,
                      size: 10.5, tracking: 0.14),
                ),
              ]),
              const SizedBox(height: 10),
              Text(amtStr, style: kNum(color, size: 30)),
            ]),
          ),

          // ── Details card ───────────────────────────────────────────────────
          _Card(children: [
            _DetailRow(
              label: tx.confirmed ? 'Confirmed' : 'Submitted',
              value: dateStr,
            ),
            _DetailRow(
              label: 'Network',
              value: _networkName(tx.blockchain),
            ),
            _DetailRow(
              label: 'Asset',
              value: '${tx.symbol}  ·  ${asset.name}',
            ),
            if (feeStr != null)
              _DetailRow(
                label: 'Network Fee',
                value: feeStr,
              ),
          ]),

          const SizedBox(height: 12),

          // ── Addresses card ─────────────────────────────────────────────────
          _Card(children: [
            if (tx.from.isNotEmpty)
              _DetailRow(
                label: 'From',
                value: tx.shortFrom,
                fullValue: tx.from,
                onCopy: tx.from.isNotEmpty
                    ? () => _copy(context, tx.from, 'From address')
                    : null,
              ),
            if (tx.to.isNotEmpty)
              _DetailRow(
                label: 'To',
                value: tx.shortTo,
                fullValue: tx.to,
                onCopy: tx.to.isNotEmpty
                    ? () => _copy(context, tx.to, 'To address')
                    : null,
              ),
            _DetailRow(
              label: 'TX Hash',
              value: tx.shortHash,
              fullValue: tx.hash,
              mono: true,
              onCopy: () => _copy(context, tx.hash, 'TX hash'),
              last: true,
            ),
          ]),

          const SizedBox(height: 20),

          // ── Explorer button ────────────────────────────────────────────────
          if (url.isNotEmpty)
            KoraGhost(
              label: 'View in Explorer',
              onTap: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  _copy(context, url, 'Explorer link');
                }
              },
            ),

          const SizedBox(height: 32),
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

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(border: kHairline()),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.fullValue,
    this.mono    = false,
    this.last    = false,
    this.onCopy,
  });

  final String  label;
  final String  value;
  final String? fullValue;
  final bool    mono;
  final bool    last;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label.toUpperCase(),
                style: kMonoText(AppColors.textSecondary, size: 9.5)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: kMonoText(AppColors.textPrimary, size: 11,
                  weight: FontWeight.w500),
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onCopy,
              child: Icon(Icons.copy_rounded,
                  size: 13, color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        if (!last)
          Divider(height: 0, thickness: 1, color: AppColors.border),
      ],
    );
  }
}
