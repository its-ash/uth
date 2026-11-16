import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:theme/theme.dart';

/// Camera that waits for the registered code ([expected]). Any other code shows a hint.
class QrView extends StatefulWidget {
  const QrView({super.key, required this.expected, required this.onSolved, required this.onUnavailable});

  final String expected;
  final VoidCallback onSolved;

  /// The camera cannot start (no permission, no camera): the user may switch to a math challenge.
  final VoidCallback onUnavailable;

  @override
  State<QrView> createState() => _QrViewState();
}

class _QrViewState extends State<QrView> {
  bool _wrong = false;
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final values = [for (final b in capture.barcodes) b.rawValue];
    if (values.contains(widget.expected)) {
      _done = true;
      widget.onSolved();
    } else if (values.any((v) => v != null)) {
      if (!_wrong) setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UiColumn(
      gap: UiSpace.md,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Scan your registered code', textAlign: TextAlign.center, style: context.text.titleMedium),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(UiRadius.lg),
            child: MobileScanner(
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: UiColumn(
                  gap: UiSpace.md,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('The camera is not available.', textAlign: TextAlign.center),
                    UiButton('Solve math instead', variant: UiButtonVariant.outline, onPressed: widget.onUnavailable),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_wrong) const UiAlert('That is not the registered code.', status: UiStatus.warning),
      ],
    );
  }
}
