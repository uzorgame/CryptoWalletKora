import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/widgets/kora_rows.dart';
import 'package:kora/core/widgets/pin_gate.dart';

// The banner shown while the wallet's stored addresses still need migrating.
//
// The amber-edged bar every caution in this wallet wears, and the wallet's own PIN gate
// behind it — not a Material dialog with an obscured text field, which was the last form of
// its kind in the app.

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

  Future<void> _askAndFix() async {
    final pin = await askAppPinValue(
      context,
      title: 'Update addresses',
      explanation: 'Enter your app PIN so this wallet can re-derive its addresses.',
    );
    if (pin == null || !mounted) return;
    final ok = await ref.read(currentWalletProvider.notifier)
        .refreshWalletAddresses(pin);
    if (!mounted) return;
    if (ok) {
      setState(() => _dismissed = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update addresses')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsFullMigration = ref.watch(needsMigrationPinProvider);
    // Ask once, unprompted, when the wallet cannot finish setting itself up without the PIN.
    if (needsFullMigration && !_autoDialogShown) {
      _autoDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _askAndFix();
      });
    }
    if (_dismissed || !_needsMigration()) return const SizedBox.shrink();
    final label = needsFullMigration
        ? 'Wallet initialisation requires your PIN.'
        : 'LTC addresses need to be updated.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
      child: Stack(children: [
        KoraWarn(label, margin: const EdgeInsets.symmetric(horizontal: 22)),
        Positioned(
          right: 22, top: 0, bottom: 0,
          child: Row(children: [
            AnimatedTap(
              onTap: _askAndFix,
              pressOpacity: 0.7,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('FIX',
                    style: kLabel(AppColors.warning, size: 9.5, tracking: 0.16)),
              ),
            ),
            AnimatedTap(
              onTap: () => setState(() => _dismissed = true),
              pressScale: 0.85,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 2),
                child: Icon(Icons.close_rounded,
                    color: AppColors.textTertiary, size: 15),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
