import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/features/send/fee/models/fee_estimate.dart';
import 'package:kora/features/send/fee/bitcoin_fee/bitcoin_fee_provider.dart';
import 'package:kora/features/send/fee/ethereum_fee/ethereum_fee_provider.dart';
import 'package:kora/features/send/fee/solana_fee/solana_fee_provider.dart';
import 'package:kora/features/send/fee/tron_fee/tron_fee_provider.dart';
import 'package:kora/features/send/fee/litecoin_fee/litecoin_fee_provider.dart';
import 'package:kora/features/send/fee/bitcoin_cash_fee/bitcoin_cash_fee_provider.dart';
import 'package:kora/features/send/fee/bsc_fee/bsc_fee_provider.dart';
import 'package:kora/features/send/fee/ethereum_classic_fee/ethereum_classic_fee_provider.dart';

// The network-fee readout on the send form. A hairline box in every state — quoting, quoted,
// unreachable — so the form never jumps when the answer changes shape. The screen's own
// NETWORK FEE label sits above this widget, so no state repeats the words inside.
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
          return _warnBox(
            'NETWORK FEE UNAVAILABLE',
            'ALL FEE APIS UNREACHABLE. CHECK CONNECTION.',
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: AppColors.surface, border: kHairline()),
          child: Row(children: [
            Text('$feeNative $symbol',
                style: kMonoText(AppColors.textPrimary, size: 11, weight: FontWeight.w500)),
            const Spacer(),
            if (feeUsd.isNotEmpty)
              Text(feeUsd, style: kMonoText(AppColors.textSecondary, size: 10)),
          ]),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: AppColors.surface, border: kHairline()),
        child: Row(children: [
          SizedBox(width: 10, height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.2, color: AppColors.textTertiary)),
          const SizedBox(width: 10),
          Text('FETCHING FEE',
              style: kLabel(AppColors.textTertiary, size: 9, tracking: 0.14)),
        ]),
      ),
      error: (error, __) => _warnBox(
        'NETWORK FEE UNAVAILABLE',
        // The provider's own message, stripped of its exception dressing.
        '${error.toString().replaceAll('Exception: ', '').replaceAll('FeeApiException [$blockchain]: ', '')}'
            .toUpperCase(),
      ),
    ) ?? const SizedBox.shrink();
  }

  /// The amber-edged hairline bar every fee failure wears.
  Widget _warnBox(String title, String detail) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppColors.warning, width: 2),
            top: kHairlineSide(), right: kHairlineSide(), bottom: kHairlineSide(),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: kLabel(AppColors.warning, size: 9, tracking: 0.1)),
          const SizedBox(height: 5),
          Text(detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: kLabel(AppColors.textTertiary, size: 8, tracking: 0.06,
                      weight: FontWeight.w400)
                  .copyWith(height: 1.7)),
        ]),
      );

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
