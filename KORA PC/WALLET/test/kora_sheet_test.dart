import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kora_windows/core/theme/kora_design.dart';
import 'package:kora_windows/ui/common/kora_button.dart';
import 'package:kora_windows/ui/common/kora_sheet.dart';

/// A sheet's actions must be reachable however long its body is.
///
/// The transaction sheet was one Column sized to its contents. Given a transaction with
/// enough rows, it grew past the window; a child laid out beyond its parent's bounds is
/// painted but not hit-tested, so DONE and COPY HASH were visible at the bottom of the screen
/// and did nothing. It worked on a short transaction, which is why it looked intermittent.
void main() {
  Future<int> tapsOnDone(WidgetTester tester, int bodyRows) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: KoraTheme.dark,
        home: Scaffold(
          body: KoraSheet(
            title: 'RECEIVED TRX',
            subtitle: 'TRON',
            body: [
              for (var i = 0; i < bodyRows; i++)
                const SizedBox(height: 60, child: Text('a row of the transaction')),
            ],
            actions: [KoraButton(label: 'DONE', onPressed: () => taps++)],
          ),
        ),
      ),
    );
    await tester.pump();

    final done = find.text('DONE');
    expect(done, findsOneWidget, reason: 'the action must be in the tree');
    await tester.tap(done, warnIfMissed: false);
    await tester.pump();
    return taps;
  }

  testWidgets('the action responds when the body is short', (tester) async {
    tester.view.physicalSize = const Size(1020, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    expect(await tapsOnDone(tester, 2), 1);
  });

  testWidgets('the action still responds when the body is far taller than the window',
      (tester) async {
    tester.view.physicalSize = const Size(1020, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Twenty rows of sixty pixels is well past a 620px window — the case that used to put the
    // buttons outside the sheet's box.
    expect(await tapsOnDone(tester, 20), 1);
  });

  testWidgets('a long body scrolls rather than overflowing', (tester) async {
    tester.view.physicalSize = const Size(1020, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tapsOnDone(tester, 20);
    // An overflow would have been reported by the framework as an exception during layout.
    expect(tester.takeException(), isNull);
  });
}
