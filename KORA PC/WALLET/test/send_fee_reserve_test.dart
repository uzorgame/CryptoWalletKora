import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kora_windows/core/models/asset.dart';
import 'package:kora_windows/core/state/providers/currency_provider.dart';
import 'package:kora_windows/core/theme/kora_design.dart';
import 'package:kora_windows/ui/send/fee_option.dart';
import 'package:kora_windows/ui/send/send_view.dart';

/// The form must not accept an amount the chain will refuse.
///
/// The fee is not a separate pot. Spending a native balance to the last unit leaves nothing
/// to pay the miner with, and the form used to allow exactly that: the action went live, the
/// passphrase was asked for, and the failure arrived from the node afterwards. On a UTXO chain
/// the wallet had already shown the send as pending by then.
void main() {
  Asset coin({
    required String id,
    required String symbol,
    required String balance,
    AssetType type = AssetType.native,
    String blockchain = 'tron',
  }) =>
      Asset(
        id: id,
        symbol: symbol,
        name: symbol,
        blockchain: blockchain,
        contractAddress: type == AssetType.native ? 'Taddress' : 'Tcontract',
        decimals: 6,
        balance: balance,
        balanceInUsd: double.parse(balance),
        priceUsd: 1,
        priceChange24h: 0,
        type: type,
      );

  /// A tier that has actually come back from the chain, costing [native] of the fee coin.
  FeeOption arrived(double native, {String symbol = 'TRX'}) => FeeOption(
        id: 'normal',
        label: 'NETWORK FEE',
        wait: '~1 min',
        cost: native,
        native: native,
        symbol: symbol,
      );

  Future<void> open(
    WidgetTester tester, {
    required List<Asset> assets,
    required Asset selected,
    required List<FeeOption> fees,
  }) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: KoraTheme.dark,
        home: Scaffold(
          body: SendView(
            assets: assets,
            selected: selected,
            walletId: 'wallet-a',
            fees: fees,
            money: const CurrencyState(currency: AppCurrency.usd, rates: {}),
            onSelectAsset: (_) {},
            onReview: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String amount) async {
    await tester.enterText(find.byType(TextField).at(1), amount);
    await tester.pump();
  }

  testWidgets('spending the whole native balance is refused, leaving room for the fee',
      (tester) async {
    final trx = coin(id: 'tron', symbol: 'TRX', balance: '100');
    await open(tester, assets: [trx], selected: trx, fees: [arrived(1.1)]);

    await tester.enterText(find.byType(TextField).first, 'TRecipientAddressHere');
    await type(tester, '100');

    expect(find.text('REVIEW TRANSACTION'), findsOneWidget);
    expect(
      find.textContaining('for the network fee'),
      findsOneWidget,
      reason: 'the whole balance leaves nothing to pay the fee with',
    );
  });

  testWidgets('the largest amount that still covers the fee is accepted', (tester) async {
    final trx = coin(id: 'tron', symbol: 'TRX', balance: '100');
    await open(tester, assets: [trx], selected: trx, fees: [arrived(1.1)]);

    await tester.enterText(find.byType(TextField).first, 'TRecipientAddressHere');
    await type(tester, '98.9');

    expect(find.textContaining('for the network fee'), findsNothing);
  });

  testWidgets('MAX fills in the balance less the fee', (tester) async {
    final trx = coin(id: 'tron', symbol: 'TRX', balance: '100');
    await open(tester, assets: [trx], selected: trx, fees: [arrived(1.1)]);

    await tester.tap(find.text('MAX'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(double.parse(field.controller!.text), closeTo(98.9, 0.0001));
    expect(find.textContaining('for the network fee'), findsNothing,
        reason: 'what MAX fills in must itself be acceptable');
  });

  testWidgets('a token send says so when the wallet cannot pay the fee coin', (tester) async {
    // The classic case: USDT in the wallet, no TRX to move it with.
    final trx = coin(id: 'tron', symbol: 'TRX', balance: '0');
    final usdt = coin(id: 'tron-usdt', symbol: 'USDT', balance: '500', type: AssetType.token);
    await open(tester, assets: [trx, usdt], selected: usdt, fees: [arrived(27)]);

    expect(find.textContaining('for the network fee'), findsOneWidget);
  });

  testWidgets('a token send is allowed once the fee coin is held', (tester) async {
    final trx = coin(id: 'tron', symbol: 'TRX', balance: '50');
    final usdt = coin(id: 'tron-usdt', symbol: 'USDT', balance: '500', type: AssetType.token);
    await open(tester, assets: [trx, usdt], selected: usdt, fees: [arrived(27)]);

    expect(find.textContaining('for the network fee'), findsNothing);

    // A token's own balance is not reduced by the fee, so all of it can go.
    await tester.tap(find.text('MAX'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(double.parse(field.controller!.text), closeTo(500, 0.0001));
  });
}
