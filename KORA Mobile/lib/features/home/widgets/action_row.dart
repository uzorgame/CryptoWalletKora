import 'package:flutter/material.dart';
import 'package:kora/features/receive/open_receive.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/features/send/send_screen.dart';
import 'package:kora/features/scan/qr_scanner_screen.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/core/widgets/animated_tap.dart';

// The Send / Receive / Scan shortcuts under the balance.

class ActionRow extends StatelessWidget {
  const ActionRow({super.key, required this.assets});
  final List<Asset> assets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        _ActionBtn(label: 'Send', icon: Icons.arrow_upward_rounded,
            onTap: () { context.pushModal(SendScreen(assets: assets)); }),
        const SizedBox(width: 12),
        _ActionBtn(label: 'Receive', icon: Icons.arrow_downward_rounded,
            onTap: () { openReceivePicker(context, assets); }),
        const SizedBox(width: 12),
        _ActionBtn(label: 'Scan', icon: Icons.qr_code_scanner_rounded,
            onTap: () async { 
              final addr = await context.pushModal<String>(const QrScannerScreen());
              if (addr != null && addr.isNotEmpty && context.mounted) {
                context.pushModal(SendScreen(
                      assets: assets,
                      initialAddress: addr,
                    ));
              }
            }),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedTap(
        onTap: onTap,
        pressScale: 0.92,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(children: [
            Icon(icon, color: AppColors.textPrimary, size: 22),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
