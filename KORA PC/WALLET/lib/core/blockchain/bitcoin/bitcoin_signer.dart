import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:kora_windows/core/blockchain/bitcoin/bitcoin_service.dart' hide TransactionOutput;
import 'package:kora_windows/core/blockchain/bitcoin/bitcoin_transaction.dart';

/// Bitcoin transaction signer — supports P2PKH (legacy) and P2WPKH (SegWit)
class BitcoinSigner {
  // ── Public API ─────────────────────────────────────────────────────────────

  /// Sign and serialize a P2PKH (legacy) transaction.
  /// Returns raw transaction hex ready to broadcast.
  static String signP2PKH({
    required BitcoinTransactionResult txResult,
    required String privateKeyHex,
    required String compressedPubKeyHex,
    int version  = 1,
    int locktime = 0,
  }) {
    final privBytes = Uint8List.fromList(HEX.decode(privateKeyHex));
    final pubBytes  = Uint8List.fromList(HEX.decode(compressedPubKeyHex));
    final pubKeyHash = _hash160(pubBytes);
    final scriptPubKey = _p2pkhScript(pubKeyHash);

    final signatures = <Uint8List>[];
    for (var i = 0; i < txResult.inputs.length; i++) {
      final preimage = _p2pkhSighashPreimage(
        inputs: txResult.inputs,
        outputs: txResult.outputs,
        signingIdx: i,
        scriptPubKey: scriptPubKey,
        version: version,
        locktime: locktime,
      );
      final sighash = _dsha256(preimage);
      final der     = _derSign(sighash, privBytes);
      // Append SIGHASH_ALL byte
      final sig = Uint8List(der.length + 1)
        ..setRange(0, der.length, der)
        ..[der.length] = 0x01;
      signatures.add(sig);
    }

    return HEX.encode(_serializeP2PKH(
      inputs: txResult.inputs,
      outputs: txResult.outputs,
      signatures: signatures,
      pubKey: pubBytes,
      version: version,
      locktime: locktime,
    ));
  }

  /// Sign and serialize a P2WPKH (native SegWit) transaction via BIP143.
  /// Returns raw transaction hex ready to broadcast.
  static String signP2WPKH({
    required BitcoinTransactionResult txResult,
    required String privateKeyHex,
    required String compressedPubKeyHex,
    int version  = 2,
    int locktime = 0,
  }) {
    final privBytes = Uint8List.fromList(HEX.decode(privateKeyHex));
    final pubBytes  = Uint8List.fromList(HEX.decode(compressedPubKeyHex));
    final pubKeyHash = _hash160(pubBytes);

    // Pre-compute BIP143 hash aggregates
    final hashPrevouts = _bip143HashPrevouts(txResult.inputs);
    final hashSequence = _bip143HashSequence(txResult.inputs);
    final hashOutputs  = _bip143HashOutputs(txResult.outputs);

    final signatures = <Uint8List>[];
    for (var i = 0; i < txResult.inputs.length; i++) {
      final preimage = _bip143Preimage(
        input:        txResult.inputs[i],
        pubKeyHash:   pubKeyHash,
        hashPrevouts: hashPrevouts,
        hashSequence: hashSequence,
        hashOutputs:  hashOutputs,
        version:  version,
        locktime: locktime,
      );
      final sighash = _dsha256(preimage);
      final der     = _derSign(sighash, privBytes);
      final sig = Uint8List(der.length + 1)
        ..setRange(0, der.length, der)
        ..[der.length] = 0x01;
      signatures.add(sig);
    }

    return HEX.encode(_serializeP2WPKH(
      inputs: txResult.inputs,
      outputs: txResult.outputs,
      signatures: signatures,
      pubKey: pubBytes,
      version: version,
      locktime: locktime,
    ));
  }

  /// Sign and serialize a Bitcoin Cash P2PKH transaction.
  /// BCH replay-protection uses BIP143 sighash digest + SIGHASH_FORKID (0x41).
  static String signP2PKHBCH({
    required BitcoinTransactionResult txResult,
    required String privateKeyHex,
    required String compressedPubKeyHex,
    int version  = 1,
    int locktime = 0,
  }) {
    final privBytes  = Uint8List.fromList(HEX.decode(privateKeyHex));
    final pubBytes   = Uint8List.fromList(HEX.decode(compressedPubKeyHex));
    final pubKeyHash = _hash160(pubBytes);
    final scriptCode = _p2pkhScript(pubKeyHash);

    // BIP143 aggregate hashes (same algorithm as SegWit)
    final hashPrevouts = _bip143HashPrevouts(txResult.inputs);
    final hashSequence = _bip143HashSequence(txResult.inputs);
    final hashOutputs  = _bip143HashOutputs(txResult.outputs);

    final signatures = <Uint8List>[];
    for (var i = 0; i < txResult.inputs.length; i++) {
      final preimage = _bchSighashPreimage(
        input:        txResult.inputs[i],
        scriptCode:   scriptCode,
        hashPrevouts: hashPrevouts,
        hashSequence: hashSequence,
        hashOutputs:  hashOutputs,
        version:  version,
        locktime: locktime,
      );
      final sighash = _dsha256(preimage);
      final der     = _derSign(sighash, privBytes);
      // Append SIGHASH_ALL | SIGHASH_FORKID = 0x41
      final sig = Uint8List(der.length + 1)
        ..setRange(0, der.length, der)
        ..[der.length] = 0x41;
      signatures.add(sig);
    }

    // Serialize as standard P2PKH (no SegWit marker)
    return HEX.encode(_serializeP2PKH(
      inputs: txResult.inputs,
      outputs: txResult.outputs,
      signatures: signatures,
      pubKey: pubBytes,
      version: version,
      locktime: locktime,
    ));
  }

  /// BIP143-style preimage for BCH (SIGHASH_ALL | SIGHASH_FORKID = 0x41).
  static Uint8List _bchSighashPreimage({
    required UTXO input,
    required Uint8List scriptCode,
    required Uint8List hashPrevouts,
    required Uint8List hashSequence,
    required Uint8List hashOutputs,
    required int version,
    required int locktime,
  }) {
    final buf = BytesBuilder()
      ..add(_int32LE(version))
      ..add(hashPrevouts)
      ..add(hashSequence)
      ..add(_reversedTxid(input.txHash))
      ..add(_uint32LE(input.outputIndex))
      ..add(_varInt(scriptCode.length))
      ..add(scriptCode)
      ..add(_int64LE(input.value))       // input amount (BCH/BIP143 requirement)
      ..add(_uint32LE(0xffffffff))       // nSequence
      ..add(hashOutputs)
      ..add(_int32LE(locktime))
      ..add(_uint32LE(0x00000041));      // SIGHASH_ALL | SIGHASH_FORKID
    return buf.toBytes();
  }

  // ── P2PKH helpers ──────────────────────────────────────────────────────────

  static Uint8List _p2pkhSighashPreimage({
    required List<UTXO> inputs,
    required List<TransactionOutput> outputs,
    required int signingIdx,
    required Uint8List scriptPubKey,
    required int version,
    required int locktime,
  }) {
    final buf = BytesBuilder();
    buf.add(_int32LE(version));

    buf.add(_varInt(inputs.length));
    for (var i = 0; i < inputs.length; i++) {
      buf.add(_reversedTxid(inputs[i].txHash));
      buf.add(_uint32LE(inputs[i].outputIndex));
      if (i == signingIdx) {
        buf.add(_varInt(scriptPubKey.length));
        buf.add(scriptPubKey);
      } else {
        buf.add(_varInt(0)); // empty scriptSig
      }
      buf.add(_uint32LE(0xffffffff)); // sequence
    }

    buf.add(_varInt(outputs.length));
    for (final out in outputs) {
      buf.add(_int64LE(out.amount));
      final spk = _addressToScriptPubKey(out.address);
      buf.add(_varInt(spk.length));
      buf.add(spk);
    }

    buf.add(_int32LE(locktime));
    buf.add(_uint32LE(0x00000001)); // SIGHASH_ALL
    return buf.toBytes();
  }

  static Uint8List _serializeP2PKH({
    required List<UTXO> inputs,
    required List<TransactionOutput> outputs,
    required List<Uint8List> signatures,
    required Uint8List pubKey,
    required int version,
    required int locktime,
  }) {
    final buf = BytesBuilder();
    buf.add(_int32LE(version));

    buf.add(_varInt(inputs.length));
    for (var i = 0; i < inputs.length; i++) {
      buf.add(_reversedTxid(inputs[i].txHash));
      buf.add(_uint32LE(inputs[i].outputIndex));

      final sig       = signatures[i];
      final scriptSig = BytesBuilder()
        ..add(_varInt(sig.length))
        ..add(sig)
        ..add(_varInt(pubKey.length))
        ..add(pubKey);
      final ss = scriptSig.toBytes();
      buf.add(_varInt(ss.length));
      buf.add(ss);
      buf.add(_uint32LE(0xffffffff));
    }

    buf.add(_varInt(outputs.length));
    for (final out in outputs) {
      buf.add(_int64LE(out.amount));
      final spk = _addressToScriptPubKey(out.address);
      buf.add(_varInt(spk.length));
      buf.add(spk);
    }

    buf.add(_int32LE(locktime));
    return buf.toBytes();
  }

  // ── P2WPKH / BIP143 helpers ───────────────────────────────────────────────

  static Uint8List _bip143HashPrevouts(List<UTXO> inputs) {
    final buf = BytesBuilder();
    for (final inp in inputs) {
      buf.add(_reversedTxid(inp.txHash));
      buf.add(_uint32LE(inp.outputIndex));
    }
    return _dsha256(buf.toBytes());
  }

  static Uint8List _bip143HashSequence(List<UTXO> inputs) {
    final buf = BytesBuilder();
    for (var _ in inputs) buf.add(_uint32LE(0xffffffff));
    return _dsha256(buf.toBytes());
  }

  static Uint8List _bip143HashOutputs(List<TransactionOutput> outputs) {
    final buf = BytesBuilder();
    for (final out in outputs) {
      buf.add(_int64LE(out.amount));
      final spk = _addressToScriptPubKey(out.address);
      buf.add(_varInt(spk.length));
      buf.add(spk);
    }
    return _dsha256(buf.toBytes());
  }

  static Uint8List _bip143Preimage({
    required UTXO input,
    required Uint8List pubKeyHash,
    required Uint8List hashPrevouts,
    required Uint8List hashSequence,
    required Uint8List hashOutputs,
    required int version,
    required int locktime,
  }) {
    // scriptCode for P2WPKH: OP_DUP OP_HASH160 <20-byte-pkh> OP_EQUALVERIFY OP_CHECKSIG
    final scriptCode = _p2pkhScript(pubKeyHash);

    final buf = BytesBuilder()
      ..add(_int32LE(version))
      ..add(hashPrevouts)
      ..add(hashSequence)
      ..add(_reversedTxid(input.txHash))
      ..add(_uint32LE(input.outputIndex))
      ..add(_varInt(scriptCode.length))
      ..add(scriptCode)
      ..add(_int64LE(input.value))
      ..add(_uint32LE(0xffffffff))   // nSequence
      ..add(hashOutputs)
      ..add(_int32LE(locktime))
      ..add(_uint32LE(0x00000001));  // SIGHASH_ALL
    return buf.toBytes();
  }

  static Uint8List _serializeP2WPKH({
    required List<UTXO> inputs,
    required List<TransactionOutput> outputs,
    required List<Uint8List> signatures,
    required Uint8List pubKey,
    required int version,
    required int locktime,
  }) {
    final buf = BytesBuilder();
    buf.add(_int32LE(version));
    buf.add([0x00, 0x01]); // SegWit marker + flag

    buf.add(_varInt(inputs.length));
    for (final inp in inputs) {
      buf.add(_reversedTxid(inp.txHash));
      buf.add(_uint32LE(inp.outputIndex));
      buf.add([0x00]); // empty scriptSig
      buf.add(_uint32LE(0xffffffff));
    }

    buf.add(_varInt(outputs.length));
    for (final out in outputs) {
      buf.add(_int64LE(out.amount));
      final spk = _addressToScriptPubKey(out.address);
      buf.add(_varInt(spk.length));
      buf.add(spk);
    }

    // Witness data (one per input)
    for (var i = 0; i < inputs.length; i++) {
      buf.add([0x02]); // 2 witness items
      final sig = signatures[i];
      buf.add(_varInt(sig.length));
      buf.add(sig);
      buf.add(_varInt(pubKey.length));
      buf.add(pubKey);
    }

    buf.add(_int32LE(locktime));
    return buf.toBytes();
  }

  // ── Crypto helpers ────────────────────────────────────────────────────────

  /// SHA256(SHA256(data))
  static Uint8List _dsha256(Uint8List data) {
    final h1 = crypto.sha256.convert(data).bytes;
    return Uint8List.fromList(crypto.sha256.convert(h1).bytes);
  }

  /// SHA256 then RIPEMD160
  static Uint8List _hash160(Uint8List data) {
    final sha = Uint8List.fromList(crypto.sha256.convert(data).bytes);
    return RIPEMD160Digest().process(sha);
  }

  /// ECDSA sign (secp256k1, RFC 6979 deterministic) → DER-encoded bytes
  static Uint8List _derSign(Uint8List hash, Uint8List privKeyBytes) {
    final privBigInt   = _bytesToBigInt(privKeyBytes);
    final domainParams = ECCurve_secp256k1();
    final privKey      = ECPrivateKey(privBigInt, domainParams);
    final signer       = ECDSASigner(null, HMac(SHA256Digest(), 64));
    signer.init(true, PrivateKeyParameter<ECPrivateKey>(privKey));
    final sig = signer.generateSignature(hash) as ECSignature;

    // Low-S normalisation (BIP62)
    final n = domainParams.n;
    final halfN = n >> 1;
    final s = sig.s > halfN ? n - sig.s : sig.s;

    return _derEncode(sig.r, s);
  }

  static Uint8List _derEncode(BigInt r, BigInt s) {
    final rBytes = _minimalPosBytes(r);
    final sBytes = _minimalPosBytes(s);
    final inner  = 2 + rBytes.length + 2 + sBytes.length;
    final out    = BytesBuilder()
      ..addByte(0x30)
      ..addByte(inner)
      ..addByte(0x02)
      ..addByte(rBytes.length)
      ..add(rBytes)
      ..addByte(0x02)
      ..addByte(sBytes.length)
      ..add(sBytes);
    return out.toBytes();
  }

  /// Minimal positive DER encoding (pad with 0x00 if high bit set)
  static Uint8List _minimalPosBytes(BigInt n) {
    final hex    = n.toRadixString(16).padLeft(64, '0');
    final bytes  = Uint8List.fromList(HEX.decode(hex));
    // Strip leading zeros but keep at least one byte
    var start = 0;
    while (start < bytes.length - 1 && bytes[start] == 0) start++;
    final trimmed = bytes.sublist(start);
    // Prepend 0x00 if high bit set (to keep positive)
    if (trimmed[0] >= 0x80) {
      return Uint8List.fromList([0x00, ...trimmed]);
    }
    return trimmed;
  }

  // ── Script builders ───────────────────────────────────────────────────────

  /// OP_DUP OP_HASH160 <pkh> OP_EQUALVERIFY OP_CHECKSIG
  static Uint8List _p2pkhScript(Uint8List pubKeyHash) {
    return Uint8List.fromList([
      0x76, 0xa9, 0x14, ...pubKeyHash, 0x88, 0xac,
    ]);
  }

  /// OP_HASH160 <scriptHash> OP_EQUAL
  static Uint8List _p2shScript(Uint8List scriptHash) {
    return Uint8List.fromList([
      0xa9, 0x14, ...scriptHash, 0x87,
    ]);
  }

  /// OP_0 <pkh>
  static Uint8List _p2wpkhScript(Uint8List pubKeyHash) {
    return Uint8List.fromList([0x00, 0x14, ...pubKeyHash]);
  }

  /// Convert Bitcoin address to scriptPubKey
  static Uint8List _addressToScriptPubKey(String address) {
    if (address.startsWith('bc1q') || address.startsWith('tb1q') ||
        address.startsWith('ltc1q')) {
      // P2WPKH bech32 (BTC/LTC native SegWit)
      final decoded = _bech32Decode(address);
      return _p2wpkhScript(decoded);
    } else if (address.startsWith('bc1p') || address.startsWith('tb1p')) {
      throw UnsupportedError('Taproot (P2TR) outputs not yet supported');
    } else if (address.startsWith('bitcoincash:') || address.startsWith('bchtest:') ||
               address.startsWith('q') || address.startsWith('p')) {
      // CashAddr (BCH) — with or without bitcoincash: prefix
      final full = address.contains(':') ? address : 'bitcoincash:$address';
      final (isP2SH, hash) = _cashAddrDecode(full);
      return isP2SH ? _p2shScript(hash) : _p2pkhScript(hash);
    } else {
      // Base58Check (legacy P2PKH or P2SH for BTC/LTC/BCH)
      final decoded = _base58CheckDecode(address);
      final version = decoded[0];
      final payload = decoded.sublist(1, 21);
      if (version == 0x00 || version == 0x6F || version == 0x30) return _p2pkhScript(payload); // P2PKH BTC/LTC mainnet+testnet
      if (version == 0x05 || version == 0xC4 || version == 0x32) return _p2shScript(payload);  // P2SH BTC/LTC mainnet+testnet
      throw UnsupportedError('Unknown address version: 0x${version.toRadixString(16)}');
    }
  }

  /// Decode a CashAddr string (e.g. 'bitcoincash:qp3...') into (isP2SH, hash20).
  static (bool isP2SH, Uint8List hash) _cashAddrDecode(String address) {
    const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final lower = address.toLowerCase();
    final sep   = lower.indexOf(':');
    final data  = lower.substring(sep + 1);
    // Decode all chars (last 8 are checksum)
    final values = data.split('').map((c) {
      final v = charset.indexOf(c);
      if (v < 0) throw ArgumentError('Invalid CashAddr char "$c" in $address');
      return v;
    }).toList();
    // Strip 8-char checksum, then convert 5→8 bit
    final payload5 = values.sublist(0, values.length - 8);
    final decoded  = _convertBits(payload5, 5, 8, false);
    // decoded[0]: version byte — bits [4..3] = type (0=P2PKH, 1=P2SH)
    final hashType = (decoded[0] >> 3) & 0x1f;
    final hash     = Uint8List.fromList(decoded.sublist(1));
    return (hashType == 1, hash);
  }

  // ── Base58Check decode ────────────────────────────────────────────────────

  static Uint8List _base58CheckDecode(String address) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var num = BigInt.zero;
    for (final char in address.runes) {
      final digit = alphabet.indexOf(String.fromCharCode(char));
      if (digit < 0) throw ArgumentError('Invalid Base58 char: $char');
      num = num * BigInt.from(58) + BigInt.from(digit);
    }
    // Convert to bytes
    var hex = num.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';
    var bytes = Uint8List.fromList(HEX.decode(hex));
    // Leading 1s → leading zeros
    int leadingZeros = 0;
    for (final c in address.runes) {
      if (String.fromCharCode(c) == '1') leadingZeros++; else break;
    }
    if (leadingZeros > 0) {
      bytes = Uint8List.fromList([...List.filled(leadingZeros, 0), ...bytes]);
    }
    // Verify checksum
    final payload  = bytes.sublist(0, bytes.length - 4);
    final checksum = bytes.sublist(bytes.length - 4);
    final computed = _dsha256(payload).sublist(0, 4);
    for (var i = 0; i < 4; i++) {
      if (checksum[i] != computed[i]) throw ArgumentError('Invalid checksum for $address');
    }
    return payload;
  }

  // ── Bech32 decode (P2WPKH) ───────────────────────────────────────────────

  static Uint8List _bech32Decode(String address) {
    const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final lower   = address.toLowerCase();
    final sep     = lower.lastIndexOf('1');
    if (sep < 1) throw ArgumentError('Invalid bech32 address: $address');

    final hrp      = lower.substring(0, sep);
    final dataPart = lower.substring(sep + 1);
    if (dataPart.length < 7) throw ArgumentError('bech32 data too short: $address');

    // Decode ALL chars (including 6-char checksum)
    final allValues = dataPart.split('').map((c) {
      final v = charset.indexOf(c);
      if (v < 0) throw ArgumentError('Invalid bech32 char "$c" in $address');
      return v;
    }).toList();

    // ── Verify checksum (BIP173 polymod) ──────────────────────────────────
    if (!_bech32VerifyChecksum(hrp, allValues)) {
      throw ArgumentError('Invalid bech32 checksum for $address');
    }

    // Data without checksum; skip witness version byte (first value)
    final values = allValues.sublist(1, allValues.length - 6);
    return Uint8List.fromList(_convertBits(values, 5, 8, false));
  }

  /// BIP173 bech32 polymod.
  static int _bech32Polymod(List<int> values) {
    const gen = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
    var chk = 1;
    for (final v in values) {
      final b = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ v;
      for (var i = 0; i < 5; i++) {
        if ((b >> i) & 1 == 1) chk ^= gen[i];
      }
    }
    return chk;
  }

  /// Expands the HRP for checksum computation (BIP173).
  static List<int> _bech32HrpExpand(String hrp) {
    final result = <int>[];
    for (final c in hrp.codeUnits) result.add(c >> 5);
    result.add(0);
    for (final c in hrp.codeUnits) result.add(c & 31);
    return result;
  }

  /// Returns true if the 6-char checksum over hrp+data is valid.
  static bool _bech32VerifyChecksum(String hrp, List<int> data) =>
      _bech32Polymod([..._bech32HrpExpand(hrp), ...data]) == 1;

  static List<int> _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
    var acc = 0, bits = 0;
    final result = <int>[];
    final maxv   = (1 << toBits) - 1;
    for (final v in data) {
      acc  = (acc << fromBits) | v;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }
    if (pad && bits > 0) result.add((acc << (toBits - bits)) & maxv);
    return result;
  }

  // ── Serialization primitives ─────────────────────────────────────────────

  static Uint8List _reversedTxid(String txidHex) {
    final bytes = Uint8List.fromList(HEX.decode(txidHex));
    return Uint8List.fromList(bytes.reversed.toList());
  }

  static Uint8List _varInt(int n) {
    if (n < 0xfd) return Uint8List.fromList([n]);
    if (n <= 0xffff) return Uint8List.fromList([0xfd, n & 0xff, (n >> 8) & 0xff]);
    if (n <= 0xffffffff) return Uint8List.fromList([
      0xfe, n & 0xff, (n >> 8) & 0xff, (n >> 16) & 0xff, (n >> 24) & 0xff,
    ]);
    throw ArgumentError('varInt too large: $n');
  }

  static Uint8List _int32LE(int n) {
    final b = ByteData(4)..setInt32(0, n, Endian.little);
    return b.buffer.asUint8List();
  }

  static Uint8List _uint32LE(int n) {
    final b = ByteData(4)..setUint32(0, n, Endian.little);
    return b.buffer.asUint8List();
  }

  static Uint8List _int64LE(int n) {
    final b = ByteData(8)..setInt64(0, n, Endian.little);
    return b.buffer.asUint8List();
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) result = (result << 8) | BigInt.from(b);
    return result;
  }
}
