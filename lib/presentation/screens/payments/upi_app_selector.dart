import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';

/// UPI app option for "open in this app after scan".
enum UpiAppOption {
  gpay,
  phonepe,
  paytm,
  bhim,
  defaultApp,
}

extension UpiAppOptionX on UpiAppOption {
  String get label {
    switch (this) {
      case UpiAppOption.gpay:
        return 'Google Pay';
      case UpiAppOption.phonepe:
        return 'PhonePe';
      case UpiAppOption.paytm:
        return 'Paytm';
      case UpiAppOption.bhim:
        return 'BHIM';
      case UpiAppOption.defaultApp:
        return 'System default';
    }
  }

  String? get androidPackage {
    switch (this) {
      case UpiAppOption.gpay:
        return 'com.google.android.apps.nbu.paisa.user';
      case UpiAppOption.phonepe:
        return 'com.phonepe.app';
      case UpiAppOption.paytm:
        return 'net.one97.paytm';
      case UpiAppOption.bhim:
        return 'in.org.npci.upiapp';
      case UpiAppOption.defaultApp:
        return null;
    }
  }

  IconData get icon {
    switch (this) {
      case UpiAppOption.gpay:
        return Icons.account_balance_wallet;
      case UpiAppOption.phonepe:
        return Icons.phone_android;
      case UpiAppOption.paytm:
        return Icons.payment;
      case UpiAppOption.bhim:
        return Icons.verified_user;
      case UpiAppOption.defaultApp:
        return Icons.open_in_new;
    }
  }
}

/// Shows a bottom sheet to select UPI app. Returns the selected option or null if dismissed.
Future<UpiAppOption?> showUpiAppSelector(BuildContext context) async {
  return showModalBottomSheet<UpiAppOption>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select UPI app',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Payment will open in this app after you scan the QR',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ...UpiAppOption.values.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, option),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.divider,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                option.icon,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                option.label,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: AppColors.textLight,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    ),
  );
}
