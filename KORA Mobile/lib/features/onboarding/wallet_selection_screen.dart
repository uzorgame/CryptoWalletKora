import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_button.dart';
import 'package:kora/core/widgets/kora_mark.dart';
import 'package:kora/core/widgets/kora_rows.dart';
import 'package:kora/core/models/wallet.dart';
import 'package:kora/core/repositories/wallet_repository.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/features/onboarding/create_wallet_screen.dart';
import 'package:kora/features/onboarding/import_wallet_screen.dart';
import 'package:kora/features/home/home_screen.dart';

/// Shown after a wallet is removed and another has to be opened before the app can go
/// anywhere.
///
/// A table of wallets, not a stack of cards: the monogram the header already carries, the
/// name, how much is in it, and a chevron. The wallet's worth sits at the right edge because
/// that is where every number in this application lives — and because choosing between
/// wallets by their asset count, which is all this screen used to offer, says nothing about
/// which one was meant.
class WalletSelectionScreen extends ConsumerStatefulWidget {
  const WalletSelectionScreen({super.key});

  @override
  ConsumerState<WalletSelectionScreen> createState() => _WalletSelectionScreenState();
}

class _WalletSelectionScreenState extends ConsumerState<WalletSelectionScreen> {
  List<Wallet> _wallets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final wallets = await WalletRepository().getAllWallets();
    if (mounted) {
      setState(() {
        _wallets = wallets;
        _loading = false;
      });
    }
  }

  Future<void> _selectWallet(Wallet wallet) async {
    // Set as current wallet
    await ref.read(currentWalletProvider.notifier).switchWallet(wallet.id);

    if (mounted) {
      // Navigate to home screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                    color: AppColors.textTertiary, strokeWidth: 1.5))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(padding: EdgeInsets.zero, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SELECT WALLET',
                                style: kLabel(AppColors.textTertiary,
                                    size: 9.5, tracking: 0.16)),
                            const SizedBox(height: 8),
                            Text('Choose a wallet\nto continue',
                                style: kNum(AppColors.textPrimary,
                                        size: 26, weight: FontWeight.w600)
                                    .copyWith(height: 1.15)),
                          ],
                        ),
                      ),
                      KoraSection(
                        'Wallets',
                        aside: _wallets.length == 1
                            ? '1 on this device'
                            : '${_wallets.length} on this device',
                      ),
                      if (_wallets.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text('NO WALLETS ON THIS DEVICE',
                                style: kLabel(AppColors.textTertiary,
                                    size: 10, tracking: 0.14)),
                          ),
                        )
                      else
                        for (final (i, w) in _wallets.indexed)
                          _WalletRow(
                            wallet: w,
                            topLine: i == 0,
                            onTap: () => _selectWallet(w),
                          ),
                      const SizedBox(height: 18),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: KoraCta(
                      label: 'Create new wallet',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CreateWalletScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: KoraGhost(
                      label: 'Import existing wallet',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ImportWalletScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                ],
              ),
      ),
    );
  }
}

/// One wallet: the monogram, its name, what it holds, and what that is worth.
class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.wallet, required this.onTap, this.topLine = false});

  final Wallet wallet;
  final VoidCallback onTap;
  final bool topLine;

  @override
  Widget build(BuildContext context) {
    final count = wallet.assets.length;
    final total = wallet.assets.fold<double>(0, (s, a) => s + a.balanceInUsd);

    return KoraRow(
      onTap: onTap,
      topLine: topLine,
      children: [
        const KoraMark(size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(wallet.name.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: kLabel(AppColors.textPrimary, size: 12.5, tracking: 0.06)),
            const SizedBox(height: 4),
            Text(count == 1 ? '1 ASSET' : '$count ASSETS',
                style: kMonoText(AppColors.textSecondary, size: 10)),
          ]),
        ),
        // A stored balance of zero means this wallet has not been opened since it was
        // written, not that it holds nothing — printing $0.00 would be a claim the screen
        // cannot make from what it has.
        if (total > 0) ...[
          const SizedBox(width: 10),
          Text(_money(total), style: kNum(AppColors.textPrimary, size: 13.5)),
        ],
        const SizedBox(width: 12),
        Text('›', style: kMonoText(AppColors.textSecondary, size: 13)),
      ],
    );
  }

  static String _money(double v) {
    if (v < 1000) return '\$${v.toStringAsFixed(2)}';
    if (v < 1000000) return '\$${(v / 1000).toStringAsFixed(2)}K';
    return '\$${(v / 1000000).toStringAsFixed(2)}M';
  }
}
