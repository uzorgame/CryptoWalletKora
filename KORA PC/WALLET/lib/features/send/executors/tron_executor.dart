import 'package:kora_windows/core/crypto/seed.dart';
import 'package:kora_windows/core/crypto/hd_wallet.dart';
import 'package:kora_windows/core/models/asset.dart';
import 'package:kora_windows/core/blockchain/tron/tron_wallet.dart';
import 'package:kora_windows/core/blockchain/tron/tron_service.dart';
import 'package:kora_windows/core/constants/token_catalog.dart';
import 'package:kora_windows/features/send/services/transaction_executor.dart';

class TronExecutor implements TransactionExecutor {
  @override
  String get blockchain => 'tron';

  @override
  String? validateAddress(String address) =>
      (address.startsWith('T') && address.length == 34 &&
          RegExp(r'^[1-9A-HJ-NP-Za-km-z]{34}$').hasMatch(address))
          ? null
          : 'Invalid Tron address — must start with T (34 chars)';

  @override
  Future<String> execute({
    required String mnemonic,
    required Asset asset,
    required String toAddress,
    required String amount,
  }) async {
    // Derived off the interface thread — see core/crypto/seed.dart.
    final wallet = TronWallet.fromHdWallet(HDWallet.fromSeed(await mnemonicSeed(mnemonic)));
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
        throw Exception('Unknown TRC-20 contract for ${asset.symbol}');
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
