import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:theme/theme.dart';

/// Full-screen camera that returns the text of the first QR code or barcode it sees.
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key, required this.title});

  final String title;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final value = b.rawValue;
      if (value != null && value.isNotEmpty) {
        _done = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return UiScaffold(
      appBar: UiAppBar(title: widget.title),
      padding: EdgeInsets.zero,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _onDetect, errorBuilder: (context, error) => const CameraError()),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(UiSpace.lg),
              child: UiStatusPill('Point the camera at the code', status: UiStatus.info),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the camera cannot start (permission denied or no camera).
class CameraError extends StatelessWidget {
  const CameraError({super.key});

  @override
  Widget build(BuildContext context) {
    return const UiEmptyState(
      title: 'Camera not available',
      message: 'Allow the camera for Uth in the phone settings to scan a code.',
      icon: Icons.no_photography_rounded,
    );
  }
}
