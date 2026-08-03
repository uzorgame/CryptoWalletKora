import 'package:kora/core/crypto/hd_wallet.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

/// Bitcoin Wallet Implementation
/// Підтримує різні типи адрес: P2PKH (Legacy), P2WPKH (SegWit), P2SH (Nested SegWit)
class BitcoinWallet {
  final HDWallet _hdWallet;
  final bool _testnet;
  final BitcoinAddressType _addressType;
  final int _index;
  
  late final String _address;
  late final String _privateKey;
  late final String _publicKey;
  
  BitcoinWallet._({
    required HDWallet hdWallet,
    required bool testnet,
    required BitcoinAddressType addressType,
    required int index,
  })  : _hdWallet = hdWallet,
        _testnet = testnet,
        _addressType = addressType,
        _index = index {
    _initializeKeys();
  }
  
  /// Create Bitcoin wallet from mnemonic
  /// [mnemonic] - BIP39 mnemonic phrase
  /// [testnet] - Use testnet (default: false)
  /// [addressType] - Address type (default: P2WPKH - SegWit)
  /// [index] - Derivation index (default: 0)
  /// Derive P2PKH address for any Bitcoin-style coin (LTC…).
  /// [coinType] — BIP44 coin-type: LTC=2
  /// [versionByte] — P2PKH prefix: LTC=0x30
  static String addressForAltcoin(
    HDWallet hdWallet, {
    required int coinType,
    required int versionByte,
  }) {
    final child    = hdWallet.derivePath("m/44'/$coinType'/0'/0/0");
    final privHex  = HEX.encode(child.privateKey!);

    // secp256k1 compressed public key
    final privBytes = Uint8List.fromList(HEX.decode(privHex));
    final params    = ECCurve_secp256k1();
    final point     = params.G * _bytesToBigIntStatic(privBytes);
    final x = point!.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    final prefix   = y.isEven ? 0x02 : 0x03;
    final xBytes   = _bigIntToBytesStatic(x, 32);
    final pubKey   = Uint8List(33)..[0] = prefix;
    pubKey.setRange(1, 33, xBytes);

    // hash160 = RIPEMD160(SHA256(pubKey))
    final sha256   = crypto.sha256.convert(pubKey).bytes;
    final ripemd   = RIPEMD160Digest();
    final hash160  = ripemd.process(Uint8List.fromList(sha256));

    // version byte + hash160
    final payload  = Uint8List(21)..[0] = versionByte;
    payload.setRange(1, 21, hash160);

    // Base58Check
    final h1       = crypto.sha256.convert(payload).bytes;
    final h2       = crypto.sha256.convert(h1).bytes;
    final full     = Uint8List(25);
    full.setRange(0, 21, payload);
    full.setRange(21, 25, h2.sublist(0, 4));

    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var num = _bytesToBigIntStatic(full);
    var encoded = '';
    while (num > BigInt.zero) {
      final rem = (num % BigInt.from(58)).toInt();
      num = num ~/ BigInt.from(58);
      encoded = alphabet[rem] + encoded;
    }
    for (var i = 0; i < full.length && full[i] == 0; i++) {
      encoded = '1$encoded';
    }
    return encoded;
  }

  /// Derive BCH address in CashAddr format (bitcoincash:q…) using BIP44 path m/44'/145'/0'/0/0.
  /// Same private key as addressForAltcoin(coinType:145) — just re-encoded as CashAddr.
  static String addressForBCHCashAddr(HDWallet hdWallet) {
    final child    = hdWallet.derivePath("m/44'/145'/0'/0/0");
    final privHex  = HEX.encode(child.privateKey!);
    final privBytes = Uint8List.fromList(HEX.decode(privHex));
    final params   = ECCurve_secp256k1();
    final point    = params.G * _bytesToBigIntStatic(privBytes);
    final x = point!.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    final pfx      = y.isEven ? 0x02 : 0x03;
    final xBytes   = _bigIntToBytesStatic(x, 32);
    final pubKey   = Uint8List(33)..[0] = pfx;
    pubKey.setRange(1, 33, xBytes);
    final sha256   = crypto.sha256.convert(pubKey).bytes;
    final ripemd   = RIPEMD160Digest();
    final hash160  = ripemd.process(Uint8List.fromList(sha256));
    // CashAddr encoding (BCH-specific polymod, different from bech32)
    const charset  = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    // Spec: convert (version_byte || hash160) together: 21 bytes → 34 5-bit groups
    final versionAndHash = Uint8List(21)..[0] = 0x00;
    versionAndHash.setRange(1, 21, hash160);
    final payload = _convertBitsStatic(versionAndHash, 8, 5, true);
    const hrp       = 'bitcoincash';
    final hrpExp    = hrp.codeUnits.map((c) => c & 0x1f).toList()..add(0);
    final ckInput   = [...hrpExp, ...payload, 0, 0, 0, 0, 0, 0, 0, 0];
    final poly      = _cashAddrPolymod(ckInput);
    final checksum  = List.generate(8, (i) => (poly >> (5 * (7 - i))) & 0x1f);
    return [...payload, ...checksum].map((d) => charset[d]).join();
  }

  static int _cashAddrPolymod(List<int> values) {
    var c = 1;
    for (final d in values) {
      final c0 = c >> 35;
      c = ((c & 0x07ffffffff) << 5) ^ d;
      if (c0 & 1  != 0) c ^= 0x98f2bc8e61;
      if (c0 & 2  != 0) c ^= 0x79b76d99e2;
      if (c0 & 4  != 0) c ^= 0xf33e5fb3c4;
      if (c0 & 8  != 0) c ^= 0xae2eabe2a8;
      if (c0 & 16 != 0) c ^= 0x1e4f43e470;
    }
    return c ^ 1;
  }

  /// Derive native-SegWit P2WPKH address for Litecoin using BIP84 path m/84'/2'/0'/0/0.
  /// Result starts with 'ltc1q' (bech32, mainnet).
  static String addressForLtcSegwit(HDWallet hdWallet) {
    final child    = hdWallet.derivePath("m/84'/2'/0'/0/0");
    final privHex  = HEX.encode(child.privateKey!);
    final privBytes = Uint8List.fromList(HEX.decode(privHex));
    final params   = ECCurve_secp256k1();
    final point    = params.G * _bytesToBigIntStatic(privBytes);
    final x = point!.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    final prefix   = y.isEven ? 0x02 : 0x03;
    final xBytes   = _bigIntToBytesStatic(x, 32);
    final pubKey   = Uint8List(33)..[0] = prefix;
    pubKey.setRange(1, 33, xBytes);
    final sha256   = crypto.sha256.convert(pubKey).bytes;
    final ripemd   = RIPEMD160Digest();
    final hash160  = ripemd.process(Uint8List.fromList(sha256));
    // Bech32 P2WPKH with HRP='ltc', witness version 0
    const charset  = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final converted = _convertBitsStatic(hash160, 8, 5, true);
    final data     = [0, ...converted]; // prepend witness version 0
    final checksum = _bech32ChecksumStatic('ltc', data);
    return 'ltc1' + ([...data, ...checksum]).map((d) => charset[d]).join();
  }

  /// Returns {privateKeyHex, pubKeyHex} for BIP84 path m/84'/[coinType]'/0'/0/0.
  /// Used for native SegWit altcoins (e.g. LTC).
  static ({String privateKeyHex, String pubKeyHex}) keysForCoinTypeSegwit(
    String mnemonic, {
    required int coinType,
  }) {
    final hdWallet  = HDWallet.fromMnemonic(mnemonic);
    final child     = hdWallet.derivePath("m/84'/$coinType'/0'/0/0");
    final privBytes = Uint8List.fromList(child.privateKey!);
    final params    = ECCurve_secp256k1();
    final point     = params.G * _bytesToBigIntStatic(privBytes);
    final x = point!.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    final pfx    = y.isEven ? 0x02 : 0x03;
    final pubKey = Uint8List(33)..[0] = pfx;
    pubKey.setRange(1, 33, _bigIntToBytesStatic(x, 32));
    return (
      privateKeyHex: HEX.encode(privBytes),
      pubKeyHex:     HEX.encode(pubKey),
    );
  }

  /// Returns {privateKeyHex, pubKeyHex} for BIP44 path m/44'/[coinType]'/0'/0/0.
  /// Used by send_screen.dart for UTXO signing.
  static ({String privateKeyHex, String pubKeyHex}) keysForCoinType(
    String mnemonic, {
    required int coinType,
  }) {
    final hdWallet  = HDWallet.fromMnemonic(mnemonic);
    final child     = hdWallet.derivePath("m/44'/$coinType'/0'/0/0");
    final privBytes = Uint8List.fromList(child.privateKey!);
    final params    = ECCurve_secp256k1();
    final point     = params.G * _bytesToBigIntStatic(privBytes);
    final x = point!.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    final pfx    = y.isEven ? 0x02 : 0x03;
    final pubKey = Uint8List(33)..[0] = pfx;
    pubKey.setRange(1, 33, _bigIntToBytesStatic(x, 32));
    return (
      privateKeyHex: HEX.encode(privBytes),
      pubKeyHex:     HEX.encode(pubKey),
    );
  }

  /// Convert Ethereum 0x address to bech32 (Injective 'inj1…', etc.)
  /// Injective uses ETH coin_type=60 — so the key is the same as ETH.
  static String ethAddressToBech32(String ethAddress, String hrp) {
    final hex   = ethAddress.startsWith('0x') ? ethAddress.substring(2) : ethAddress;
    final bytes = Uint8List.fromList(HEX.decode(hex.padLeft(40, '0')));
    return _bech32EncodeStatic(hrp, bytes);
  }

  /// Derive P2PKH address with a 2-byte version prefix (DCR 'Ds…').
  static String addressForAltcoin2Byte(
    HDWallet hdWallet, {
    required int coinType,
    required int versionByte1,
    required int versionByte2,
  }) {
    final child     = hdWallet.derivePath("m/44'/$coinType'/0'/0/0");
    final privBytes = Uint8List.fromList(HEX.decode(HEX.encode(child.privateKey!)));
    final params    = ECCurve_secp256k1();
    final point     = params.G * _bytesToBigIntStatic(privBytes);
    final x = point!.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    final pfx    = y.isEven ? 0x02 : 0x03;
    final pubKey = Uint8List(33)..[0] = pfx;
    pubKey.setRange(1, 33, _bigIntToBytesStatic(x, 32));
    final sha256  = crypto.sha256.convert(pubKey).bytes;
    final ripemd  = RIPEMD160Digest();
    final hash160 = ripemd.process(Uint8List.fromList(sha256));
    final payload = Uint8List(22)..[0] = versionByte1..[1] = versionByte2;
    payload.setRange(2, 22, hash160);
    final h1   = crypto.sha256.convert(payload).bytes;
    final h2   = crypto.sha256.convert(h1).bytes;
    final full = Uint8List(26);
    full.setRange(0, 22, payload);
    full.setRange(22, 26, h2.sublist(0, 4));
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var num = _bytesToBigIntStatic(full);
    var encoded = '';
    while (num > BigInt.zero) {
      final rem = (num % BigInt.from(58)).toInt();
      num = num ~/ BigInt.from(58);
      encoded = alphabet[rem] + encoded;
    }
    for (var i = 0; i < full.length && full[i] == 0; i++) {
      encoded = '1$encoded';
    }
    return encoded;
  }

  // ─── Additional secp256k1 chain address methods ───────────────────────────

  /// ICON (ICX): 'hx' + last 20 bytes of Keccak256(uncompressed 64-byte pubkey).
  static String addressForICX(String mnemonic) {
    final hdWallet  = HDWallet.fromMnemonic(mnemonic);
    final child     = hdWallet.derivePath("m/44'/74'/0'/0/0");
    final privBytes = Uint8List.fromList(HEX.decode(HEX.encode(child.privateKey!)));
    final params    = ECCurve_secp256k1();
    final point     = params.G * _bytesToBigIntStatic(privBytes);
    final x = point!.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    final pub64 = Uint8List(64)
      ..setRange(0, 32, _bigIntToBytesStatic(x, 32))
      ..setRange(32, 64, _bigIntToBytesStatic(y, 32));
    final hash = KeccakDigest(256).process(pub64);
    return 'hx${HEX.encode(hash.sublist(12))}';
  }


  /// Stacks (STX): 'S' + c32[22] + c32checkEncode(hash160).
  static String addressForSTX(HDWallet hdWallet) {
    final child     = hdWallet.derivePath("m/44'/5757'/0'/0/0");
    final privBytes = Uint8List.fromList(HEX.decode(HEX.encode(child.privateKey!)));
    final params    = ECCurve_secp256k1();
    final point     = params.G * _bytesToBigIntStatic(privBytes);
    final x = point!.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    final pfx    = y.isEven ? 0x02 : 0x03;
    final pubKey = Uint8List(33)..[0] = pfx;
    pubKey.setRange(1, 33, _bigIntToBytesStatic(x, 32));
    final sha256  = crypto.sha256.convert(pubKey).bytes;
    final ripemd  = RIPEMD160Digest();
    final hash160 = ripemd.process(Uint8List.fromList(sha256));
    const version = 22; // P2PKH mainnet
    // c32checksum = sha256d(version_byte + hash160)[0:4]
    final toHash = Uint8List(21)..[0] = version;
    toHash.setRange(1, 21, hash160);
    final h1  = crypto.sha256.convert(toHash).bytes;
    final h2  = crypto.sha256.convert(h1).bytes;
    final ck  = h2.sublist(0, 4);
    // payload = hash160 + checksum (24 bytes) → c32 encode
    final payload = Uint8List(24)..setRange(0, 20, hash160)..setRange(20, 24, ck);
    const c32 = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    var num = _bytesToBigIntStatic(payload);
    var enc = '';
    while (num > BigInt.zero) {
      final rem = (num % BigInt.from(32)).toInt();
      num ~/= BigInt.from(32);
      enc = c32[rem] + enc;
    }
    for (var i = 0; i < payload.length && payload[i] == 0; i++) enc = c32[0] + enc;
    return 'S${c32[version]}$enc';
  }


  // Shared helper: RIPEMD160(SHA256(script)) → base58check with versionByte
  static String _base58checkWithVersion(Uint8List script, int versionByte) {
    final sha256  = crypto.sha256.convert(script).bytes;
    final ripemd  = RIPEMD160Digest();
    final hash160 = ripemd.process(Uint8List.fromList(sha256));
    final payload = Uint8List(21)..[0] = versionByte;
    payload.setRange(1, 21, hash160);
    final h1   = crypto.sha256.convert(payload).bytes;
    final h2   = crypto.sha256.convert(h1).bytes;
    final full = Uint8List(25)..setRange(0, 21, payload)..setRange(21, 25, h2.sublist(0, 4));
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var num = _bytesToBigIntStatic(full);
    var encoded = '';
    while (num > BigInt.zero) {
      final rem = (num % BigInt.from(58)).toInt();
      num ~/= BigInt.from(58);
      encoded = alphabet[rem] + encoded;
    }
    for (var i = 0; i < full.length && full[i] == 0; i++) encoded = '1$encoded';
    return encoded;
  }

  // ─── Static bech32 helpers ────────────────────────────────────────────────

  static String _bech32EncodeStatic(String hrp, Uint8List data) {
    const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final converted = _convertBitsStatic(data, 8, 5, true);
    final checksum  = _bech32ChecksumStatic(hrp, converted);
    return hrp + '1' + (converted + checksum).map((d) => charset[d]).join();
  }

  static List<int> _bech32ChecksumStatic(String hrp, List<int> data) {
    final values  = _bech32HrpExpand(hrp) + data + [0, 0, 0, 0, 0, 0];
    final polymod = _bech32PolymodStatic(values) ^ 1;
    return List.generate(6, (i) => (polymod >> (5 * (5 - i))) & 31);
  }

  static List<int> _bech32HrpExpand(String hrp) {
    final r = <int>[];
    for (final c in hrp.codeUnits) r.add(c >> 5);
    r.add(0);
    for (final c in hrp.codeUnits) r.add(c & 31);
    return r;
  }

  static int _bech32PolymodStatic(List<int> values) {
    const gen = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
    var chk = 1;
    for (final v in values) {
      final top = chk >> 25;
      chk = (chk & 0x1ffffff) << 5 ^ v;
      for (var i = 0; i < 5; i++) {
        chk ^= ((top >> i) & 1) != 0 ? gen[i] : 0;
      }
    }
    return chk;
  }

  static List<int> _convertBitsStatic(Uint8List data, int from, int to, bool pad) {
    var acc = 0, bits = 0;
    final result = <int>[];
    final maxv = (1 << to) - 1;
    for (final v in data) {
      acc = (acc << from) | v;
      bits += from;
      while (bits >= to) {
        bits -= to;
        result.add((acc >> bits) & maxv);
      }
    }
    if (pad && bits > 0) result.add((acc << (to - bits)) & maxv);
    return result;
  }

  static BigInt _bytesToBigIntStatic(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  static Uint8List _bigIntToBytesStatic(BigInt value, int length) {
    final bytes = Uint8List(length);
    var v = value;
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return bytes;
  }

  factory BitcoinWallet.fromMnemonic(
    String mnemonic, {
    bool testnet = false,
    BitcoinAddressType addressType = BitcoinAddressType.p2wpkh,
    int index = 0,
  }) {
    final hdWallet = HDWallet.fromMnemonic(mnemonic);
    
    return BitcoinWallet._(
      hdWallet: hdWallet,
      testnet: testnet,
      addressType: addressType,
      index: index,
    );
  }

  factory BitcoinWallet.fromHdWallet(
    HDWallet hdWallet, {
    bool testnet = false,
    BitcoinAddressType addressType = BitcoinAddressType.p2wpkh,
    int index = 0,
  }) {
    return BitcoinWallet._(
      hdWallet: hdWallet,
      testnet: testnet,
      addressType: addressType,
      index: index,
    );
  }
  
  void _initializeKeys() {
    // BIP84 (m/84') for P2WPKH (native SegWit bc1…); BIP44 (m/44') for P2PKH/P2SH
    _privateKey = _addressType == BitcoinAddressType.p2wpkh
        ? _hdWallet.getBitcoinSegwitPrivateKey(_index)
        : _hdWallet.getBitcoinPrivateKey(_index);
    
    // Derive public key using secp256k1
    _publicKey = _derivePublicKey(_privateKey);
    
    // Generate Bitcoin address based on type
    _address = _generateAddress(_publicKey, _addressType, _testnet);
  }
  
  /// Derives public key from private key using secp256k1 curve
  String _derivePublicKey(String privateKeyHex) {
    final privateKeyBytes = Uint8List.fromList(HEX.decode(privateKeyHex));
    final privateKeyBigInt = _bytesToBigInt(privateKeyBytes);
    
    // secp256k1 parameters
    final params = ECCurve_secp256k1();
    final G = params.G;
    
    // Calculate public key: pubKey = privateKey * G
    final publicKeyPoint = G * privateKeyBigInt;
    
    // Compressed public key (33 bytes)
    final x = publicKeyPoint!.x!.toBigInteger()!;
    final y = publicKeyPoint.y!.toBigInteger()!;
    
    // Compression: 02 if y is even, 03 if y is odd
    final prefix = y.isEven ? 0x02 : 0x03;
    final xBytes = _bigIntToBytes(x, 32);
    
    final compressedPubKey = Uint8List(33);
    compressedPubKey[0] = prefix;
    compressedPubKey.setRange(1, 33, xBytes);
    
    return HEX.encode(compressedPubKey);
  }
  
  /// Generates Bitcoin address from public key
  String _generateAddress(String publicKeyHex, BitcoinAddressType type, bool testnet) {
    final publicKeyBytes = Uint8List.fromList(HEX.decode(publicKeyHex));
    
    switch (type) {
      case BitcoinAddressType.p2pkh:
        return _generateP2PKHAddress(publicKeyBytes, testnet);
      case BitcoinAddressType.p2wpkh:
        return _generateP2WPKHAddress(publicKeyBytes, testnet);
      case BitcoinAddressType.p2sh:
        return _generateP2SHAddress(publicKeyBytes, testnet);
    }
  }
  
  /// Generate P2PKH (Legacy) address
  String _generateP2PKHAddress(Uint8List publicKey, bool testnet) {
    // 1. SHA-256 hash of public key
    final sha256Hash = crypto.sha256.convert(publicKey).bytes;
    
    // 2. RIPEMD-160 hash
    final ripemd160 = RIPEMD160Digest();
    final pubKeyHash = ripemd160.process(Uint8List.fromList(sha256Hash));
    
    // 3. Add version byte (0x00 for mainnet, 0x6F for testnet)
    final version = testnet ? 0x6F : 0x00;
    final versionedPayload = Uint8List(21);
    versionedPayload[0] = version;
    versionedPayload.setRange(1, 21, pubKeyHash);
    
    // 4. Base58Check encoding
    return _base58CheckEncode(versionedPayload);
  }
  
  /// Generate P2WPKH (SegWit) address
  String _generateP2WPKHAddress(Uint8List publicKey, bool testnet) {
    // 1. SHA-256 hash of public key
    final sha256Hash = crypto.sha256.convert(publicKey).bytes;
    
    // 2. RIPEMD-160 hash
    final ripemd160 = RIPEMD160Digest();
    final pubKeyHash = ripemd160.process(Uint8List.fromList(sha256Hash));
    
    // 3. Bech32 encoding
    final hrp = testnet ? 'tb' : 'bc';
    return _bech32Encode(hrp, 0, pubKeyHash);
  }
  
  /// Generate P2SH (Nested SegWit) address
  String _generateP2SHAddress(Uint8List publicKey, bool testnet) {
    // 1. SHA-256 hash of public key
    final sha256Hash = crypto.sha256.convert(publicKey).bytes;
    
    // 2. RIPEMD-160 hash
    final ripemd160 = RIPEMD160Digest();
    final pubKeyHash = ripemd160.process(Uint8List.fromList(sha256Hash));
    
    // 3. Create redeemScript: OP_0 <20-byte-pubkey-hash>
    final redeemScript = Uint8List(22);
    redeemScript[0] = 0x00; // OP_0
    redeemScript[1] = 0x14; // Push 20 bytes
    redeemScript.setRange(2, 22, pubKeyHash);
    
    // 4. SHA-256 hash of redeemScript
    final scriptSha256 = crypto.sha256.convert(redeemScript).bytes;
    
    // 5. RIPEMD-160 hash
    final scriptHash = ripemd160.process(Uint8List.fromList(scriptSha256));
    
    // 6. Add version byte (0x05 for mainnet, 0xC4 for testnet)
    final version = testnet ? 0xC4 : 0x05;
    final versionedPayload = Uint8List(21);
    versionedPayload[0] = version;
    versionedPayload.setRange(1, 21, scriptHash);
    
    // 7. Base58Check encoding
    return _base58CheckEncode(versionedPayload);
  }
  
  /// Base58Check encoding
  String _base58CheckEncode(Uint8List payload) {
    // 1. Double SHA-256 for checksum
    final hash1 = crypto.sha256.convert(payload).bytes;
    final hash2 = crypto.sha256.convert(hash1).bytes;
    final checksum = hash2.sublist(0, 4);
    
    // 2. Append checksum
    final fullPayload = Uint8List(payload.length + 4);
    fullPayload.setRange(0, payload.length, payload);
    fullPayload.setRange(payload.length, payload.length + 4, checksum);
    
    // 3. Base58 encode
    return _base58Encode(fullPayload);
  }
  
  /// Base58 encoding
  String _base58Encode(Uint8List bytes) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var num = _bytesToBigInt(bytes);
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
  
  /// Bech32 encoding for SegWit addresses
  String _bech32Encode(String hrp, int witnessVersion, Uint8List witnessProgram) {
    final values = _convertBits(witnessProgram, 8, 5, true);
    final data = [witnessVersion] + values;
    return _bech32EncodeRaw(hrp, data);
  }
  
  String _bech32EncodeRaw(String hrp, List<int> data) {
    const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final combined = data + _bech32CreateChecksum(hrp, data);
    return hrp + '1' + combined.map((d) => charset[d]).join();
  }
  
  List<int> _bech32CreateChecksum(String hrp, List<int> data) {
    final values = _hrpExpand(hrp) + data + [0, 0, 0, 0, 0, 0];
    final polymod = _bech32Polymod(values) ^ 1;
    return List.generate(6, (i) => (polymod >> (5 * (5 - i))) & 31);
  }
  
  List<int> _hrpExpand(String hrp) {
    final result = <int>[];
    for (var c in hrp.codeUnits) {
      result.add(c >> 5);
    }
    result.add(0);
    for (var c in hrp.codeUnits) {
      result.add(c & 31);
    }
    return result;
  }
  
  int _bech32Polymod(List<int> values) {
    const gen = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
    var chk = 1;
    for (var value in values) {
      final top = chk >> 25;
      chk = (chk & 0x1ffffff) << 5 ^ value;
      for (var i = 0; i < 5; i++) {
        chk ^= ((top >> i) & 1) != 0 ? gen[i] : 0;
      }
    }
    return chk;
  }
  
  List<int> _convertBits(Uint8List data, int fromBits, int toBits, bool pad) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxv = (1 << toBits) - 1;
    
    for (var value in data) {
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }
    
    if (pad && bits > 0) {
      result.add((acc << (toBits - bits)) & maxv);
    }
    
    return result;
  }
  
  /// Helper: Convert bytes to BigInt
  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (var byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }
  
  /// Helper: Convert BigInt to bytes
  Uint8List _bigIntToBytes(BigInt number, int length) {
    final bytes = Uint8List(length);
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (number & BigInt.from(0xff)).toInt();
      number = number >> 8;
    }
    return bytes;
  }
  
  /// Get Bitcoin address
  String get address => _address;
  
  /// Get private key (use with caution!)
  String get privateKey => _privateKey;
  
  /// Get public key
  String get publicKey => _publicKey;
  
  /// Get address type
  BitcoinAddressType get addressType => _addressType;
  
  /// Is testnet
  bool get isTestnet => _testnet;
  
  /// Get network name
  String get network => _testnet ? 'testnet' : 'mainnet';
  
  /// Sign message using Bitcoin message signing (BIP-137)
  String signMessage(String message) {
    // Bitcoin message signing format
    final messagePrefix = '\x18Bitcoin Signed Message:\n';
    final messageBytes = Uint8List.fromList(message.codeUnits);
    final messageLengthBytes = Uint8List.fromList([messageBytes.length]);
    
    // Construct full message
    final fullMessage = Uint8List.fromList([
      ...messagePrefix.codeUnits,
      ...messageLengthBytes,
      ...messageBytes,
    ]);
    
    // Double SHA-256 hash
    final hash1 = crypto.sha256.convert(fullMessage).bytes;
    final hash2 = crypto.sha256.convert(hash1).bytes;
    
    // Sign with private key (simplified - in production use proper ECDSA)
    return HEX.encode(hash2);
  }
}

/// Bitcoin Address Types
enum BitcoinAddressType {
  /// Legacy address (starts with 1 or m)
  p2pkh,
  
  /// SegWit address (starts with bc1 or tb1)
  p2wpkh,
  
  /// Nested SegWit address (starts with 3 or 2)
  p2sh,
}

extension BitcoinAddressTypeExtension on BitcoinAddressType {
  String get displayName {
    switch (this) {
      case BitcoinAddressType.p2pkh:
        return 'Legacy (P2PKH)';
      case BitcoinAddressType.p2wpkh:
        return 'SegWit (P2WPKH)';
      case BitcoinAddressType.p2sh:
        return 'Nested SegWit (P2SH)';
    }
  }
  
  String get description {
    switch (this) {
      case BitcoinAddressType.p2pkh:
        return 'Original Bitcoin address format';
      case BitcoinAddressType.p2wpkh:
        return 'Modern SegWit format with lower fees';
      case BitcoinAddressType.p2sh:
        return 'Compatible SegWit format';
    }
  }
}
