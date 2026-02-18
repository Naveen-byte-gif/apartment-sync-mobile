import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import 'upi_app_selector.dart';
import 'upi_qr_scanner_screen.dart';

/// Screen with a primary "Scan & Pay" button.
/// Tap → Select UPI app (GPay / PhonePe / Paytm / BHIM) → Open scanner → Scan QR → Auto-fill payment in selected app.
class ScanAndPayScreen extends StatelessWidget {
  const ScanAndPayScreen({super.key});

  Future<void> _onTapScanAndPay(BuildContext context) async {
    // 1. Ask user to select UPI method
    final selected = await showUpiAppSelector(context);
    if (!context.mounted || selected == null) return;
    // 2. Navigate to scanner (payment will open in selected app after scan)
    final launched = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => UpiQrScannerScreen(preferredApp: selected),
      ),
    );
    if (context.mounted && launched == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opened in ${selected.label}. Complete payment there.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan & Pay'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Icon(
                Icons.qr_code_scanner,
                size: 80,
                color: AppColors.primary.withOpacity(0.8),
              ),
              const SizedBox(height: 24),
              const Text(
                'Tap to scan UPI QR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select your UPI app, then scan any payment QR. Amount and details will auto-fill in that app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _onTapScanAndPay(context),
                  icon: const Icon(Icons.qr_code_scanner, size: 26),
                  label: const Text(
                    'Scan & Pay',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: AppColors.info.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap above → Choose UPI app → Scan QR. Payment opens in your chosen app with amount pre-filled.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
