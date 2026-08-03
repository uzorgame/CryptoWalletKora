import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/key_manager.dart';
import '../../core/models/wallet.dart';
import '../../core/state/providers/wallet_provider.dart';
import '../../core/theme/kora_design.dart';
import '../onboarding/onboarding_controller.dart';
import '../onboarding/onboarding_flow.dart';
import 'kora_sheet.dart';
import 'passphrase_gate.dart';

/// The two wallet actions that are offered from more than one place.
///
/// Both the rail's switcher and the settings page can open another wallet and add a new one.
/// They live here together so the passphrase prompt cannot end up on one path and not the
/// other — a gate that is only sometimes there is not a gate.

/// Opens another wallet, once the app passphrase has been given again.
///
/// The passphrase is not needed to read the wallet — its balances are already on disk — so
/// this is a deliberate gate rather than a technical one. Which wallet is open decides which
/// keys the next signature comes from, and that is not something an unattended machine should
/// be able to change.
Future<void> switchWalletWithPassphrase(
  BuildContext context,
  WidgetRef ref,
  Wallet wallet,
) async {
  if (wallet.id == ref.read(currentWalletProvider).value?.id) return;

  final passphrase = await askPassphrase(
    context,
    title: 'OPEN ${wallet.name.toUpperCase()}',
    explanation: 'Sending from this point on signs with this wallet’s keys.',
    confirmLabel: 'OPEN WALLET',
  );
  if (passphrase == null || !context.mounted) return;

  if (!await KeyManager.verifyAppPin(passphrase)) {
    if (!context.mounted) return;
    await _refuse(context, 'NOT OPENED',
        'That is not the app passphrase. The wallet that was open is still open.');
    return;
  }

  await ref.read(currentWalletProvider.notifier).switchWallet(wallet.id);
}

/// Adds a wallet to an app that already has one.
///
/// The passphrase is asked for and checked BEFORE the flow starts, not after: the new wallet
/// is encrypted under it, and discovering at the end that it was wrong would mean throwing
/// away a recovery phrase the user has just written down by hand.
Future<void> addWalletWithPassphrase(BuildContext context, WidgetRef ref) async {
  final passphrase = await askPassphrase(
    context,
    title: 'ADD WALLET',
    explanation: 'The new wallet is encrypted under the passphrase this app already uses.',
    confirmLabel: 'CONTINUE',
  );
  if (passphrase == null || !context.mounted) return;

  if (!await KeyManager.verifyAppPin(passphrase)) {
    if (!context.mounted) return;
    await _refuse(
        context, 'NOT ADDED', 'That is not the app passphrase, so nothing was created.');
    return;
  }
  if (!context.mounted) return;

  final existing = ref.read(allWalletsProvider).valueOrNull ?? const <Wallet>[];
  final result = await Navigator.of(context).push<OnboardingResult>(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: kViewSlide,
      pageBuilder: (context, _, __) => OnboardingFlow(
        firstRun: false,
        existingNames: [for (final w in existing) w.name],
        onDone: (result) => Navigator.of(context).pop(result),
        onCancel: () => Navigator.of(context).pop(),
      ),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: kEase),
        child: child,
      ),
    ),
  );
  // The onboarding route can sit on screen for minutes while a recovery phrase is written
  // down by hand, and auto-lock can tear the whole tree down underneath it. Reading a provider
  // off a disposed ref throws, so the flow stops here rather than half-creating a wallet.
  if (result == null || !context.mounted) return;

  final notifier = ref.read(currentWalletProvider.notifier);
  if (result.mode == OnboardingMode.create) {
    await notifier.createWallet(
        name: result.name, mnemonic: result.mnemonic, pin: passphrase);
  } else {
    await notifier.importWallet(
        name: result.name, mnemonic: result.mnemonic, pin: passphrase);
  }
  ref.invalidate(allWalletsProvider);
}

Future<void> _refuse(BuildContext context, String title, String body) => showKoraSheet<void>(
      context,
      builder: (context) => KoraNotice(title: title, body: body),
    );
