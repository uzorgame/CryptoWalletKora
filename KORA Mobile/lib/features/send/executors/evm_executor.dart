// EVM chains executor (Ethereum, BSC, ETC)

import 'package:web3dart/web3dart.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/blockchain/ethereum/ethereum_wallet.dart';
import 'package:kora/core/blockchain/ethereum/ethereum_service.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/features/send/services/transaction_executor.dart';
import 'package:kora/core/constants/token_catalog.dart';

class EvmExecutor implements TransactionExecutor {

  @override
  String get blockchain => 'ethereum';

  @override
  String? validateAddress(String address) {
    return RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address)
        ? null
        : 'Invalid address — must start with 0x (42 chars)';
  }

  @override
  Future<String> execute({
    required String mnemonic,
    required Asset asset,
    required String toAddress,
    required String amount,
  }) async {
    final wallet = EthereumWallet.fromMnemonic(mnemonic, blockchain: asset.blockchain);
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
        // asset.contractAddress stores the wallet address, not the token contract.
        // Always resolve the real token contract from the catalog.
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
