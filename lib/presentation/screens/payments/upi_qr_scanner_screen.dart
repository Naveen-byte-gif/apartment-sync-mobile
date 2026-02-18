import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/upi_launcher_service.dart';
import 'upi_app_selector.dart';

/// Full-screen camera scanner that detects UPI QR codes (upi://pay?...).
/// On detection: launches the UPI deep link in the selected app and pops this screen.
class UpiQrScannerScreen extends StatefulWidget {
  /// Preferred UPI app to open payment in (from "Select UPI app" step).
  final UpiAppOption? preferredApp;

  const UpiQrScannerScreen({super.key, this.preferredApp});

  @override
  State<UpiQrScannerScreen> createState() => _UpiQrScannerScreenState();
}

class _UpiQrScannerScreenState extends State<UpiQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _hasLaunched = false;
  String? _lastLaunchedUri;
  Timer? _debounceTimer;

  static const String _upiPrefix = 'upi://pay';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool _isUpiDeepLink(String? value) {
    if (value == null || value.isEmpty) return false;
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith(_upiPrefix);
  }

  Future<void> _launchUpiAndClose(String upiUri) async {
    if (_hasLaunched) return;
    // Debounce: same QR can be reported multiple times
    if (_lastLaunchedUri == upiUri) return;
    _lastLaunchedUri = upiUri;
    _hasLaunched = true;

    try {
      final launched = await UpiLauncherService.launchUpi(
        upiUri,
        androidPackage: widget.preferredApp?.androidPackage,
      );
      if (mounted) {
        if (launched) {
          Navigator.of(context).pop(true);
        } else {
          _showError('Could not open UPI app.');
          setState(() => _hasLaunched = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Invalid UPI link or app not found.');
        setState(() => _hasLaunched = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasLaunched) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      final raw = barcode.rawValue ?? barcode.displayValue;
      if (_isUpiDeepLink(raw)) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          _launchUpiAndClose(raw!);
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan UPI QR',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay hint
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.preferredApp != null
                    ? 'Point camera at UPI QR.\nPayment will open in ${widget.preferredApp!.label}.'
                    : 'Point camera at UPI QR code.\nAmount & details will open in your UPI app.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
