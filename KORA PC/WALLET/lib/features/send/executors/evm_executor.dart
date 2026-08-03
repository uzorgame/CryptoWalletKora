import 'package:kora_windows/core/crypto/seed.dart';
import 'package:kora_windows/core/crypto/hd_wallet.dart';
import 'package:web3dart/web3dart.dart';
import 'package:kora_windows/core/models/asset.dart';
import 'package:kora_windows/core/blockchain/ethereum/ethereum_wallet.dart';
import 'package:kora_windows/core/blockchain/ethereum/ethereum_service.dart';
import 'package:kora_windows/core/config/api_config.dart';
import 'package:kora_windows/core/constants/token_catalog.dart';
import 'package:kora_windows/features/send/services/transaction_executor.dart';

class EvmExecutor implements TransactionExecutor {
  @override
  String get blockchain => 'ethereum';

  @override
  String? validateAddress(String address) =>
      RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address)
          ? null
          : 'Invalid address — must start with 0x (42 chars)';

  @override
  Future<String> execute({
    required String mnemonic,
    required Asset asset,
    required String toAddress,
    required String amount,
  }) async {
    // The seed is derived in an isolate: PBKDF2 at 2048 rounds froze the window for a fifth
    // of a second the moment the user confirmed, before any network work had begun.
    final wallet = EthereumWallet.fromHdWallet(
      HDWallet.fromSeed(await mnemonicSeed(mnemonic)),
      blockchain: asset.blockchain,
    );
    final svc = _evmService(asset.blockchain);
    try {
      final String txHash;
      if (asset.type == AssetType.native) {
        txHash = await svc.sendETH(
          from: wallet.privateKey,
          to: toAddress,
          amount: EtherAmount.inWei(toTokenAmount(amount, 18)),
        );
      } else {
        final tokenContract = allCatalogTokens
            .firstWhere((t) => t.id == asset.id)
            .contractAddress!;
        txHash = await svc.sendToken(
          from: wallet.privateKey,
          tokenAddress: tokenContract,
          to: toAddress,
          amount: toTokenAmount(amount, asset.decimals),
        );
      }
      svc.dispose();
      return txHash;
    } catch (e) {
      svc.dispose();
      rethrow;
    }
  }

  EthereumService _evmService(String blockchain) {
    final (rpc, chainId) = APIConfig.evmRpcConfig(blockchain);
    return EthereumService(rpcUrl: rpc, chainId: chainId);
  }
}
