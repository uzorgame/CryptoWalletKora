import 'package:flutter/material.dart';
import 'package:kora/core/widgets/kora_mark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/models/wallet.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.zero,
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.zero),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My Wallets',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  allWallets.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (wallets) {
                      final atLimit = wallets.length >= _kMaxWallets;
                      return AnimatedTap(
                        onTap: () => _onAddWallet(wallets.length),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: atLimit ? AppColors.cardElevated : AppColors.surface,
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_rounded,
                                color: atLimit ? AppColors.textTertiary : AppColors.textPrimary,
                                size: 16),
                            const SizedBox(width: 4),
                            Text(
                              atLimit ? '${wallets.length}/$_kMaxWallets' : 'Add',
                              style: TextStyle(
                                  color: atLimit ? AppColors.textTertiary : AppColors.textPrimary,
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            allWallets.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 1.5),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (wallets) => ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: wallets.length,
                itemBuilder: (_, i) {
                  final w = wallets[i];
                  final isActive = w.id == currentWallet?.id;
                  return AnimatedTap(
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
                    pressScale: 0.97,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.cardElevated
                            : AppColors.surface,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: isActive
                              ? AppColors.textPrimary.withValues(alpha: 0.3)
                              : AppColors.border,
                          width: isActive ? 1.0 : 0.5,
                        ),
                      ),
                      child: Row(children: [
                        // The same mark the home header carries, dimmed on the wallets
                        // that are not open.
                        Opacity(
                          opacity: isActive ? 1 : 0.45,
                          child: const KoraMark(size: 34),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.name,
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(w.type.displayName,
                                    style: TextStyle(
                                        color: AppColors.textSecondary, fontSize: 12)),
                              ]),
                        ),
                        if (isActive)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Text('Active',
                                style: TextStyle(
                                    color: AppColors.textPrimary, fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        // Rename button
                        AnimatedTap(
                          onTap: () { _showRenameDialog(w.id, w.name); },
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.zero,
                              border: Border.all(color: AppColors.border, width: 1),
                            ),
                            child: Icon(Icons.edit_rounded,
                                color: AppColors.textTertiary, size: 15),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
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
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: TextFormField(
          initialValue: currentName,
          autofocus: true,
          maxLength: 32,
          style: TextStyle(color: AppColors.textPrimary),
          onChanged: (v) => nameValue = v,
          onFieldSubmitted: (_) {
            confirmed = true;
            Navigator.of(ctx).pop();
          },
          decoration: InputDecoration(
            hintText: 'Wallet name',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            counterStyle: TextStyle(color: AppColors.textTertiary),
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
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              confirmed = true;
              Navigator.of(ctx).pop();
            },
            child: Text('Save',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w600)),
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
