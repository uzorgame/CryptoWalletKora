import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/features/send/fee/models/fee_estimate.dart';
import 'package:kora/features/send/fee/bitcoin_fee/bitcoin_fee_provider.dart';
import 'package:kora/features/send/fee/ethereum_fee/ethereum_fee_provider.dart';
import 'package:kora/features/send/fee/solana_fee/solana_fee_provider.dart';
import 'package:kora/features/send/fee/tron_fee/tron_fee_provider.dart';
import 'package:kora/features/send/fee/litecoin_fee/litecoin_fee_provider.dart';
import 'package:kora/features/send/fee/bitcoin_cash_fee/bitcoin_cash_fee_provider.dart';
import 'package:kora/features/send/fee/bsc_fee/bsc_fee_provider.dart';
import 'package:kora/features/send/fee/ethereum_classic_fee/ethereum_classic_fee_provider.dart';

// The network-fee readout on the send form.

class FeeWidget extends ConsumerWidget {
  const FeeWidget({super.key, required this.blockchain, this.selectedSpeed = FeeSpeed.normal, this.isToken = false});
  final String blockchain;
  final FeeSpeed selectedSpeed;
  final bool isToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<FeeEstimate?>? feeState;
    final spd = selectedSpeed;

    switch (blockchain) {
      case 'bitcoin':
        feeState = ref.watch(bitcoinFeeProvider(spd));
      case 'ethereum':
        feeState = ref.watch(ethereumFeeProvider(EthereumFeeParams(blockchain: 'ethereum', speed: FeeSpeed.normal, isToken: isToken)));
      case 'bsc':
        feeState = ref.watch(bscFeeProvider(FeeSpeed.normal));
      case 'ethereum_classic':
        feeState = ref.watch(ethereumClassicFeeProvider(FeeSpeed.normal));
      case 'solana':
        feeState = ref.watch(solanaFeeProvider(null));
      case 'tron':
        feeState = ref.watch(tronFeeProvider);
      case 'litecoin':
        feeState = ref.watch(litecoinFeeProvider(spd));
      case 'bitcoin_cash':
        feeState = ref.watch(bitcoinCashFeeProvider(spd));
      default:
        return const SizedBox.shrink();
    }

    return feeState?.when(
      data: (fee) {
        if (fee == null) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.5), width: 0.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text('Network Fee: Unable to fetch',
                    style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              Text('All fee APIs unavailable. Check connection.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontStyle: FontStyle.italic)),
            ]),
          );
        }
        
        final symbol = _getBlockchainSymbol(blockchain);
        
        // Format native fee - smart precision based on magnitude
        String feeNative;
        if (fee.feeInNative >= 1) {
          feeNative = fee.feeInNative.toStringAsFixed(2);
        } else if (fee.feeInNative >= 0.001) {
          feeNative = fee.feeInNative.toStringAsFixed(4);
        } else {
          feeNative = fee.feeInNative.toStringAsFixed(8)
              .replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
        }

        // Format USD - enough decimals to always show a non-zero value
        String feeUsd = '';
        if (fee.feeInUsd > 0) {
          if (fee.feeInUsd >= 1) {
            feeUsd = '\$${fee.feeInUsd.toStringAsFixed(2)}';
          } else if (fee.feeInUsd >= 0.01) {
            feeUsd = '\$${fee.feeInUsd.toStringAsFixed(3)}';
          } else if (fee.feeInUsd >= 0.0001) {
            feeUsd = '\$${fee.feeInUsd.toStringAsFixed(4)}';
          } else {
            feeUsd = '\$${fee.feeInUsd.toStringAsFixed(6)}'
                .replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
          }
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(children: [
            Icon(Icons.local_gas_station_outlined, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 8),
            Text('Network Fee:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$feeNative $symbol',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              if (feeUsd.isNotEmpty)
                Text(feeUsd,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ]),
          ]),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(children: [
          SizedBox(width: 12, height: 12, 
            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          Text('Loading fee...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ]),
      ),
      error: (error, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.5), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Network Fee: Unable to fetch',
                  style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              'API Error: ${error.toString().replaceAll('Exception: ', '').replaceAll('FeeApiException [${blockchain}]: ', '')}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Please check connection or try again later',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    ) ?? const SizedBox.shrink();
  }

  String _getBlockchainSymbol(String blockchain) {
    return switch (blockchain) {
      'bitcoin' => 'BTC',
      'ethereum' => 'ETH',
      'bsc' => 'BNB',
      'ethereum_classic' => 'ETC',
      'solana' => 'SOL',
      'tron' => 'TRX',
      'litecoin' => 'LTC',
      'bitcoin_cash' => 'BCH',
      _ => '',
    };
  }
}
