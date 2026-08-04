import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

// The banner shown while the wallet's stored addresses still need migrating.

class MigrationBanner extends ConsumerStatefulWidget {
  const MigrationBanner({super.key, required this.assets});
  final List<Asset> assets;
  @override
  ConsumerState<MigrationBanner> createState() => _MigrationBannerState();
}

class _MigrationBannerState extends ConsumerState<MigrationBanner> with ThemeAwareMixin {
  bool _dismissed = false;
  bool _autoDialogShown = false;

  bool _needsAddressFix() {
    const utxoWrong = {'litecoin'};
    return widget.assets.any((a) =>
        (utxoWrong.contains(a.blockchain) && a.contractAddress.startsWith('0x')) ||
        false);
  }

  bool _needsMigration() => _needsAddressFix() || ref.watch(needsMigrationPinProvider);

  void _showPinDialog() {
    final pinCtrl  = TextEditingController();
    String? errMsg;
    bool    obscure = true;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('Re-derive Addresses',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Enter your wallet PIN to re-derive correct addresses for LTC.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: obscure,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textPrimary, letterSpacing: 4),
              decoration: InputDecoration(
                hintText: '• • • • • •',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                errorText: errMsg,
                errorStyle: TextStyle(color: AppColors.negative, fontSize: 11),
                filled: true, fillColor: AppColors.background,
                border:        OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.textSecondary)),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textTertiary, size: 18),
                  onPressed: () => setS(() => obscure = !obscure),
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final pin = pinCtrl.text.trim();
                final ok  = await ref.read(currentWalletProvider.notifier)
                    .refreshWalletAddresses(pin);
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.of(ctx).pop();
                  if (mounted) setState(() => _dismissed = true);
                } else {
                  setS(() => errMsg = 'Incorrect PIN');
                }
              },
              child: Text('Update', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsFullMigration = ref.watch(needsMigrationPinProvider);
    // Auto-show PIN dialog once when full migration requires the real PIN
    if (needsFullMigration && !_autoDialogShown) {
      _autoDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPinDialog();
      });
    }
    if (_dismissed || !_needsMigration()) return const SizedBox.shrink();
    final label = needsFullMigration
        ? 'Wallet initialisation requires your PIN.'
        : 'LTC addresses need to be updated.';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(children: [
        Icon(Icons.update_rounded, color: AppColors.warning, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.warning, fontSize: 12),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedTap(
          onTap: _showPinDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.zero,
            ),
            child: Text('Fix', style: TextStyle(color: AppColors.warning,
                fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedTap(
          onTap: () => setState(() => _dismissed = true),
          child: Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 16),
        ),
      ]),
    );
  }
}
