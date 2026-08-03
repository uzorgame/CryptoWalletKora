import 'dart:typed_data';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as crypto;
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';

/// HD Wallet implementation following BIP32/BIP44 standards
/// Supports hierarchical deterministic key derivation
class HDWallet {
  final bip32.BIP32 _root;
  
  HDWallet._(this._root);
  
  /// Create HD Wallet from mnemonic phrase
  /// [mnemonic] - BIP39 mnemonic phrase (12/24 words)
  /// [passphrase] - Optional BIP39 passphrase
  factory HDWallet.fromMnemonic(String mnemonic, {String passphrase = ''}) {
    final seed = bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);
    final root = bip32.BIP32.fromSeed(seed);
    return HDWallet._(root);
  }
  
  /// Create HD Wallet from seed bytes
  factory HDWallet.fromSeed(Uint8List seed) {
    final root = bip32.BIP32.fromSeed(seed);
    return HDWallet._(root);
  }
  
  /// Derive child key using BIP44 path
  /// BIP44 format: m / purpose' / coin_type' / account' / change / address_index
  /// 
  /// Examples:
  /// - Ethereum: m/44'/60'/0'/0/0
  /// - Bitcoin: m/44'/0'/0'/0/0
  /// - Solana: m/44'/501'/0'/0/0
  bip32.BIP32 derivePath(String path) {
    return _root.derivePath(path);
  }
  
  /// Get Ethereum address at specific index
  /// Uses BIP44 path: m/44'/60'/0'/0/{index}
  String getEthereumAddress(int index) {
    final child = derivePath("m/44'/60'/0'/0/$index");
    return _publicKeyToEthereumAddress(child.publicKey);
  }
  
  /// Get Ethereum private key at specific index
  String getEthereumPrivateKey(int index) {
    final child = derivePath("m/44'/60'/0'/0/$index");
    return HEX.encode(child.privateKey!);
  }
  
  /// Get Bitcoin address at specific index
  /// Uses BIP44 path: m/44'/0'/0'/0/{index}
  String getBitcoinAddress(int index, {bool testnet = false}) {
    final child = derivePath("m/44'/0'/0'/0/$index");
    return _publicKeyToBitcoinAddress(child.publicKey, testnet: testnet);
  }
  
  /// Get Bitcoin private key at specific index (BIP44 — P2PKH legacy)
  String getBitcoinPrivateKey(int index) {
    final child = derivePath("m/44'/0'/0'/0/$index");
    return HEX.encode(child.privateKey!);
  }

  /// Get Bitcoin SegWit private key at specific index (BIP84 — P2WPKH bc1…)
  String getBitcoinSegwitPrivateKey(int index) {
    final child = derivePath("m/84'/0'/0'/0/$index");
    return HEX.encode(child.privateKey!);
  }
  
  /// Get Ethereum Classic address at specific index
  /// Uses BIP44 path: m/44'/61'/0'/0/{index} (coin_type 61 per SLIP-44)
  String getEthereumClassicAddress(int index) {
    final child = derivePath("m/44'/61'/0'/0/$index");
    return _publicKeyToEthereumAddress(child.publicKey);
  }

  /// Get Ethereum Classic private key at specific index
  String getEthereumClassicPrivateKey(int index) {
    final child = derivePath("m/44'/61'/0'/0/$index");
    return HEX.encode(child.privateKey!);
  }

  /// Get BSC address (same as Ethereum)
  /// Uses BIP44 path: m/44'/60'/0'/0/{index}
  String getBSCAddress(int index) {
    return getEthereumAddress(index);
  }
  
  /// Get BSC private key (same as Ethereum)
  String getBSCPrivateKey(int index) {
    return getEthereumPrivateKey(index);
  }
  
  /// Get Tron address at specific index
  /// Uses BIP44 path: m/44'/195'/0'/0/{index}
  String getTronAddress(int index) {
    final child = derivePath("m/44'/195'/0'/0/$index");
    return _publicKeyToTronAddress(child.publicKey);
  }
  
  /// Get Tron private key at specific index
  String getTronPrivateKey(int index) {
    final child = derivePath("m/44'/195'/0'/0/$index");
    return HEX.encode(child.privateKey!);
  }
  
  /// Get master public key (xpub)
  String get masterPublicKey {
    return _root.neutered().toBase58();
  }

  /// Get master private key (xprv) - DANGEROUS, use with caution
  String get masterPrivateKey {
    return _root.toBase58();
  }
  
  // ==================== HELPER METHODS ====================
  
  /// Convert compressed secp256k1 public key → Ethereum address (0x + 20 bytes).
  String _publicKeyToEthereumAddress(Uint8List publicKey) {
    final raw    = _decompressPublicKey(publicKey);         // 64 bytes (x ∥ y)
    final keccak = KeccakDigest(256);
    final hash   = keccak.process(raw);                    // 32 bytes
    return '0x${HEX.encode(hash.sublist(12))}';
  }

  /// Convert compressed secp256k1 public key → P2PKH Bitcoin address.
  String _publicKeyToBitcoinAddress(Uint8List publicKey, {bool testnet = false}) {
    // SHA256 then RIPEMD160
    final sha256Bytes = Uint8List.fromList(crypto.sha256.convert(publicKey).bytes);
    final ripemd      = RIPEMD160Digest();
    final hash160     = ripemd.process(sha256Bytes);
    // Version byte: 0x00 mainnet, 0x6F testnet
    final payload = Uint8List(21)..[0] = testnet ? 0x6F : 0x00;
    payload.setRange(1, 21, hash160);
    // Double-SHA256 checksum
    final c1   = Uint8List.fromList(crypto.sha256.convert(payload).bytes);
    final c2   = crypto.sha256.convert(c1).bytes;
    final full = Uint8List(25)
      ..setRange(0, 21, payload)
      ..setRange(21, 25, c2.sublist(0, 4));
    return _base58Encode(full);
  }

  /// Convert compressed secp256k1 public key → Tron address (Base58Check, prefix 0x41).
  String _publicKeyToTronAddress(Uint8List publicKey) {
    final raw    = _decompressPublicKey(publicKey);         // 64 bytes (x ∥ y)
    final keccak = KeccakDigest(256);
    final hash   = keccak.process(raw);                    // 32 bytes
    final payload = Uint8List(21)..[0] = 0x41;
    payload.setRange(1, 21, hash.sublist(12));
    final c1   = Uint8List.fromList(crypto.sha256.convert(payload).bytes);
    final c2   = crypto.sha256.convert(c1).bytes;
    final full = Uint8List(25)
      ..setRange(0, 21, payload)
      ..setRange(21, 25, c2.sublist(0, 4));
    return _base58Encode(full);
  }

  // ── low-level helpers ──────────────────────────────────────────────────────

  /// Decompress a 33-byte secp256k1 compressed public key to 64-byte raw (x ∥ y).
  static Uint8List _decompressPublicKey(Uint8List compressed) {
    final params = ECCurve_secp256k1();
    final point  = params.curve.decodePoint(compressed)!;
    final x      = _bigIntToBytes32(point.x!.toBigInteger()!);
    final y      = _bigIntToBytes32(point.y!.toBigInteger()!);
    return Uint8List(64)
      ..setRange(0, 32, x)
      ..setRange(32, 64, y);
  }

  static Uint8List _bigIntToBytes32(BigInt n) {
    final b = Uint8List(32);
    for (var i = 31; i >= 0; i--) {
      b[i] = (n & BigInt.from(0xff)).toInt();
      n >>= 8;
    }
    return b;
  }

  static String _base58Encode(Uint8List bytes) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var num = BigInt.zero;
    for (final b in bytes) num = (num << 8) | BigInt.from(b);
    var encoded = '';
    while (num > BigInt.zero) {
      final rem = (num % BigInt.from(58)).toInt();
      num = num ~/ BigInt.from(58);
      encoded = alphabet[rem] + encoded;
    }
    for (final b in bytes) {
      if (b == 0) encoded = '1$encoded'; else break;
    }
    return encoded;
  }
}

/// BIP44 Coin Types
class CoinType {
  static const int bitcoin = 0;
  static const int ethereum = 60;
  static const int solana = 501;
  static const int tron = 195;
  static const int bsc = 60; // Same as Ethereum
  static const int ethereumClassic = 61;
  
  /// Get BIP44 path for specific blockchain
  static String getPath(String blockchain, {int account = 0, int index = 0}) {
    final coinType = _getCoinType(blockchain);
    return "m/44'/$coinType'/$account'/0/$index";
  }
  
  static int _getCoinType(String blockchain) {
    switch (blockchain.toLowerCase()) {
      case 'bitcoin':
        return bitcoin;
      case 'ethereum':
        return ethereum;
      case 'solana':
        return solana;
      case 'tron':
        return tron;
      case 'bsc':
        return bsc;
      case 'ethereum_classic':
        return ethereumClassic;
      default:
        throw ArgumentError('Unsupported blockchain: $blockchain');
    }
  }
}
