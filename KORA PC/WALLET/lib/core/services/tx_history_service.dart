import 'package:kora_windows/core/models/asset.dart';
import 'package:kora_windows/core/constants/token_catalog.dart';
import 'package:kora_windows/core/config/api_config.dart';
import 'package:kora_windows/core/models/tx_record.dart';
import 'package:kora_windows/core/services/history/evm_history.dart';
import 'package:kora_windows/core/services/history/solana_history.dart';
import 'package:kora_windows/core/services/history/tron_history.dart';
import 'package:kora_windows/core/services/history/utxo_history.dart';

export 'package:kora_windows/core/models/tx_record.dart';
export 'package:kora_windows/core/services/history/history_cache.dart';
export 'package:kora_windows/core/services/history/pending_tx_store.dart';

/// Where a history request goes, per chain.
///
/// The clients themselves live one per chain under `services/history/`. A UTXO transaction and
/// an EVM one have almost nothing in common beyond the type they produce, and keeping them in
/// one file meant every change to Bitcoin's output reconstruction sat in the same place as
/// Etherscan's key rotation.
///
/// [TxRecord] and the caches are re-exported here, so a caller can go on asking the history
/// service for the history service.
///
/// Resolves the wallet's own address for the chain — a token has none of its own, and its
/// movements are recorded against the native coin's address, which is why [walletAssets] is
/// needed rather than just the asset being asked about.
Future<List<TxRecord>> fetchHistoryForAsset({
  required Asset asset,
  required List<Asset> walletAssets,
  int limit = 50,
}) async {
  // Resolve user's wallet address for this chain
  final String userAddress;
  if (asset.type == AssetType.native) {
    userAddress = asset.contractAddress;
  } else {
    final native = walletAssets.firstWhere(
      (a) => a.blockchain == asset.blockchain && a.type == AssetType.native,
      orElse: () => asset,
    );
    userAddress = native.contractAddress;
  }

  // Resolve token contract address from catalog (e.g. 0xdAC17... for USDT-ETH)
  String? contractAddr;
  if (asset.type == AssetType.token) {
    try {
      contractAddr = allCatalogTokens.firstWhere((t) => t.id == asset.id).contractAddress;
    } catch (_) {}
  }

  final chain = asset.blockchain;
  if (APIConfig.evmChains.contains(chain)) {
    return fetchEvmHistory(
      address: userAddress,
      blockchain: chain,
      contractAddress: contractAddr,
      limit: limit,
    );
  } else if (chain == 'tron') {
    return fetchTronHistory(address: userAddress, contractAddress: contractAddr, limit: limit);
  } else if (chain == 'solana') {
    if (asset.type == AssetType.token && contractAddr != null) {
      return fetchSolanaTokenHistory(
        ownerAddress: userAddress,
        mintAddress: contractAddr,
        symbol: asset.symbol,
        decimals: asset.decimals,
      );
    }
    return fetchSolanaHistory(address: userAddress, limit: limit);
  } else if (chain == 'bitcoin') {
    return fetchBitcoinHistory(address: userAddress, limit: limit);
  } else if (chain == 'litecoin') {
    return fetchLitecoinHistory(address: userAddress, limit: limit);
  } else if (chain == 'bitcoin_cash') {
    return fetchBlockchairUtxoHistory(
      address: userAddress,
      blockchain: chain,
      symbol: asset.symbol,
      limit: limit,
    );
  }
  return [];
}
