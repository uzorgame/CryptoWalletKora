import 'package:flutter/material.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';
import 'package:kora/core/widgets/kora_field.dart';
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
      appBar: koraAppBar(context, 'Receive',
          onBack: () => Navigator.of(context).pop()),
      body: Column(children: [
        const SizedBox(height: 14),
        KoraField(
          child: Row(children: [
            Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 17),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: koraInputStyle(),
                decoration: koraInputDecoration('SEARCH CRYPTOCURRENCY'),
              ),
            ),
            if (_query.isNotEmpty)
              AnimatedTap(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                child: Icon(Icons.close_rounded,
                    color: AppColors.textTertiary, size: 16),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _query.isEmpty ? 'MY ASSETS' : 'RESULTS (${filtered.length})',
              style: kLabel(AppColors.textTertiary, size: 9.5, tracking: 0.16),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('NO ASSETS FOUND',
                      style: kLabel(AppColors.textTertiary, size: 10, tracking: 0.14)))
              : ListView.builder(
                  padding: EdgeInsets.zero,
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
// A hairline table row: symbol and name lead, the balance sits right in tabular figures.
// The catalog's names carry the network where it matters, so no separate badge survives.

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.asset, required this.onTap});
  final Asset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.98,
      pressOpacity: 0.85,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: kHairlineSide())),
        child: Row(children: [
          Expanded(
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(asset.symbol,
                      style: kLabel(AppColors.textPrimary, size: 12.5, tracking: 0.06)),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(asset.name,
                        overflow: TextOverflow.ellipsis,
                        style: kBody(AppColors.textSecondary, size: 11)),
                  ),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(asset.formattedBalance,
                style: kNum(AppColors.textPrimary, size: 13)),
            const SizedBox(height: 4),
            Text(asset.formattedUsdValue,
                style: kMonoText(AppColors.textSecondary, size: 10)),
          ]),
          const SizedBox(width: 10),
          Text('›', style: kMonoText(AppColors.textTertiary, size: 13)),
        ]),
      ),
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
