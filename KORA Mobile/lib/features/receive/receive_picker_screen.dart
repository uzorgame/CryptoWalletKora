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

/// The receive tab, exactly the prototype's picker: CHOOSE AN ASSET over a hairline table.
/// Each row reads the symbol, the name and how much of it the wallet holds; the chevron is
/// the only ornament. Tapping opens that asset's address.
class ReceivePickerScreen extends StatefulWidget {
  const ReceivePickerScreen({
    super.key,
    required this.assets,
    this.embedded = false,
    this.onExit,
  });
  final List<Asset> assets;

  /// True when living as tab 03 under the shell's bar — the back arrow then returns to the
  /// wallet tab through [onExit] instead of popping.
  final bool embedded;
  final VoidCallback? onExit;

  @override
  State<ReceivePickerScreen> createState() => _ReceivePickerScreenState();
}

class _ReceivePickerScreenState extends State<ReceivePickerScreen> with ThemeAwareMixin {
  void _open(Asset asset) {
    context.pushFade(ReceiveScreen(preselectedAsset: asset));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: koraAppBar(context, 'Receive',
          onBack: widget.embedded
              ? widget.onExit
              : () => Navigator.of(context).pop()),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const KoraSlabel('Choose an asset',
            padding: EdgeInsets.fromLTRB(22, 18, 22, 10)),
        Expanded(
          child: widget.assets.isEmpty
              ? Center(
                  child: Text('NO ASSETS',
                      style: kLabel(AppColors.textTertiary, size: 10, tracking: 0.14)))
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: widget.assets.length,
                  itemBuilder: (_, i) => _AssetRow(
                    asset: widget.assets[i],
                    onTap: () => _open(widget.assets[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ─── Single asset row ─────────────────────────────────────────────────────────
// The prototype's krow: symbol with the name beside it, the held amount underneath in mono,
// a chevron at the edge.

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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(border: Border(bottom: kHairlineSide())),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline,
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
              const SizedBox(height: 4),
              Row(children: [
                Text(asset.formattedBalance,
                    style: kMonoText(AppColors.textSecondary, size: 10)),
                const SizedBox(width: 5),
                Text(asset.symbol,
                    style: kBody(AppColors.textSecondary, size: 10)),
              ]),
            ]),
          ),
          Text('›', style: kMonoText(AppColors.textSecondary, size: 13)),
        ]),
      ),
    );
  }
}
