import 'package:flutter/material.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/widgets/chips/coin_icon.dart';
import 'package:kora/features/receive/receive_screen.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

class ReceivePickerScreen extends StatefulWidget {
  const ReceivePickerScreen({super.key, required this.assets});
  final List<Asset> assets;

  @override
  State<ReceivePickerScreen> createState() => _ReceivePickerScreenState();
}

class _ReceivePickerScreenState extends State<ReceivePickerScreen> with ThemeAwareMixin {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Asset> get _filtered {
    if (_query.isEmpty) return widget.assets;
    final q = _query.toLowerCase();
    return widget.assets.where((a) =>
        a.name.toLowerCase().contains(q) ||
        a.symbol.toLowerCase().contains(q) ||
        _netLabel(a.blockchain).toLowerCase().contains(q)).toList();
  }

  void _open(Asset asset) {
    context.pushFade(ReceiveScreen(preselectedAsset: asset));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Receive',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(children: [
        // ── Search bar ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search cryptocurrency…',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              prefixIcon: Icon(Icons.search_rounded,
                  color: AppColors.textTertiary, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AppColors.textTertiary, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: AppColors.textSecondary, width: 1.2)),
            ),
          ),
        ),

        // ── Section header ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _query.isEmpty ? 'My assets' : 'Results (${filtered.length})',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
          ),
        ),

        // ── Asset list ────────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No assets found',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 15)))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _AssetRow(
                    asset: filtered[i],
                    onTap: () => _open(filtered[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ─── Single asset row ─────────────────────────────────────────────────────────

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.asset, required this.onTap});
  final Asset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.97,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(children: [
          CoinIcon(symbol: asset.symbol, iconUrl: asset.iconUrl, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.symbol,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Row(children: [
                    _NetBadge(_netLabel(asset.blockchain)),
                  ]),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(asset.formattedBalance,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(asset.formattedUsdValue,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ]),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios_rounded,
              color: AppColors.textTertiary, size: 14),
        ]),
      ),
    );
  }
}

class _NetBadge extends StatelessWidget {
  const _NetBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}

String _netLabel(String b) => const {
      'bitcoin':   'Bitcoin',
      'ethereum':  'Ethereum',
      'bsc':       'BNB Smart Chain',
      'tron':      'Tron',
      'solana':    'Solana',
      'litecoin':  'Litecoin',
    }[b] ??
    b;
