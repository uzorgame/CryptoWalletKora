import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/crypto/encryption.dart';
import 'core/services/binance_price_stream.dart';
import 'core/services/localization_service.dart';
import 'core/services/theme_notifier.dart';
import 'core/theme/kora_design.dart';
import 'ui/kora_gate.dart';

/// The app version, shown in settings. Kept here rather than read from the package-info
/// plugin: one string in one place beats a plugin call and an await on every settings build.
const String kVersion = '5.1.1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    // The same window as Market, so the two products sit side by side without one looking
    // like a dialog belonging to the other.
    size: Size(1020, 620),
    // Growing is allowed, shrinking is not: the tables start dropping columns below this
    // width, and a wallet that hides a column of numbers is lying by omission. There is
    // deliberately no maximum.
    minimumSize: Size(1020, 620),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setIcon('assets/kora_logo.png');
    await windowManager.show();
    await windowManager.focus();
  });

  await LocalizationService.instance.loadSavedLanguage();

  // Both of these are slow the first time and cheap afterwards, and both are first needed at
  // the worst possible moment — the passphrase prompt, and the first price tick. Started here
  // without awaiting, they are warm before the user reaches either.
  unawaited(EncryptionService.warmupCrypto());
  BinancePriceStream.instance.start();

  runApp(const ProviderScope(child: KoraDesktop()));
}

class KoraDesktop extends StatelessWidget {
  const KoraDesktop({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ThemeNotifier.instance,
        builder: (_, __) => MaterialApp(
          title: 'KORA Wallet',
          debugShowCheckedModeBanner: false,
          // Both themes are built once and held as statics — see kora_design.dart. Building a
          // ThemeData on every root rebuild re-derives every text style in the app.
          theme: KoraTheme.light,
          darkTheme: KoraTheme.dark,
          themeMode: ThemeNotifier.instance.mode,
          home: const KoraGate(version: kVersion),
        ),
      );
}
