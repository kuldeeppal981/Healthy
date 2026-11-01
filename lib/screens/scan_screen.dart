import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/theme_service.dart';
import '../theme.dart';
import 'scan_result_screen.dart';

/// Camera barcode scanner. Also has a manual barcode box for emulators or
/// damaged barcodes.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  final TextEditingController _manual = TextEditingController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _open(String code) {
    if (_handled) return;
    _handled = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ScanResultScreen(barcode: code)),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        _open(v);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan product')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ThemeService.undoDark(
                      context,
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error, child) => Container(
                        color: AppColors.card,
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: const Text(
                          'Could not open the camera. Allow camera permission, or type the barcode number below.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    ),
                    Center(
                      child: Container(
                        width: 260,
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                const Text(
                  'Place the barcode inside the box',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manual,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Or type the barcode number'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(80, 52),
                        ),
                        onPressed: () {
                          final v = _manual.text.trim();
                          if (v.length >= 6) _open(v);
                        },
                        child: const Text('Look up'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
