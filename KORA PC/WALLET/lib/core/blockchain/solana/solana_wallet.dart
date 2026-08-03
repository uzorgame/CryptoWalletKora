import 'dart:convert' show utf8;
import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as crypto;
import 'package:hex/hex.dart';
import 'package:pinenacl/ed25519.dart';

/// Solana Wallet Implementation
/// Uses Ed25519 keypair (RFC 8032) + SLIP-0010 derivation.
/// Path: m/44'/501'/0' (compatible with Trust Wallet).
/// Public key generation via pinenacl (TweetNaCl port).
class SolanaWallet {
  final int _index;

  late final String _address;
  late final String _privateKey;
  late final String _publicKey;

  SolanaWallet._({required Uint8List bip39Seed, required int index})
      : _index = index {
    _initializeKeysFromSeed(bip39Seed);
  }

  /// Create Solana wallet from mnemonic.
  factory SolanaWallet.fromMnemonic(String mnemonic, {int index = 0}) {
    final seed = Uint8List.fromList(bip39.mnemonicToSeed(mnemonic));
    return SolanaWallet._(bip39Seed: seed, index: index);
  }

  factory SolanaWallet.fromSeed(Uint8List bip39Seed, {int index = 0}) =>
      SolanaWallet._(bip39Seed: bip39Seed, index: index);

  void _initializeKeysFromSeed(Uint8List bip39Seed) {
    final privKey32   = _slip0010Derive(bip39Seed, [44, 501, 0]);
    final pubKeyBytes = _ed25519PubKey(privKey32);
    _privateKey = HEX.encode(privKey32);
    _publicKey  = HEX.encode(pubKeyBytes);
    _address    = _generateAddress(_publicKey);
  }

  /// SLIP-0010 Ed25519 key derivation (RFC 8032 / SLIP-0010).
  /// All path components are treated as hardened (Ed25519 requires it).
  static Uint8List _slip0010Derive(Uint8List seed, List<int> pathComponents) {
    final masterKey = utf8.encode('ed25519 seed');
    var I  = Uint8List.fromList(
        crypto.Hmac(crypto.sha512, masterKey).convert(seed).bytes);
    var kL = Uint8List.fromList(I.sublist(0, 32));
    var kR = Uint8List.fromList(I.sublist(32, 64));
    for (final idx in pathComponents) {
      final hardenedIdx = idx | 0x80000000;
      final data = Uint8List(37)
        ..[0] = 0x00
        ..setRange(1, 33, kL);
      data.buffer.asByteData().setUint32(33, hardenedIdx, Endian.big);
      final child = Uint8List.fromList(
          crypto.Hmac(crypto.sha512, kR).convert(data).bytes);
      kL = Uint8List.fromList(child.sublist(0, 32));
      kR = Uint8List.fromList(child.sublist(32, 64));
    }
    return kL;
  }

  /// Generates Solana address from public key hex (Base58 encoded).
  String _generateAddress(String publicKeyHex) {
    return _base58Encode(Uint8List.fromList(HEX.decode(publicKeyHex)));
  }
  
  /// Base58 encoding (Bitcoin alphabet)
  String _base58Encode(Uint8List bytes) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var num = BigInt.zero;
    
    // Convert bytes to BigInt
    for (var byte in bytes) {
      num = (num << 8) | BigInt.from(byte);
    }
    
    var encoded = '';
    while (num > BigInt.zero) {
      final remainder = (num % BigInt.from(58)).toInt();
      num = num ~/ BigInt.from(58);
      encoded = alphabet[remainder] + encoded;
    }
    
    // Add leading '1's for leading zero bytes
    for (var i = 0; i < bytes.length && bytes[i] == 0; i++) {
      encoded = '1' + encoded;
    }
    
    return encoded;
  }
  
  /// Get Solana address (Base58 encoded public key)
  String get address => _address;
  
  /// Get private key (use with caution!)
  String get privateKey => _privateKey;
  
  /// Get public key
  String get publicKey => _publicKey;
  
  /// Get derivation index
  int get index => _index;
  
  /// Sign a message using Ed25519 (RFC 8032).
  Uint8List signMessage(String message) =>
      _sign(Uint8List.fromList(message.codeUnits));

  /// Sign a transaction using Ed25519 (RFC 8032).
  Uint8List signTransaction(Uint8List transactionBytes) => _sign(transactionBytes);

  Uint8List _sign(Uint8List data) {
    final seed = Uint8List.fromList(HEX.decode(_privateKey).sublist(0, 32));
    return _ed25519Sign(seed, data);
  }

  // ── Ed25519 (RFC 8032) — extended twisted Edwards coordinates ──────────────
  // All point arithmetic avoids field inversions by using projective coords
  // (X:Y:Z:T) where x = X/Z, y = Y/Z, x·y = T/Z.
  // One inversion is needed only at the end to encode the result.

  // Field prime p = 2^255 - 19
  static final BigInt _ep =
      (BigInt.one << 255) - BigInt.from(19);
  // 2·d mod p  (d = -121665/121666 mod p, used in unified point addition)
  static final BigInt _ed2 = BigInt.parse(
      '16295367250680780974490674513165176452449234426866156013048792003956563747161');
  // Base point in extended coords [X, Y, Z, T]  (Z = 1, T = Gx·Gy mod p)
  static final List<BigInt> _eB = _makeBase();
  // Identity in extended coords
  static final List<BigInt> _eId = [BigInt.zero, BigInt.one, BigInt.one, BigInt.zero];

  static List<BigInt> _makeBase() {
    final gx = BigInt.parse(
        '15112221349535400772501151409588531511454012693041857206046113283949847762202');
    final gy = BigInt.parse(
        '46316835694926478169428394003475163141307993866256225615783033603165251855960');
    final p  = (BigInt.one << 255) - BigInt.from(19);
    return [gx, gy, BigInt.one, gx * gy % p];
  }

  // Reduce a (possibly negative) BigInt modulo p
  static BigInt _fe(BigInt a) => ((a % _ep) + _ep) % _ep;

  // Unified point addition for twisted Edwards a = -1 (Hisil et al.)
  // Cost: 8M (no inversion)
  static List<BigInt> _ptAdd(List<BigInt> P, List<BigInt> Q) {
    final X1 = P[0], Y1 = P[1], Z1 = P[2], T1 = P[3];
    final X2 = Q[0], Y2 = Q[1], Z2 = Q[2], T2 = Q[3];
    final p  = _ep;
    final A = _fe(Y1 - X1) * _fe(Y2 - X2) % p;
    final B = (Y1 + X1)   % p * ((Y2 + X2) % p) % p;
    final C = T1 * _ed2   % p * T2 % p;
    final D = Z1 * BigInt.two % p * Z2 % p;
    final E = _fe(B - A);
    final F = _fe(D - C);
    final G = (D + C) % p;
    final H = (B + A) % p;
    return [E * F % p, G * H % p, F * G % p, E * H % p];
  }

  // Scalar multiplication (double-and-add, LSB first)
  static List<BigInt> _ptMul(List<BigInt> P, BigInt n) {
    var Q = List<BigInt>.from(_eId);
    var R = List<BigInt>.from(P);
    var s = n;
    while (s > BigInt.zero) {
      if (s.isOdd) Q = _ptAdd(Q, R);
      R = _ptAdd(R, R);
      s >>= 1;
    }
    return Q;
  }

  // Encode extended point → 32-byte compressed little-endian (RFC 8032 §5.1.2)
  static Uint8List _ptEncode(List<BigInt> P) {
    final zinv = P[2].modPow(_ep - BigInt.two, _ep); // one inversion here
    final x = P[0] * zinv % _ep;
    final y = P[1] * zinv % _ep;
    final b = Uint8List(32);
    var yi = y;
    for (var i = 0; i < 32; i++) {
      b[i] = (yi & BigInt.from(0xff)).toInt();
      yi >>= 8;
    }
    if (x.isOdd) b[31] |= 0x80;
    return b;
  }

  // Little-endian bytes → BigInt
  static BigInt _leInt(List<int> bytes) {
    var n = BigInt.zero;
    for (var i = bytes.length - 1; i >= 0; i--) {
      n = (n << 8) | BigInt.from(bytes[i]);
    }
    return n;
  }


  // Derive Ed25519 public key from 32-byte seed (RFC 8032 §5.1.5) via pinenacl
  static Uint8List _ed25519PubKey(Uint8List seed) {
    final sk = SigningKey(seed: seed);
    return Uint8List.fromList(sk.verifyKey);
  }

  /// Public: derive Ed25519 compressed point from a raw 32-byte scalar
  /// (already clamped). Used by Monero (spend/view key).
  static Uint8List ed25519PubKeyFromScalar(Uint8List scalar32) =>
      _ptEncode(_ptMul(_eB, _leInt(scalar32)));

  // ─── Cross-chain address derivation (ed25519 family) ────────────────────────

  /// Derive raw 32-byte ed25519 public key for any chain (SLIP-0010).
  /// [pathComponents] are treated as hardened by the SLIP-0010 derivation.
  static Uint8List pubKeyForChain(String mnemonic, List<int> pathComponents) {
    final seed = Uint8List.fromList(bip39.mnemonicToSeed(mnemonic));
    return _ed25519PubKey(_slip0010Derive(seed, pathComponents));
  }

  static Uint8List pubKeyForChainFromSeed(Uint8List seed, List<int> pathComponents) =>
      _ed25519PubKey(_slip0010Derive(seed, pathComponents));

  /// Returns 32-byte ed25519 private key seed for any SLIP-0010 path.
  static Uint8List privateKeyForChain(String mnemonic, List<int> pathComponents) {
    final seed = Uint8List.fromList(bip39.mnemonicToSeed(mnemonic));
    return _slip0010Derive(seed, pathComponents);
  }

  /// Sign [msg] with ed25519 using a 32-byte SLIP-0010 seed. Returns 64-byte signature.
  static Uint8List ed25519Sign(Uint8List seed32, Uint8List msg) =>
      _ed25519Sign(seed32, msg);


  // RFC 8032 §5.1.6 Ed25519 signature via pinenacl
  static Uint8List _ed25519Sign(Uint8List seed, Uint8List msg) {
    final sk = SigningKey(seed: seed);
    final signed = sk.sign(msg); // signed = sig(64) + msg
    return Uint8List.fromList(signed.sublist(0, 64));
  }
}
