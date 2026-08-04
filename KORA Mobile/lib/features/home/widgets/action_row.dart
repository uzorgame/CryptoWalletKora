import 'package:flutter/material.dart';
import 'package:kora/features/receive/open_receive.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/features/send/send_screen.dart';
import 'package:kora/features/scan/qr_scanner_screen.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';

// The Send / Receive / Scan shortcuts under the balance — one joined group divided by
// one-pixel gaps of the border colour, the signature the desktop's button rows carry.
// Send is the suggested action, so it alone is inverted.
class ActionRow extends StatelessWidget {
  const ActionRow({super.key, required this.assets});
  final List<Asset> assets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        decoration: BoxDecoration(color: AppColors.border, border: kHairline()),
        child: Row(children: [
          _KoraAction(label: 'SEND', primary: true,
              onTap: () { context.pushModal(SendScreen(assets: assets)); }),
          const SizedBox(width: 1),
          _KoraAction(label: 'RECEIVE',
              onTap: () { openReceivePicker(context, assets); }),
          const SizedBox(width: 1),
          _KoraAction(label: 'SCAN',
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
      ),
    );
  }
}

class _KoraAction extends StatelessWidget {
  const _KoraAction({required this.label, required this.onTap, this.primary = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedTap(
        onTap: onTap,
        pressScale: 0.95,
        pressOpacity: 0.8,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: primary ? AppColors.textPrimary : AppColors.background,
          alignment: Alignment.center,
          child: Text(label,
              style: kLabel(
                primary ? AppColors.background : AppColors.textSecondary,
                size: 10.5,
                tracking: 0.14,
              )),
        ),
      ),
    );
  }
}
