import 'package:flutter/material.dart';
import 'package:kora/core/widgets/kora_mark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/models/wallet.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/widgets/kora_rows.dart';
import 'package:kora/core/widgets/pin_gate.dart';
import 'package:kora/features/home/wallet_switcher/add_wallet_sheet.dart';

// The sheet listing every wallet on this device, for switching between them.

/// How many wallets one device may hold.
const int _kMaxWallets = 5;

class WalletSwitcherSheet extends ConsumerStatefulWidget {
  const WalletSwitcherSheet({super.key});

  @override
  ConsumerState<WalletSwitcherSheet> createState() => _WalletSwitcherSheetState();
}

class _WalletSwitcherSheetState extends ConsumerState<WalletSwitcherSheet> with ThemeAwareMixin {
  void _onAddWallet(int currentCount) {
    if (currentCount >= _kMaxWallets) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum of $_kMaxWallets wallets reached'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pop(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AddWalletSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allWallets = ref.watch(allWalletsProvider);
    final currentWallet = ref.watch(currentWalletProvider).value;

    // The prototype's k-switcher: a square sheet on the brighter hairline, the title
    // tracked, a line saying plainly that switching costs a PIN, then the table.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderHi, width: 1)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Container(width: 24, height: 2, color: AppColors.textTertiary),
            const SizedBox(height: 18),
            Text('WALLETS',
                style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.18)),
            const SizedBox(height: 8),
            Text('SWITCHING ASKS FOR THE APP PIN',
                style: kLabel(AppColors.textTertiary, size: 9, tracking: 0.14)),
            const SizedBox(height: 14),
            allWallets.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    color: AppColors.textTertiary, strokeWidth: 1.5),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (wallets) => ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: wallets.length,
                itemBuilder: (_, i) {
                  final w = wallets[i];
                  final isActive = w.id == currentWallet?.id;
                  return KoraRow(
                    topLine: i == 0,
                    // Switching wallets asks for the app PIN. A wallet is a set of keys;
                    // moving between them with one stray tap — in a pocket, in somebody
                    // else's hands — is not a thing this application should allow.
                    onTap: isActive ? null : () async {
                      final ok = await askAppPin(
                        context,
                        title: 'Switch wallet',
                        explanation: 'Enter your app PIN to switch to ${w.name}.',
                      );
                      if (!ok || !context.mounted) return;
                      if (context.mounted) Navigator.pop(context);
                      await ref.read(currentWalletProvider.notifier).switchWallet(w.id);
                    },
                    children: [
                      // The same mark the home header carries, dimmed on the wallets
                      // that are not open.
                      Opacity(
                        opacity: isActive ? 1 : 0.45,
                        child: const KoraMark(size: 34),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w.name.toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                  style: kLabel(
                                      isActive
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                      size: 12.5, tracking: 0.06)),
                              const SizedBox(height: 4),
                              Text(w.type.displayName.toUpperCase(),
                                  style: kMonoText(AppColors.textSecondary, size: 10)),
                            ]),
                      ),
                      AnimatedTap(
                        onTap: () { _showRenameDialog(w.id, w.name); },
                        pressScale: 0.85,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(Icons.edit_outlined,
                              color: AppColors.textTertiary, size: 15),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isActive)
                        Text('✓', style: kMonoText(AppColors.textPrimary, size: 12))
                      else
                        Text('›', style: kMonoText(AppColors.textSecondary, size: 13)),
                    ],
                  );
                },
              ),
            ),
            allWallets.maybeWhen(
              data: (wallets) {
                final atLimit = wallets.length >= _kMaxWallets;
                return AnimatedTap(
                  onTap: () => _onAddWallet(wallets.length),
                  pressOpacity: 0.7,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
                    child: Row(children: [
                      Text(
                        atLimit
                            ? '${wallets.length}/$_kMaxWallets WALLETS'
                            : '+ ADD WALLET',
                        style: kLabel(
                            atLimit ? AppColors.textTertiary : AppColors.textSecondary,
                            size: 10, tracking: 0.14),
                      ),
                    ]),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(String walletId, String currentName) async {
    String nameValue = currentName;
    bool confirmed = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('Rename Wallet',
            style: kBody(AppColors.textPrimary, size: 13, weight: FontWeight.w600)),
        content: TextFormField(
          initialValue: currentName,
          autofocus: true,
          maxLength: 32,
          style: kBody(AppColors.textPrimary, size: 13),
          onChanged: (v) => nameValue = v,
          onFieldSubmitted: (_) {
            confirmed = true;
            Navigator.of(ctx).pop();
          },
          decoration: InputDecoration(
            hintText: 'Wallet name',
            hintStyle: kBody(AppColors.textTertiary, size: 13),
            filled: true,
            fillColor: AppColors.surface,
            counterStyle: kBody(AppColors.textTertiary, size: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: AppColors.accent, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: kBody(AppColors.textSecondary, size: 13)),
          ),
          TextButton(
            onPressed: () {
              confirmed = true;
              Navigator.of(ctx).pop();
            },
            child: Text('Save',
                style: kBody(AppColors.accent, size: 13, weight: FontWeight.w600)),
          ),
        ],
      ),
    );

    debugPrint('[Rename] confirmed=$confirmed nameValue="$nameValue" mounted=$mounted');
    if (!confirmed || nameValue.trim().isEmpty || !mounted) {
      debugPrint('[Rename] Skipped: confirmed=$confirmed empty=${nameValue.trim().isEmpty} unmounted=${!mounted}');
      return;
    }
    Navigator.of(context).pop(); // close sheet
    // Wait for both dialog + sheet dismiss animations before triggering
    // provider updates — otherwise _dependents.isEmpty assertion fires.
    await Future.delayed(const Duration(milliseconds: 350));
    debugPrint('[Rename] Calling renameWallet($walletId, "${nameValue.trim()}")');
    if (mounted) {
      await ref
          .read(currentWalletProvider.notifier)
          .renameWallet(walletId, nameValue.trim());
      debugPrint('[Rename] Done');
    } else {
      debugPrint('[Rename] unmounted after delay — skipped renameWallet');
    }
  }
}
