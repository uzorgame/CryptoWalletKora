import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:kora/core/theme/kora_design.dart';

/// Full-screen QR scanner. Returns the scanned string via Navigator.pop.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _done = true;
    // Many wallets encode QR as  "<scheme>:<address>?amount=..."
    // Strip known prefixes to extract the bare address.
    final cleaned = _extractAddress(raw);
    Navigator.of(context).pop(cleaned);
  }

  static String _extractAddress(String raw) {
    for (final scheme in [
      'ethereum:', 'bitcoin:', 'tron:', 'solana:',
      'litecoin:', 'dogecoin:',
    ]) {
      if (raw.toLowerCase().startsWith(scheme)) {
        final rest = raw.substring(scheme.length);
        final q = rest.indexOf('?');
        return q >= 0 ? rest.substring(0, q) : rest;
      }
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text('SCAN QR CODE',
            style: kLabel(Colors.white, size: 11, tracking: 0.18)),
        iconTheme: const IconThemeData(color: Colors.white, size: 18),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, size: 19),
            onPressed: () => _ctrl.toggleTorch(),
            tooltip: 'Toggle flash',
          ),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: _onDetect,
        ),
        // Overlay with cut-out square
        _ScanOverlay(),
        // Hint label
        Positioned(
          bottom: 60,
          left: 0, right: 0,
          child: Center(
            child: Text(
              'ALIGN QR CODE WITHIN THE FRAME',
              style: kLabel(Colors.white70, size: 9.5, tracking: 0.16),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cutSize = 260.0;
    final cx = size.width / 2;
    final cy = size.height / 2 - 40;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: cutSize, height: cutSize);

    // Dim everything except cut-out
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(rect),
      ),
      dimPaint,
    );

    // Corner brackets
    // Square brackets, butt-capped: the finder has no rounded corner anywhere else in
    // this application either.
    const cLen = 40.0;
    const cW   = 1.5;
    final cPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = cW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final r = rect;

    // Top-left
    canvas.drawLine(r.topLeft, r.topLeft.translate(cLen, 0), cPaint);
    canvas.drawLine(r.topLeft, r.topLeft.translate(0, cLen), cPaint);
    // Top-right
    canvas.drawLine(r.topRight, r.topRight.translate(-cLen, 0), cPaint);
    canvas.drawLine(r.topRight, r.topRight.translate(0, cLen), cPaint);
    // Bottom-left
    canvas.drawLine(r.bottomLeft, r.bottomLeft.translate(cLen, 0), cPaint);
    canvas.drawLine(r.bottomLeft, r.bottomLeft.translate(0, -cLen), cPaint);
    // Bottom-right
    canvas.drawLine(r.bottomRight, r.bottomRight.translate(-cLen, 0), cPaint);
    canvas.drawLine(r.bottomRight, r.bottomRight.translate(0, -cLen), cPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
