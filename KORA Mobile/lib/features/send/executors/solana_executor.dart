import 'package:kora/core/models/asset.dart';
import 'package:kora/core/blockchain/solana/solana_wallet.dart';
import 'package:kora/core/blockchain/solana/solana_service.dart';
import 'package:kora/features/send/services/transaction_executor.dart';

class SolanaExecutor implements TransactionExecutor {
  @override
  String get blockchain => 'solana';

  @override
  String? validateAddress(String address) {
    return RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(address)
        ? null
        : 'Invalid Solana address (Base58, 32–44 chars)';
  }

  @override
  Future<String> execute({
    required String mnemonic,
    required Asset asset,
    required String toAddress,
    required String amount,
  }) async {
    final wallet = SolanaWallet.fromMnemonic(mnemonic);
    final svc = SolanaService();

    if (asset.type == AssetType.native) {
      final lamports = toTokenAmount(amount, 9).toInt();
      return await svc.sendSOL(
        fromAddress: wallet.address,
        toAddress: toAddress,
        lamports: lamports,
        signer: wallet.signTransaction,
      );
    } else {
      return await svc.sendSPLToken(
        fromAddress: wallet.address,
        toAddress: toAddress,
        mintAddress: asset.contractAddress,
        amount: toTokenAmount(amount, asset.decimals),
        signer: wallet.signTransaction,
      );
    }
  }
}
