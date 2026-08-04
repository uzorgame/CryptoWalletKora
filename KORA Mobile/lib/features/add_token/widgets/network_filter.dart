import 'package:flutter/material.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';

// The network filter strip: which chains can be filtered by, and the chip that picks one.

class NetworkOption {
  const NetworkOption({
    required this.id,
    required this.label,
    required this.iconSymbol,
  });
  final String? id;       // null = All
  final String label;
  final String iconSymbol;
}

const networks = <NetworkOption>[
  NetworkOption(id: null,        label: 'All',       iconSymbol: ''),
  NetworkOption(id: 'ethereum',  label: 'Ethereum',  iconSymbol: 'ETH'),
  NetworkOption(id: 'bsc',       label: 'BSC',       iconSymbol: 'BNB'),
  NetworkOption(id: 'tron',      label: 'Tron',      iconSymbol: 'TRX'),
  NetworkOption(id: 'solana',    label: 'Solana',    iconSymbol: 'SOL'),
  NetworkOption(id: 'bitcoin',   label: 'Bitcoin',   iconSymbol: 'BTC'),
  NetworkOption(id: 'litecoin',  label: 'Litecoin',  iconSymbol: 'LTC'),
];

class NetworkChip extends StatelessWidget {
  const NetworkChip({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final NetworkOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.9,
      child: AnimatedContainer(
        duration: kControl,
        curve: kEase,
        margin: const EdgeInsets.only(right: 1),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.background,
          border: kHairline(),
        ),
        child: Text(
          option.label.toUpperCase(),
          style: kLabel(
            selected ? AppColors.background : AppColors.textTertiary,
            size: 9.5,
            tracking: 0.1,
          ),
        ),
      ),
    );
  }
}

String networkLabel(String blockchain) {
  const map = <String, String>{
    'bitcoin': 'Bitcoin',     'ethereum': 'Ethereum',  'solana': 'Solana',
    'bsc': 'BNB Smart Chain', 'tron': 'Tron',          'dogecoin': 'Dogecoin',
    'litecoin': 'Litecoin',
  };
  return map[blockchain] ?? blockchain;
}
