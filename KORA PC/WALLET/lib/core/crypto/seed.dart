import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:bip39/bip39.dart' as bip39;

/// Turns a recovery phrase into a BIP-39 seed, off the interface thread.
///
/// `mnemonicToSeed` is PBKDF2-HMAC-SHA512 at 2048 iterations with no yield point in it —
/// somewhere between eighty and two hundred milliseconds of uninterruptible work. Every
/// executor called it synchronously inside `execute()`, which meant the window froze the
/// instant the user confirmed a transaction and before a single byte had gone to the network.
/// That is the worst moment in the application to stop responding: the user has just agreed
/// to move money and cannot tell whether the press registered.
///
/// The rest of the crypto in this app already runs in an isolate — `EncryptionService` and
/// the address derivation both use `compute`. The signing path was the one that was missed.
Future<Uint8List> mnemonicSeed(String mnemonic) => compute(_seedWorker, mnemonic);

/// Top-level, as `compute` requires.
Uint8List _seedWorker(String mnemonic) => Uint8List.fromList(bip39.mnemonicToSeed(mnemonic));
