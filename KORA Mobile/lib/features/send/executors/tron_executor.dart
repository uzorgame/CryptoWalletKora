import 'package:kora/core/models/asset.dart';
import 'package:kora/core/blockchain/tron/tron_wallet.dart';
import 'package:kora/core/blockchain/tron/tron_service.dart';
import 'package:kora/core/constants/token_catalog.dart';
import 'package:kora/features/send/services/transaction_executor.dart';

class TronExecutor implements TransactionExecutor {
  @override
  String get blockchain => 'tron';

  @override
  String? validateAddress(String address) {
    return TronAddressUtils.isValidAddress(address)
        ? null
        : 'Invalid Tron address — must start with T (34 chars)';
  }

  @override
  Future<String> execute({
    required String mnemonic,
    required Asset asset,
    required String toAddress,
    required String amount,
  }) async {
    final wallet = TronWallet.fromMnemonic(mnemonic);
    final svc = TronService();

    if (asset.type == AssetType.native) {
      return await svc.sendTRX(
        from: wallet.address,
        to: toAddress,
        amount: toTokenAmount(amount, 6).toInt(),
        signer: wallet.signTransactionHash,
      );
    } else {
      final contract = allCatalogTokens
          .where((t) => t.id == asset.id)
          .map((t) => t.contractAddress)
          .firstOrNull;
      if (contract == null || contract.isEmpty) {
        throw Exception('Unknown TRC-20 contract for ${asset.symbol} (id=${asset.id})');
      }
      return await svc.sendTRC20(
        from: wallet.address,
        to: toAddress,
        contractAddress: contract,
        amount: toTokenAmount(amount, asset.decimals),
        signer: wallet.signTransactionHash,
      );
    }
  }
}
