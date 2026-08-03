import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/crypto/key_manager.dart';
import '../core/services/lock_service.dart';
import '../core/state/providers/wallet_provider.dart';
import '../core/theme/kora_design.dart';
import 'kora_app.dart';
import 'onboarding/onboarding_controller.dart';
import 'onboarding/onboarding_flow.dart';
import 'screens/lock_screen.dart';

/// Decides what the window shows: the first-run flow, the lock, or the wallet.
///
/// The decision is made from what is actually stored rather than from a flag written at some
/// earlier point. A "has onboarded" boolean can disagree with the store — and when it does,
/// the app either asks a returning user to start over or opens an empty wallet over real keys.
class KoraGate extends ConsumerStatefulWidget {
  const KoraGate({super.key, required this.version});

  final String version;

  @override
  ConsumerState<KoraGate> createState() => _KoraGateState();
}

class _KoraGateState extends ConsumerState<KoraGate> {
  bool _unlocked = false;

  /// Clears the lock notifier as well as the local flag.
  ///
  /// Both have to move together: the notifier is what the lifecycle observer sets, and a
  /// notifier left reading "locked" would fire again on the next rebuild and throw the user
  /// straight back to the passphrase they had just entered.
  void _unlock() {
    ref.read(lockProvider.notifier).unlock();
    setState(() => _unlocked = true);
  }

  /// The first wallet in the app, which is also what sets the app passphrase.
  ///
  /// Adding further wallets is done from inside the unlocked app, where the passphrase is
  /// already known — see `KoraApp`. Keeping the two apart means this path never has to ask
  /// whether a passphrase already exists.
  Future<void> _firstWallet(OnboardingResult result) async {
    final passphrase = result.passphrase;
    if (passphrase == null) return;

    await KeyManager.storeAppPin(passphrase);
    final notifier = ref.read(currentWalletProvider.notifier);
    if (result.mode == OnboardingMode.create) {
      await notifier.createWallet(
        name: result.name,
        mnemonic: result.mnemonic,
        pin: passphrase,
      );
    } else {
      await notifier.importWallet(
        name: result.name,
        mnemonic: result.mnemonic,
        pin: passphrase,
      );
    }

    // The wallet now exists, so `hasWalletsProvider` has to be asked again — otherwise the
    // gate keeps showing onboarding over a wallet that was just created.
    ref.invalidate(hasWalletsProvider);
    if (mounted) _unlock();
  }

  @override
  Widget build(BuildContext context) {
    // Auto-lock reports through `lockProvider`, which watches the app's lifecycle. It was
    // written, and the timeout was offered in settings, but nothing ever listened to it — so
    // the setting chose between behaviours that were all "stay unlocked". Watching it here is
    // what makes that setting mean something.
    ref.listen<bool>(lockProvider, (_, locked) {
      if (locked && _unlocked) setState(() => _unlocked = false);
    });

    return ref.watch(hasWalletsProvider).when(
          loading: () => const _Waiting(),
          // A store that cannot be read is not an empty store. Showing onboarding here would
          // invite the user to create a wallet over keys that are still there.
          error: (_, __) => const _Waiting(),
          data: (exists) {
            if (!exists) {
              return OnboardingFlow(
                firstRun: true,
                existingNames: const [],
                onDone: _firstWallet,
              );
            }
            if (!_unlocked) {
              return LockScreen(onUnlocked: _unlock);
            }
            return KoraApp(
              version: widget.version,
              onLock: () {
                ref.read(lockProvider.notifier).lock();
                setState(() => _unlocked = false);
              },
            );
          },
        );
  }
}

/// Shown only while the store is being read, which is a few milliseconds. Deliberately just
/// the background colour: a spinner that appears and vanishes within one frame reads as a
/// flicker, and makes an app that was fast look like an app that was busy.
class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Kora.of(context).bg,
        child: const SizedBox.expand(),
      );
}
