import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'services/market_service.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets/mark.dart';
import 'widgets/rise.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Smaller than the browser mock-up measured, because a browser page and a desktop window
  // do not occupy a screen the same way: the same logical size that reads as a compact panel
  // in a page reads as a large window on a 150% display.
  const options = WindowOptions(
    size: Size(1020, 620),
    minimumSize: Size(880, 540),
    center: true,
    // Opaque. A transparent window background makes the compositor blend every frame against
    // whatever is behind it, and nothing in this interface is translucent.
    backgroundColor: Color(0xFF0A0A0A),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    title: 'KORA Market',
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await ThemeNotifier.instance.init();
  // Fired without awaiting: the splash is playing regardless, and the first paint should not
  // wait on a network round trip.
  MarketService.instance.start();

  runApp(const KoraMarketApp());
}

class KoraMarketApp extends StatelessWidget {
  const KoraMarketApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ThemeNotifier.instance,
        builder: (context, _) => MaterialApp(
          title: 'KORA Market',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeNotifier.instance.mode,
          home: const _Root(),
        ),
      );
}

/// The splash sits over the shell rather than in front of it on a route: the window is the
/// same window throughout, and fading a layer away is closer to what the app is doing than
/// pushing a page is.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with TickerProviderStateMixin {
  /// The mark scales in on its own curve; every other element rises on a shared one, offset
  /// by its own delay. These are the prototype's numbers, not approximations of them.
  late final AnimationController _mark = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  /// The hairline fills over a second and a half, independent of the entrances above it.
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  bool _gone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2100), () async {
      if (!mounted) return;
      await _exit.forward();
      if (mounted) setState(() => _gone = true);
    });
  }

  @override
  void dispose() {
    _mark.dispose();
    _line.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const MarketShell(),
          if (!_gone)
            FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0).animate(_exit),
              child: _Splash(mark: _mark, line: _line),
            ),
        ],
      );
}

class _Splash extends StatelessWidget {
  const _Splash({required this.mark, required this.line});

  final Animation<double> mark;
  final Animation<double> line;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    // Material, not a plain ColoredBox: the splash is a sibling of the Scaffold rather than
    // a child of it, and text with no Material ancestor is painted with Flutter's yellow
    // debug underline.
    return Material(
      color: p.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: mark,
              builder: (context, _) {
                final t = kEase.transform(mark.value);
                return Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: 0.86 + 0.14 * t,
                    child: KoraMark(size: 62, color: p.text),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            Rise(
              generation: 0,
              delay: const Duration(milliseconds: 120),
              duration: const Duration(milliseconds: 600),
              child: Text('KORA',
                  style: TextStyle(
                    fontFamily: kDisplay,
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 44 * 0.14,
                    color: p.text,
                    height: 1,
                  )),
            ),
            const SizedBox(height: 6),
            Rise(
              generation: 0,
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 600),
              // The tracking pushes the word right of centre, so it is pulled back by one
              // letter-space — the same correction the prototype makes with padding-left.
              child: Padding(
                padding: const EdgeInsets.only(left: 11 * 0.42),
                child: Text('MARKET', style: label(p.text2, size: 11, tracking: 0.42)),
              ),
            ),
            const SizedBox(height: 30),
            Rise(
              generation: 0,
              delay: const Duration(milliseconds: 300),
              duration: const Duration(milliseconds: 600),
              child: SizedBox(
                width: 190,
                height: 1,
                child: ColoredBox(
                  color: p.border,
                  child: AnimatedBuilder(
                    animation: line,
                    builder: (context, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: kEase.transform(line.value),
                      child: ColoredBox(color: p.text),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Rise(
              generation: 0,
              delay: const Duration(milliseconds: 400),
              duration: const Duration(milliseconds: 600),
              child: Text('REAL-TIME PRICES · TOP ${kSymbols.length} ASSETS · BINANCE',
                  style: label(p.text3, size: 10, tracking: 0.18)),
            ),
          ],
        ),
      ),
    );
  }
}
