import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class PartnerScannerScreen extends StatefulWidget {
  const PartnerScannerScreen({super.key});
  @override
  State<PartnerScannerScreen> createState() => _PartnerScannerScreenState();
}

class _PartnerScannerScreenState extends State<PartnerScannerScreen> {
  bool _detected = false;
  int _attempt = 0;

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    for (final barcode in capture.barcodes) {
      if (barcode.format != BarcodeFormat.qrCode || barcode.rawValue == null) {
        continue;
      }
      _detected = true;
      // Removing the viewport stops/disposes its camera before verification.
      setState(() {});
      Navigator.of(context).pop(barcode.rawValue!);
      return;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan reward')),
        body: SafeArea(
            child: Column(children: [
          const Padding(
              padding: EdgeInsets.all(20),
              child: Text("Scan the customer's BeenPin QR")),
          Expanded(
              child: _detected
                  ? const SizedBox.shrink()
                  : MobileScanner(
                      key: ValueKey(_attempt),
                      onDetect: _onDetect,
                      // The package's owned controller handles permission requests, lifecycle
                      // pause/resume and disposal. Retry creates a fresh camera session.
                      errorBuilder: (context, error, child) => Center(
                          child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.no_photography_outlined, size: 44),
                          const SizedBox(height: 16),
                          Text(
                              error.errorCode ==
                                      MobileScannerErrorCode.permissionDenied
                                  ? 'Camera access is needed to scan rewards. Allow access in Settings if permission was denied.'
                                  : 'Camera unavailable. Close other camera apps and try again.',
                              textAlign: TextAlign.center),
                          TextButton(
                              onPressed: () => setState(() => _attempt++),
                              child: const Text('Retry')),
                          TextButton(
                              onPressed: () async {
                                await openAppSettings();
                              },
                              child: const Text('Open Settings')),
                        ]),
                      )),
                    )),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
        ])),
      );
}
