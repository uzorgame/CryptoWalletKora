import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:kora_windows/core/blockchain/bitcoin/bitcoin_wallet.dart';
import 'package:kora_windows/core/blockchain/solana/solana_wallet.dart';
import 'package:kora_windows/core/blockchain/tron/tron_wallet.dart';
import 'package:kora_windows/core/crypto/hd_wallet.dart';
import 'package:kora_windows/core/crypto/seed.dart';

/// The signing key must derive to the address the wallet receives on.
///
/// The send executors were changed to take their BIP-39 seed from `mnemonicSeed`, which runs
/// PBKDF2 in an isolate instead of on the interface thread. Nothing about the derivation was
/// meant to change — only where it runs — but "meant to" is not a guarantee anyone should have
/// to accept about a wallet. If the seed differed by one byte, every address would differ,
/// signatures would be made by keys that own nothing, and a send would go out from an account
/// that is not the one on screen.
///
/// So this pins the two paths against each other:
///   - the RECEIVE path, `Uint8List.fromList(bip39.mnemonicToSeed(m))`, exactly as
///     `wallet_initialization_service.dart` writes it — that file was not touched, and it is
///     what produced every address currently stored in a user's wallet;
///   - the SEND path, `await mnemonicSeed(m)`, which the executors now use.
///
/// They must agree byte for byte, and every chain's address must come out the same from both.
void main() {
  // The BIP-39 specification's own test vector. Fixed on purpose: a random phrase would make a
  // failure unreproducible, which is the opposite of what this test is for.
  const phrase =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  /// Exactly the expression wallet_initialization_service.dart uses to build receive addresses.
  Uint8List receivePathSeed(String mnemonic) =>
      Uint8List.fromList(bip39.mnemonicToSeed(mnemonic));

  test('the send path derives the identical BIP-39 seed to the receive path', () async {
    final fromReceive = receivePathSeed(phrase);
    final fromSend = await mnemonicSeed(phrase);

    expect(fromSend.length, 64, reason: 'a BIP-39 seed is 512 bits');
    expect(
      fromSend,
      orderedEquals(fromReceive),
      reason: 'moving PBKDF2 into an isolate must not change one byte of its output',
    );
  });

  test('every chain derives the same address from both paths', () async {
    final receive = HDWallet.fromSeed(receivePathSeed(phrase));
    final receiveSeed = receivePathSeed(phrase);

    final sendSeed = await mnemonicSeed(phrase);
    final send = HDWallet.fromSeed(sendSeed);

    // One entry per chain the app can send from, named the way the wallet names them.
    final expected = <String, String>{
      'bitcoin': BitcoinWallet.fromHdWallet(receive).address,
      'ethereum': receive.getEthereumAddress(0),
      'ethereum_classic': receive.getEthereumClassicAddress(0),
      'tron': TronWallet.fromHdWallet(receive).address,
      'solana': SolanaWallet.fromSeed(receiveSeed).address,
      'litecoin': BitcoinWallet.addressForLtcSegwit(receive),
      'bitcoin_cash': BitcoinWallet.addressForBCHCashAddr(receive),
    };

    final actual = <String, String>{
      'bitcoin': BitcoinWallet.fromHdWallet(send).address,
      'ethereum': send.getEthereumAddress(0),
      'ethereum_classic': send.getEthereumClassicAddress(0),
      'tron': TronWallet.fromHdWallet(send).address,
      'solana': SolanaWallet.fromSeed(sendSeed).address,
      'litecoin': BitcoinWallet.addressForLtcSegwit(send),
      'bitcoin_cash': BitcoinWallet.addressForBCHCashAddr(send),
    };

    for (final chain in expected.keys) {
      expect(
        actual[chain],
        expected[chain],
        reason: 'the key that signs a $chain transaction must own the $chain address on screen',
      );
    }

    // A guard against the whole thing passing vacuously: if the derivation silently returned
    // empty strings, every comparison above would be true and mean nothing.
    for (final entry in expected.entries) {
      expect(entry.value, isNotEmpty, reason: '${entry.key} derived no address at all');
    }
  });

  test('the seed is stable across repeated derivation', () async {
    // Two isolate round-trips must agree; a race in compute() would show up here rather than
    // in somebody's transaction.
    final a = await mnemonicSeed(phrase);
    final b = await mnemonicSeed(phrase);
    expect(a, orderedEquals(b));
  });
}
