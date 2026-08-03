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
import 'package:kora/core/widgets/chips/coin_icon.dart';

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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Receive'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: walletAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.textPrimary, strokeWidth: 1.5)),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: Colors.red))),
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
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Asset tabs — only shown when not locked to a specific asset
              if (!locked && tabs.length > 1)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: tabs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final a   = tabs[i];
                      final sel = (a.id == _selected?.id);
                      return AnimatedTap(
                        onTap: () => setState(() => _selected = a),
                        pressScale: 0.92,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.textPrimary : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: sel ? AppColors.textPrimary : AppColors.border, width: 0.5),
                          ),
                          child: Text(a.symbol,
                              style: TextStyle(
                                  color: sel ? AppColors.background : AppColors.textSecondary,
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 32),

              // QR Code + Asset Info with smooth transition
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
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
                    // QR Code
                    if (address.isNotEmpty)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
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
                    const SizedBox(height: 20),

                    // Coin + network info card
                    if (_selected != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Row(children: [
                          CoinIcon(
                            symbol: _selected!.symbol,
                            iconUrl: _selected!.iconUrl,
                            size: 44,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selected!.symbol,
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _networkLabel(_selected!.blockchain),
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Address display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(children: [
                  Text(
                    address,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 13,
                        fontWeight: FontWeight.w500, letterSpacing: 0.3, height: 1.5),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Copy button
              FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: address));
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Address copied to clipboard')));
                },
                icon: Icon(Icons.copy_rounded, size: 18),
                label: Text('Copy Address'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.background,
                  minimumSize: Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),

              // Critical: ETH-fallback address for unsupported chain
              if (_selected != null && _isEthFallback(_selected!))
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.negative.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.negative.withValues(alpha: 0.4), width: 0.5),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.error_outline_rounded, color: AppColors.negative, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '⚠ ${_selected!.blockchain.toUpperCase()} is not yet fully supported. '
                        'The address below is a placeholder in ETH format and '
                        'CANNOT actually receive ${_selected!.symbol}. '
                        'Do NOT share this address for receiving funds.',
                        style: TextStyle(
                            color: AppColors.negative, fontSize: 12, height: 1.5),
                      ),
                    ),
                  ]),
                ),

              // Normal warning
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3), width: 0.5),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only send ${_selected?.symbol ?? 'assets'} to this address. Sending other assets may result in permanent loss.',
                      style: TextStyle(
                          color: AppColors.warning, fontSize: 12, height: 1.5),
                    ),
                  ),
                ]),
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
