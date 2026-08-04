import 'package:flutter/material.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/models/wallet.dart';
import 'package:kora/core/repositories/wallet_repository.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/features/onboarding/create_wallet_screen.dart';
import 'package:kora/features/onboarding/import_wallet_screen.dart';
import 'package:kora/features/home/home_screen.dart';

/// Screen shown after wallet deletion when other wallets exist
/// Allows user to select an existing wallet or create/import a new one
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
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Header
                    Text(
                      'Select Wallet',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a wallet to continue',
                      style: kBody(AppColors.textSecondary, size: 15),
                    ),
                    const SizedBox(height: 24),
                    
                    // Wallet list
                    Expanded(
                      child: _wallets.isEmpty
                          ? Center(
                              child: Text(
                                'No wallets available',
                                style: kBody(AppColors.textSecondary, size: 16),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _wallets.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final wallet = _wallets[index];
                                return _WalletCard(
                                  wallet: wallet,
                                  onTap: () => _selectWallet(wallet),
                                );
                              },
                            ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Create new wallet button
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CreateWalletScreen(),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: AppColors.background,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Create New Wallet'),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Import wallet button
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ImportWalletScreen(),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(double.infinity, 56),
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Import Existing Wallet'),
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.wallet,
    required this.onTap,
  });

  final Wallet wallet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.97,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.zero,
          ),
          child: Row(
            children: [
              // Wallet icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.zero,
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Wallet info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      style: kNum(AppColors.textPrimary, size: 17, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${wallet.assets.length} assets',
                      style: kBody(AppColors.textSecondary, size: 14),
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
