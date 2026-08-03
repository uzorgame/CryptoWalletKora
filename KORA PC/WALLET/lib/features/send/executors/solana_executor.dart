import 'package:kora_windows/core/crypto/seed.dart';
import 'package:kora_windows/core/crypto/hd_wallet.dart';
import 'package:kora_windows/core/models/asset.dart';
import 'package:kora_windows/core/blockchain/solana/solana_wallet.dart';
import 'package:kora_windows/core/blockchain/solana/solana_service.dart';
import 'package:kora_windows/core/constants/token_catalog.dart';
import 'package:kora_windows/features/send/services/transaction_executor.dart';

class SolanaExecutor implements TransactionExecutor {
  @override
  String get blockchain => 'solana';

  @override
  String? validateAddress(String address) =>
      RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(address)
          ? null
          : 'Invalid Solana address (Base58, 32–44 chars)';

  @override
  Future<String> execute({
    required String mnemonic,
    required Asset asset,
    required String toAddress,
    required String amount,
  }) async {
    // Derived off the interface thread — see core/crypto/seed.dart.
    final wallet = SolanaWallet.fromSeed(await mnemonicSeed(mnemonic));
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
      final mintAddress = allCatalogTokens
          .where((t) => t.id == asset.id)
          .map((t) => t.contractAddress)
          .firstOrNull;
      if (mintAddress == null || mintAddress.isEmpty) {
        throw Exception('Unknown SPL token mint for ${asset.symbol}');
      }
      return await svc.sendSPLToken(
        fromAddress: wallet.address,
        toAddress: toAddress,
        mintAddress: mintAddress,
        amount: toTokenAmount(amount, asset.decimals),
        signer: wallet.signTransaction,
      );
    }
  }
}
