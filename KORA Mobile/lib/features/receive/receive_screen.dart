import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key, this.preselectedAsset});
  final Asset? preselectedAsset;

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> with ThemeAwareMixin {
  Asset? _selected;

  String _address(List<Asset> assets) {
    final asset = _selected ?? assets.firstOrNull;
    if (asset == null) return '';
    return asset.contractAddress;
  }

  /// True when a non-EVM asset has an ETH-format 0x address (placeholder/fallback).
  bool _isEthFallback(Asset asset) {
    return !APIConfig.evmChains.contains(asset.blockchain) &&
        asset.contractAddress.startsWith('0x');
  }

  /// Returns one representative Asset per unique blockchain.
  /// Tokens on the same chain share the same address, so we pick the native
  /// coin for that chain (or the first asset if no native exists).
  List<Asset> _uniqueBlockchainAssets(List<Asset> assets) {
    final seen = <String>{};
    final result = <Asset>[];
    // Prefer native coins as the representative
    final natives = assets.where((a) => a.type == AssetType.native).toList();
    for (final a in [...natives, ...assets]) {
      if (seen.add(a.blockchain)) result.add(a);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(currentWalletProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: koraAppBar(context, 'Receive',
          onBack: () => Navigator.of(context).pop()),
      body: walletAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.textPrimary, strokeWidth: 1.5)),
        error: (e, _) => Center(child: Text('Error: $e', style: kBody(Colors.red, size: 13))),
        data: (wallet) {
          final assets  = wallet?.assets ?? [];
          if (_selected == null && assets.isNotEmpty) {
            _selected = widget.preselectedAsset ?? assets.first;
          }
          final address = _address(assets);

          // ── If preselectedAsset is set, lock this screen to that asset only.
          // We must NEVER allow the user to accidentally switch to a different
          // blockchain and generate a QR code for the wrong network.
          final bool locked = widget.preselectedAsset != null;

          // For the "Receive" button on HomeScreen (no preselection) we let
          // the user switch between assets — but only show one representative
          // per unique blockchain (avoids showing 3× USDT tabs).
          final List<Asset> tabs = locked
              ? [_selected!]
              : _uniqueBlockchainAssets(assets);

          return SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // The chips join into one segment, the chosen asset inverted — the same
              // control the fee tiers use.
              if (!locked && tabs.length > 1)
                Container(
                  margin: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                  decoration: BoxDecoration(color: AppColors.border, border: kHairline()),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: IntrinsicHeight(
                      child: Row(children: [
                        for (final (i, a) in tabs.indexed) ...[
                          if (i > 0) const SizedBox(width: 1),
                          AnimatedTap(
                            onTap: () => setState(() => _selected = a),
                            pressScale: 0.95,
                            child: AnimatedContainer(
                              duration: kControl,
                              curve: kEase,
                              constraints: const BoxConstraints(minWidth: 58),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              color: a.id == _selected?.id
                                  ? AppColors.textPrimary
                                  : AppColors.background,
                              alignment: Alignment.center,
                              child: Text(a.symbol,
                                  style: kLabel(
                                    a.id == _selected?.id
                                        ? AppColors.background
                                        : AppColors.textTertiary,
                                    size: 9.5, tracking: 0.1)),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),

              // The QR and what it is, swapped together on the house curve.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: kEase,
                switchOutCurve: kEase,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.012),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  key: ValueKey(_selected?.id ?? 'empty'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The asset and its network in one line: what to send, and where.
                    // Never one without the other — an address is only correct on its chain.
                    if (_selected != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                        child: Text(
                          '${_selected!.symbol} · ${_networkLabel(_selected!.blockchain).toUpperCase()} NETWORK',
                          textAlign: TextAlign.center,
                          style: kLabel(AppColors.textPrimary, size: 10.5, tracking: 0.16),
                        ),
                      ),
                    if (address.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: kHairline(),
                            ),
                            child: QrImageView(
                              data: address,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                              eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square, color: Colors.black),
                              dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // The address itself, in mono — the one string that must be transcribed exactly.
              Padding(
                padding: const EdgeInsets.fromLTRB(34, 18, 34, 0),
                child: Text(
                  address,
                  textAlign: TextAlign.center,
                  style: kMonoText(AppColors.textSecondary, size: 10.5).copyWith(height: 1.8),
                ),
              ),
              const SizedBox(height: 18),

              // Copy and Share as one joined group, Copy suggested.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  decoration: BoxDecoration(color: AppColors.border, border: kHairline()),
                  child: Row(children: [
                    Expanded(
                      child: AnimatedTap(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: address));
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Address copied to clipboard')));
                        },
                        pressScale: 0.96,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: AppColors.textPrimary,
                          alignment: Alignment.center,
                          child: Text('COPY ADDRESS',
                              style: kLabel(AppColors.background, size: 10.5, tracking: 0.16)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              // Critical: ETH-fallback address for unsupported chain
              if (_selected != null && _isEthFallback(_selected!))
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: AppColors.negative, width: 2),
                        top: kHairlineSide(), right: kHairlineSide(), bottom: kHairlineSide(),
                      ),
                    ),
                    child: Text(
                      '${_selected!.blockchain.toUpperCase()} IS NOT YET FULLY SUPPORTED. '
                      'THE ADDRESS ABOVE IS A PLACEHOLDER IN ETH FORMAT AND '
                      'CANNOT ACTUALLY RECEIVE ${_selected!.symbol}. '
                      'DO NOT SHARE THIS ADDRESS FOR RECEIVING FUNDS.',
                      style: kLabel(AppColors.negative, size: 8.5, tracking: 0.08,
                              weight: FontWeight.w400)
                          .copyWith(height: 1.8),
                    ),
                  ),
                ),

              // Normal warning — names the asset and the network it lives on.
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AppColors.warning, width: 2),
                      top: kHairlineSide(), right: kHairlineSide(), bottom: kHairlineSide(),
                    ),
                  ),
                  child: Text(
                    'SEND ONLY ${_selected?.symbol ?? 'ASSETS'} ON THE '
                    '${_networkLabel(_selected?.blockchain ?? '').toUpperCase()} NETWORK. '
                    'OTHER ASSETS MAY BE LOST PERMANENTLY.',
                    style: kLabel(AppColors.warning, size: 8.5, tracking: 0.08,
                            weight: FontWeight.w400)
                        .copyWith(height: 1.8),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

String _networkLabel(String b) => const {
  'bitcoin':    'Bitcoin',       'ethereum':  'Ethereum',
  'bsc':        'BNB Smart Chain','tron':     'Tron',
  'solana':     'Solana',        'litecoin':   'Litecoin',
}[b] ?? b;
