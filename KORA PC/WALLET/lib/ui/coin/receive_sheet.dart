import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/kora_design.dart';
import '../common/kora_button.dart';
import '../common/kora_sheet.dart';

/// An address, as a code and as text.
///
/// A real encoder, not a drawing that looks like one: a receive code nobody can scan is worse
/// than no code at all.
class ReceiveSheet extends StatelessWidget {
  const ReceiveSheet({
    super.key,
    required this.symbol,
    required this.chain,
    required this.network,
    required this.walletName,
    required this.address,
  });

  final String symbol;
  final String chain;
  final String network;
  final String walletName;
  final String address;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);

    return KoraSheet(
      title: 'RECEIVE $symbol',
      subtitle: '$network · $chain · ${walletName.toUpperCase()}',
      body: [
        // White quiet zone regardless of theme: a scanner needs the contrast, not the palette.
        Center(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: QrImageView(
              data: address,
              version: QrVersions.auto,
              size: 208,
              gapless: true,
              backgroundColor: Colors.white,
              // Medium recovery: enough to survive a scuffed screen without inflating the
              // code to the point where the modules get too small to read.
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.surface, border: Border.all(color: p.border)),
          child: Text(
            address,
            textAlign: TextAlign.center,
            style: koraLabel(p.text, size: 11, tracking: 0).copyWith(height: 1.5),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Send only $symbol on $network to this address.\nAnything else is lost permanently.',
          textAlign: TextAlign.center,
          style: koraLabel(p.text3, size: 9.5, tracking: 0).copyWith(height: 1.5),
        ),
      ],
      actions: [
        _CopyAddress(address: address),
        KoraButton(
          label: 'DONE',
          expand: true,
          tone: KoraButtonTone.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _CopyAddress extends StatefulWidget {
  const _CopyAddress({required this.address});

  final String address;

  @override
  State<_CopyAddress> createState() => _CopyAddressState();
}

class _CopyAddressState extends State<_CopyAddress> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) => KoraButton(
        label: _copied ? 'COPIED' : 'COPY ADDRESS',
        expand: true,
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: widget.address));
          if (!mounted) return;
          setState(() => _copied = true);
          await Future<void>.delayed(const Duration(milliseconds: 1400));
          if (mounted) setState(() => _copied = false);
        },
      );
}
