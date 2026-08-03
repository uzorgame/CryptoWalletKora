import 'package:kora/features/send/executors/evm_executor.dart';
import 'package:kora/features/send/executors/tron_executor.dart';
import 'package:kora/features/send/executors/solana_executor.dart';
import 'package:kora/features/send/executors/utxo_executor.dart';
import 'package:kora/features/send/services/transaction_executor.dart';
import 'package:kora/features/send/fee/models/fee_estimate.dart';

// Which executor signs for which chain — the one place that mapping is written down.

TransactionExecutor? getExecutor(String blockchain) {
  return switch (blockchain) {
    // EVM chains
    'ethereum' || 'bsc' ||
    'ethereum_classic' => EvmExecutor(),
    
    // TRON
    'tron' => TronExecutor(),
    
    // Bitcoin-like
    'bitcoin' || 'litecoin' || 'bitcoin_cash' => UtxoExecutor(blockchain, null),
    
    // Solana
    'solana' => SolanaExecutor(),
    
    _ => null,
  };
}

TransactionExecutor? getExecutorWithFee(String blockchain, FeeEstimate? fee) {
  final satPerVByte = (fee?.details?['satPerVByte'] as num?)?.toInt();
  return switch (blockchain) {
    'bitcoin' || 'litecoin' || 'bitcoin_cash' => UtxoExecutor(blockchain, satPerVByte),
    _ => getExecutor(blockchain),
  };
}
