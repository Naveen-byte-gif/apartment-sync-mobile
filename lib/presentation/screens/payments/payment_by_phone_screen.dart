import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/upi_launcher_service.dart';
import '../../../data/models/payment_data.dart';
import 'payment_confirmation_screen.dart';
import 'scan_and_pay_screen.dart';
import 'upi_app_selector.dart';

class PaymentByPhoneScreen extends StatefulWidget {
  /// Optional: when paying for a specific invoice (e.g. from Pay Now on invoice)
  final String? invoiceId;
  /// Optional: prefill amount (e.g. from invoice outstanding)
  final double? initialAmount;

  const PaymentByPhoneScreen({
    super.key,
    this.invoiceId,
    this.initialAmount,
  });

  @override
  State<PaymentByPhoneScreen> createState() => _PaymentByPhoneScreenState();
}

class _PaymentByPhoneScreenState extends State<PaymentByPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedPurpose = 'Maintenance';
  bool _isLoading = false;
  String? _upiDeepLink;
  String? _paymentNote;
  PaymentData? _payment;
  bool _deepLinkFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
    }
    _loadUpiConfig();
    _loadUserPhoneNumber();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPhoneNumber() async {
    try {
      final userJson = StorageService.getString(AppConstants.userKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        final phone = userData['phoneNumber']?.toString();
        if (phone != null) {
          setState(() {
            _phoneController.text = phone;
          });
        }
      }
    } catch (e) {
      print('Error loading user phone: $e');
    }
  }

  Future<void> _loadUpiConfig() async {
    try {
      final response = await ApiService.get(ApiConstants.publicUpiConfig);
      if (response['success'] == true) {
        final data = response['data'];
        if (data != null && data is Map<String, dynamic>) {
          setState(() {});
        }
      }
    } catch (e, stackTrace) {
      print('Error loading UPI config: $e');
    }
  }

  Future<void> _initiatePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _deepLinkFailed = false;
    });

    try {
      final phoneNumber = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
      final amount = double.parse(_amountController.text);

      // Validate minimum amount (₹10)
      if (amount < 10) {
        AppMessageHandler.handleError(
          context,
          'Minimum payment amount is ₹10. Test payments of ₹1 are not allowed.',
        );
        setState(() => _isLoading = false);
        return;
      }

      final body = <String, dynamic>{
        'phoneNumber': phoneNumber,
        'amount': amount,
        'paymentPurpose': _selectedPurpose,
        'description': _descriptionController.text.trim(),
      };
      if (widget.invoiceId != null && widget.invoiceId!.isNotEmpty) {
        body['invoiceId'] = widget.invoiceId;
      }
      final response = await ApiService.post(
        ApiConstants.createPaymentByPhone,
        body,
      );

      if (response['success'] == true) {
        final data = response['data'];
        if (data != null && data is Map<String, dynamic>) {
          try {
            setState(() {
              _upiDeepLink = data['upiDeepLink']?.toString();
              _paymentNote = data['paymentNote']?.toString();
              if (data['payment'] != null && data['payment'] is Map<String, dynamic>) {
                _payment = PaymentData.fromJson(data['payment'] as Map<String, dynamic>);
              }
            });
          } catch (e, stackTrace) {
            print('Error parsing payment response: $e');
            AppMessageHandler.handleError(
              context,
              'Error processing payment response. Please try again.',
            );
            setState(() => _isLoading = false);
            return;
          }
        }
        // QR-first flow: do NOT auto-open UPI app. Show QR as Solution 1 (BEST).
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scan the QR code with GPay for highest success rate'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        final message = response['message'] ?? 'Failed to initiate payment';
        
        // Check if error is about security/decline
        if (message.toLowerCase().contains('security') || 
            message.toLowerCase().contains('decline')) {
          setState(() {
            _deepLinkFailed = true;
          });
        } else {
          AppMessageHandler.handleError(context, message);
        }
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
      setState(() {
        _deepLinkFailed = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Open payment in UPI app only after user selects one (GPay, PhonePe, etc.). Never auto-open.
  Future<void> _openInUpiAppAfterSelection() async {
    if (_upiDeepLink == null) return;
    // First: ask user to select which UPI app (no opening until they choose)
    final selected = await showUpiAppSelector(context);
    if (!mounted || selected == null) return;
    try {
      final launched = await UpiLauncherService.launchUpi(
        _upiDeepLink!,
        androidPackage: selected.androidPackage,
      );
      if (!mounted) return;
      if (!launched) {
        setState(() => _deepLinkFailed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open ${selected.label}. Install the app or try another.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deepLinkFailed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open UPI app.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showQrCodeDialog() {
    if (_upiDeepLink == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Solution 1 (BEST): Scan with GPay',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Open GPay → Scan → Pay',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: _upiDeepLink!,
                  version: QrVersions.auto,
                  size: 250,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Amount: ₹${_amountController.text}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_paymentNote != null) ...[
                const SizedBox(height: 8),
                Text(
                  _paymentNote!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarkAsPaidDialog() {
    final transactionIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the UPI Transaction ID (UTR) from your payment confirmation.\n\nInvoice will be generated after you confirm the payment.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: transactionIdController,
              decoration: InputDecoration(
                labelText: 'Transaction ID',
                hintText: 'Enter UPI Transaction Reference ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToConfirmation(transactionIdController.text.trim());
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _navigateToConfirmation(String? upiReferenceId) {
    if (_payment == null) return;

    // Navigate to confirmation - invoice will be generated there
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentConfirmationScreen(
          paymentId: _payment!.id,
          invoice: null, // No invoice yet - will be generated
          amount: double.parse(_amountController.text),
          upiReferenceId: upiReferenceId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay by Mobile Number'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Card(
                color: AppColors.info.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Enter your phone number to make payment. Invoice will be generated after payment confirmation.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScanAndPayScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  label: const Text('Scan & Pay (scan any UPI QR)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Phone Number field
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter 10-digit phone number',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: 'Your registered phone number',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  final phone = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (phone.length != 10) {
                    return 'Please enter a valid 10-digit phone number';
                  }
                  if (!phone.startsWith(RegExp(r'[6-9]'))) {
                    return 'Phone number should start with 6, 7, 8, or 9';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Amount field
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  hintText: 'Enter payment amount (min ₹10)',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: 'Minimum amount: ₹10',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount < 10) {
                    return 'Minimum payment amount is ₹10';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Payment purpose
              const Text(
                'Payment Purpose',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPurpose,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['Maintenance', 'Water', 'Other']
                    .map((purpose) => DropdownMenuItem(
                          value: purpose,
                          child: Text(purpose),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedPurpose = value ?? 'Maintenance');
                },
              ),
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Add any additional notes',
                  prefixIcon: const Icon(Icons.note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              
              // Solution 1 (BEST): Scan QR code
              if (_payment != null && _upiDeepLink != null) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  color: AppColors.success.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.success.withOpacity(0.4), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle, color: AppColors.success, size: 28),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Solution 1 (BEST): Scan QR code',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ask payer to:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StepRow(num: 1, text: 'Open GPay (or PhonePe / Paytm / any UPI app)'),
                        _StepRow(num: 2, text: 'Tap "Scan" or "Scan QR"'),
                        _StepRow(num: 3, text: 'Scan this QR code & pay'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.verified, size: 16, color: AppColors.success),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text('Highest success', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.verified, size: 16, color: AppColors.success),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text('Trust established instantly', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.verified, size: 16, color: AppColors.success),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text('After 1–2 QR payments, UPI may work too', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                QrImageView(
                                  data: _upiDeepLink!,
                                  version: QrVersions.auto,
                                  size: 220,
                                  backgroundColor: Colors.white,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Amount: ₹${_amountController.text}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (_paymentNote != null && _paymentNote!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _paymentNote!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showQrCodeDialog,
                            icon: const Icon(Icons.fullscreen, size: 20),
                            label: const Text('View fullscreen QR'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.success,
                              side: const BorderSide(color: AppColors.success),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openInUpiAppAfterSelection,
                    icon: const Icon(Icons.open_in_new, size: 20),
                    label: const Text('Open in UPI app (select GPay, PhonePe, etc.)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showMarkAsPaidDialog,
                    icon: const Icon(Icons.check_circle_outline, size: 22),
                    label: const Text('I have paid – Enter transaction ID'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
              if (_deepLinkFailed && _payment != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Card(
                    color: AppColors.warning.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'UPI app could not be opened. Use Scan QR above for best results.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Continue button (only show if payment not initiated yet)
              if (_payment == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _initiatePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Pay with Mobile Number',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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

class _StepRow extends StatelessWidget {
  final int num;
  final String text;

  const _StepRow({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$num',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
