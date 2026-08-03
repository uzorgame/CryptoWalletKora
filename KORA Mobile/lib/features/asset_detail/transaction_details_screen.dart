import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/services/tx_history_service.dart';
import 'package:kora/core/theme/app_theme.dart';

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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Transaction Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [

          // ── Status header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(
                  isSelf
                      ? Icons.sync_rounded
                      : isIn
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                  color: color, size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(amtStr,
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  )),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (tx.confirmed ? AppColors.positive : Colors.orange)
                      .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (!tx.confirmed) ...[
                      SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: Colors.orange),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      tx.confirmed ? 'Confirmed' : 'Processing',
                      style: TextStyle(
                        color: tx.confirmed ? AppColors.positive : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
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
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.border, width: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  _copy(context, url, 'Explorer link');
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('View in Explorer',
                  style: TextStyle(fontWeight: FontWeight.w500)),
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
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onCopy,
              child: Icon(Icons.copy_rounded,
                  size: 14, color: AppColors.textTertiary),
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
          Divider(height: 0, thickness: 0.5, color: AppColors.border),
      ],
    );
  }
}
