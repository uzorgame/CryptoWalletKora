import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/asset.dart';
import 'executors/evm_executor.dart';
import 'executors/solana_executor.dart';
import 'executors/tron_executor.dart';
import 'executors/utxo_executor.dart';
import 'fee/bitcoin_cash_fee/bitcoin_cash_fee_provider.dart';
import 'fee/bitcoin_fee/bitcoin_fee_provider.dart';
import 'fee/bsc_fee/bsc_fee_provider.dart';
import 'fee/ethereum_classic_fee/ethereum_classic_fee_provider.dart';
import 'fee/ethereum_fee/ethereum_fee_provider.dart';
import 'fee/litecoin_fee/litecoin_fee_provider.dart';
import 'fee/models/fee_estimate.dart';
import 'fee/solana_fee/solana_fee_provider.dart';
import 'fee/tron_fee/tron_fee_provider.dart';
import 'services/transaction_executor.dart';

/// The one place that knows which chain uses which executor and which fee provider.
///
/// This dispatch used to live in the send screen — three separate switch statements over the
/// same blockchain strings, one to pick an executor, one to read a fee and one to watch it.
/// Three copies of the same list is three chances for a chain to be added to two of them.
class SendGateway {
  const SendGateway._();

  /// Chains whose fee genuinely varies by how long you are willing to wait. The rest quote a
  /// single price, and offering them a slow/normal/fast choice would be offering a choice
  /// that changes nothing.
  static const _tieredChains = {'bitcoin', 'litecoin', 'bitcoin_cash'};

  static bool hasSpeedTiers(String blockchain) => _tieredChains.contains(blockchain);

  /// The executor for a chain, carrying the chosen fee rate where the chain takes one.
  ///
  /// The estimate goes in whole rather than a plucked-out number: only this file should know
  /// that a UTXO chain's rate is hidden under `details['satPerVByte']`, because that is the
  /// kind of detail a caller copies once and then never updates.
  static TransactionExecutor? executorFor(String blockchain, {FeeEstimate? fee}) {
    final satPerVByte = (fee?.details?['satPerVByte'] as num?)?.toInt();
    return switch (blockchain) {
      'ethereum' || 'bsc' || 'ethereum_classic' => EvmExecutor(),
      'tron' => TronExecutor(),
      'solana' => SolanaExecutor(),
      'bitcoin' || 'litecoin' || 'bitcoin_cash' => UtxoExecutor(blockchain, satPerVByte),
      _ => null,
    };
  }

  /// The tier each chain's fee provider is actually keyed by.
  ///
  /// Only the UTXO chains vary their estimate by speed. The EVM notifiers accept a tier and
  /// ignore it, and Tron and Solana have none at all — so every other chain is keyed by one
  /// constant value. Keying them by the UI's tier instead would create a separate notifier
  /// per tier, each of which would have to fetch the same number again.
  static FeeSpeed? _key(String blockchain, FeeSpeed speed) => switch (blockchain) {
        'bitcoin' || 'litecoin' || 'bitcoin_cash' => speed,
        'solana' || 'tron' => null,
        _ => FeeSpeed.normal,
      };

  /// Watches the fee estimate for an asset at a given speed.
  ///
  /// Watched rather than read: an estimate arrives after the form is built, and a fee shown
  /// once and never updated is a number that quietly goes stale while the user reads it.
  ///
  /// Watching alone is not enough — see [requestFee]. Every one of these is a
  /// `StateNotifierProvider` that starts at `AsyncValue.data(null)` and fetches nothing until
  /// it is told to.
  static AsyncValue<FeeEstimate?> watchFee(WidgetRef ref, Asset asset, FeeSpeed speed) {
    final isToken = asset.type == AssetType.token;
    final key = _key(asset.blockchain, speed);
    return switch (asset.blockchain) {
      'bitcoin' => ref.watch(bitcoinFeeProvider(key)),
      'litecoin' => ref.watch(litecoinFeeProvider(key)),
      'bitcoin_cash' => ref.watch(bitcoinCashFeeProvider(key)),
      'ethereum' => ref.watch(ethereumFeeProvider(
          EthereumFeeParams(blockchain: 'ethereum', speed: key, isToken: isToken))),
      'bsc' => ref.watch(bscFeeProvider(key)),
      'ethereum_classic' => ref.watch(ethereumClassicFeeProvider(key)),
      'solana' => ref.watch(solanaFeeProvider(key)),
      'tron' => ref.watch(tronFeeProvider),
      _ => const AsyncValue.data(null),
    };
  }

  /// Asks the chain what it currently costs.
  ///
  /// This is the half that was missing. Every fee provider here is a `StateNotifierProvider`
  /// seeded with `AsyncValue.data(null)`; nothing in it fetches on construction. A screen
  /// that only watched therefore sat on `null` forever and rendered a dash where the fee
  /// should be — on every chain, not just one. The old send form called the equivalent
  /// `_fetchFee()` by hand on open and on every change; this is that call, in the one place
  /// that already knows which notifier belongs to which chain.
  static void requestFee(WidgetRef ref, Asset asset, FeeSpeed speed) {
    final isToken = asset.type == AssetType.token;
    final key = _key(asset.blockchain, speed);
    switch (asset.blockchain) {
      case 'bitcoin':
        ref.read(bitcoinFeeProvider(key).notifier).fetchFee();
      case 'litecoin':
        ref.read(litecoinFeeProvider(key).notifier).fetchFee();
      case 'bitcoin_cash':
        ref.read(bitcoinCashFeeProvider(key).notifier).fetchFee();
      case 'ethereum':
        ref
            .read(ethereumFeeProvider(
                    EthereumFeeParams(blockchain: 'ethereum', speed: key, isToken: isToken))
                .notifier)
            .fetchFee();
      case 'bsc':
        ref.read(bscFeeProvider(key).notifier).fetchFee(isToken: isToken);
      case 'ethereum_classic':
        ref.read(ethereumClassicFeeProvider(key).notifier).fetchFee();
      case 'solana':
        ref.read(solanaFeeProvider(key).notifier).fetchFee();
      case 'tron':
        ref.read(tronFeeProvider.notifier).fetchFee(isToken: isToken);
    }
  }
}
