import 'dart:typed_data';
import 'package:kora/core/crypto/hd_wallet.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart' as crypto;

/// Tron Wallet
/// Address = Base58Check( 0x41 || last20(Keccak256(uncompressed_pubkey_64_bytes)) )
/// Same secp256k1 as Ethereum but different prefix and encoding
class TronWallet {
  final int _index;

  late final String _address;
  late final String _privateKey;
  late final String _publicKey;

  TronWallet._({required HDWallet hdWallet, required int index})
      : _index = index {
    _initializeKeys(hdWallet);
  }

  factory TronWallet.fromMnemonic(String mnemonic, {int index = 0}) {
    return TronWallet._(
      hdWallet: HDWallet.fromMnemonic(mnemonic),
      index: index,
    );
  }

  factory TronWallet.fromHdWallet(HDWallet hdWallet, {int index = 0}) =>
      TronWallet._(hdWallet: hdWallet, index: index);

  void _initializeKeys(HDWallet hdWallet) {
    _privateKey = hdWallet.getTronPrivateKey(_index);
    _publicKey  = _deriveUncompressedPublicKey(_privateKey);
    _address    = _generateAddress(_publicKey);
  }

  /// secp256k1: uncompressed public key = X (32 bytes) + Y (32 bytes) = 64 bytes
  String _deriveUncompressedPublicKey(String privateKeyHex) {
    final privBytes   = Uint8List.fromList(HEX.decode(privateKeyHex));
    final privBigInt  = _bytesToBigInt(privBytes);
    final G           = ECCurve_secp256k1().G;
    final point       = (G * privBigInt)!;
    final x = _bigIntToBytes(point.x!.toBigInteger()!, 32);
    final y = _bigIntToBytes(point.y!.toBigInteger()!, 32);
    final uncompressed = Uint8List(64)
      ..setRange(0, 32, x)
      ..setRange(32, 64, y);
    return HEX.encode(uncompressed);
  }

  /// Base58Check( 0x41 || last20(Keccak256(pubkey64)) )
  String _generateAddress(String publicKeyHex) {
    final pubKeyBytes = Uint8List.fromList(HEX.decode(publicKeyHex));

    // Keccak256 of the 64-byte uncompressed public key
    final keccak    = KeccakDigest(256);
    final keccakHash = keccak.process(pubKeyBytes);

    // Take last 20 bytes
    final addrHash = keccakHash.sublist(12); // 32 - 12 = 20

    // 0x41 prefix (Tron mainnet)
    final payload = Uint8List(21)
      ..[0] = 0x41;
    payload.setRange(1, 21, addrHash);

    // Double SHA256 checksum (4 bytes)
    final h1       = Uint8List.fromList(crypto.sha256.convert(payload).bytes);
    final h2       = crypto.sha256.convert(h1).bytes;
    final checksum = h2.sublist(0, 4);

    // 25-byte final payload
    final full = Uint8List(25)
      ..setRange(0, 21, payload)
      ..setRange(21, 25, checksum);

    return _base58Encode(full);
  }

  /// Sign message (double SHA256 then ECDSA)
  String signMessage(String message) {
    final msgBytes = Uint8List.fromList(message.codeUnits);
    final h1 = crypto.sha256.convert(msgBytes).bytes;
    final h2 = Uint8List.fromList(crypto.sha256.convert(h1).bytes);
    return _ecdsaSign(h2);
  }

  /// Sign a pre-hashed 32-byte transaction hash
  String signTransactionHash(Uint8List txHash) => _ecdsaSign(txHash);

  String _ecdsaSign(Uint8List hash) {
    final privKeyBytes  = Uint8List.fromList(HEX.decode(_privateKey));
    final privKeyBigInt = _bytesToBigInt(privKeyBytes);
    final domainParams  = ECCurve_secp256k1();
    final privKey       = ECPrivateKey(privKeyBigInt, domainParams);

    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    signer.init(true, PrivateKeyParameter<ECPrivateKey>(privKey));
    final sig = signer.generateSignature(hash) as ECSignature;

    final v = _recoveryByte(sig.r, sig.s, hash, privKeyBigInt, domainParams);

    return sig.r.toRadixString(16).padLeft(64, '0') +
           sig.s.toRadixString(16).padLeft(64, '0') +
           v.toRadixString(16).padLeft(2, '0');
  }

  /// Determine the 1-byte recovery ID (0 or 1) by trying both candidates
  /// and comparing the recovered public key against the known public key.
  int _recoveryByte(BigInt r, BigInt s, Uint8List hash,
      BigInt privKey, ECDomainParameters params) {
    final p = BigInt.parse(
        'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
        radix: 16);
    final n            = params.n;
    final G            = params.G;
    final expectedPub  = (G * privKey)!;

    for (var recId = 0; recId <= 1; recId++) {
      final x = r + BigInt.from(recId >> 1) * n;
      if (x >= p) continue;

      // y² = x³ + 7 (mod p);  p ≡ 3 (mod 4) → y = (y²)^((p+1)/4) mod p
      final y2 = (x.modPow(BigInt.from(3), p) + BigInt.from(7)) % p;
      var y    = y2.modPow((p + BigInt.one) >> 2, p);
      if ((y * y) % p != y2) continue;
      if (y.isOdd != ((recId & 1) == 1)) y = p - y;

      final R      = params.curve.createPoint(x, y);
      final rInv   = r.modInverse(n);
      final e      = _bytesToBigInt(hash) % n;
      final coeffR = (rInv * s) % n;
      final coeffG = (n - (rInv * e) % n) % n;
      final Q = (R * coeffR)! + (G * coeffG)!;
      if (Q == null) continue;

      if (Q.x?.toBigInteger() == expectedPub.x?.toBigInteger() &&
          Q.y?.toBigInteger() == expectedPub.y?.toBigInteger()) {
        return recId;
      }
    }
    return 0;
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  String _base58Encode(Uint8List bytes) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var num = _bytesToBigInt(bytes);
    var encoded = '';
    while (num > BigInt.zero) {
      final rem = (num % BigInt.from(58)).toInt();
      num = num ~/ BigInt.from(58);
      encoded = alphabet[rem] + encoded;
    }
    for (var i = 0; i < bytes.length && bytes[i] == 0; i++) {
      encoded = '1$encoded';
    }
    return encoded;
  }

  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) result = (result << 8) | BigInt.from(b);
    return result;
  }

  Uint8List _bigIntToBytes(BigInt n, int length) {
    final bytes = Uint8List(length);
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (n & BigInt.from(0xff)).toInt();
      n >>= 8;
    }
    return bytes;
  }

  // ── public getters ────────────────────────────────────────────────────────

  String get address    => _address;
  String get privateKey => _privateKey;
  String get publicKey  => _publicKey;
  int    get index      => _index;
}

class TronAddressUtils {
  static bool isValidAddress(String address) =>
      address.startsWith('T') && address.length == 34;
}
