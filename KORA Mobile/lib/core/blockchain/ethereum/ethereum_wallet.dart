import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:kora/core/crypto/hd_wallet.dart';

/// Ethereum Wallet implementation using Web3dart
class EthereumWallet {
  late final EthPrivateKey _privateKey;
  late final EthereumAddress _address;
  final String _privateKeyHex;

  EthereumWallet._(this._privateKey, this._address, this._privateKeyHex);

  /// Create Ethereum wallet from mnemonic using BIP44
  /// Path: m/44'/60'/0'/0/{index} (ETH, BSC)
  /// Path: m/44'/61'/0'/0/{index} (ETC — coin_type 61 per SLIP-44)
  factory EthereumWallet.fromMnemonic(String mnemonic, {int index = 0, String blockchain = 'ethereum'}) {
    final hdWallet = HDWallet.fromMnemonic(mnemonic);
    final privateKeyHex = blockchain == 'ethereum_classic'
        ? hdWallet.getEthereumClassicPrivateKey(index)
        : hdWallet.getEthereumPrivateKey(index);
    final privateKey = EthPrivateKey.fromHex(privateKeyHex);
    final address = privateKey.address;
    
    return EthereumWallet._(privateKey, address, privateKeyHex);
  }

  /// Create Ethereum wallet from private key
  factory EthereumWallet.fromPrivateKey(String privateKeyHex) {
    final privateKey = EthPrivateKey.fromHex(privateKeyHex);
    final address = privateKey.address;
    
    return EthereumWallet._(privateKey, address, privateKeyHex);
  }

  /// Get Ethereum address
  EthereumAddress get address => _address;
  
  /// Get address as hex string
  String get addressHex => _address.hex;
  
  /// Get private key (use with caution!)
  EthPrivateKey get privateKey => _privateKey;
  
  /// Get private key as hex string (use with caution!)
  String get privateKeyHex => _privateKeyHex;

  /// Sign a message (EIP-191 personal sign)
  Uint8List signMessage(String message) {
    final messageBytes = Uint8List.fromList(message.codeUnits);
    return _privateKey.signPersonalMessageToUint8List(messageBytes);
  }

  /// Sign typed data (EIP-712)
  Future<Uint8List> signTypedData({
    required Map<String, dynamic> domain,
    required Map<String, dynamic> message,
    required Map<String, dynamic> types,
  }) async {
    throw UnimplementedError('EIP-712 signing not yet implemented');
  }
}
