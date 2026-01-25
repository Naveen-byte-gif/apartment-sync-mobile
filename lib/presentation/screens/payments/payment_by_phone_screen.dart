import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/payment_data.dart';
import '../../../data/models/upi_config_data.dart';
import 'payment_confirmation_screen.dart';

class PaymentByPhoneScreen extends StatefulWidget {
  const PaymentByPhoneScreen({super.key});

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
  String? _upiId;
  String? _accountHolderName;
  String? _paymentNote;
  PaymentData? _payment;
  UpiConfigData? _upiConfig;
  bool _deepLinkFailed = false;

  @override
  void initState() {
    super.initState();
    _loadUpiConfig();
    // Auto-fill user's phone number if available
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
          try {
            setState(() {
              _upiConfig = UpiConfigData.fromJson(data);
            });
          } catch (e, stackTrace) {
            print('Error parsing UPI config JSON: $e');
            print('Stack trace: $stackTrace');
          }
        }
      }
    } catch (e, stackTrace) {
      print('Error loading UPI config: $e');
      print('Stack trace: $stackTrace');
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

      final response = await ApiService.post(
        ApiConstants.createPaymentByPhone,
        {
          'phoneNumber': phoneNumber,
          'amount': amount,
          'paymentPurpose': _selectedPurpose,
          'description': _descriptionController.text.trim(),
        },
      );

      if (response['success'] == true) {
        final data = response['data'];
        if (data != null && data is Map<String, dynamic>) {
          try {
            setState(() {
              _upiDeepLink = data['upiDeepLink']?.toString();
              _upiId = data['upiId']?.toString();
              _accountHolderName = data['accountHolderName']?.toString();
              _paymentNote = data['paymentNote']?.toString();
              
              // Safely parse payment data
              if (data['payment'] != null) {
                if (data['payment'] is Map<String, dynamic>) {
                  _payment = PaymentData.fromJson(data['payment'] as Map<String, dynamic>);
                }
              }
            });
          } catch (e, stackTrace) {
            print('Error parsing payment response: $e');
            print('Stack trace: $stackTrace');
            AppMessageHandler.handleError(
              context,
              'Error processing payment response. Please try again.',
            );
            setState(() => _isLoading = false);
            return;
          }
        }

        // Try to launch UPI app with app chooser
        final launched = await _launchUpiAppWithChooser();

        // Always show fallback options after attempting to launch
        if (mounted) {
          setState(() {
            _deepLinkFailed = true;
            // Ensure payment data is preserved
            if (_payment == null && data != null && data is Map<String, dynamic>) {
              try {
                if (data['payment'] != null && data['payment'] is Map<String, dynamic>) {
                  _payment = PaymentData.fromJson(data['payment'] as Map<String, dynamic>);
                }
              } catch (e) {
                print('Error parsing payment in fallback: $e');
              }
            }
          });
          
          // Show helpful message about fallback options
          if (!launched) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('UPI app could not be opened. Please use QR code or manual payment.'),
                    backgroundColor: AppColors.info,
                    duration: const Duration(seconds: 3),
                    action: SnackBarAction(
                      label: 'Show QR',
                      textColor: Colors.white,
                      onPressed: () => _showQrCodeDialog(),
                    ),
                  ),
                );
              }
            });
          }
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

  Future<bool> _launchUpiAppWithChooser() async {
    if (_upiDeepLink == null) return false;

    try {
      final uri = Uri.parse(_upiDeepLink!);
      
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication, // Forces UPI app chooser
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        return launched;
      } else {
        setState(() {
          _deepLinkFailed = true;
        });
        return false;
      }
    } catch (e) {
      print('Error launching UPI app: $e');
      setState(() {
        _deepLinkFailed = true;
      });
      return false;
    }
  }

  void _showQrCodeDialog() {
    if (_upiId == null || _upiConfig == null) return;

    final qrData = _generateQrCodeString();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scan QR Code to Pay',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
                  data: qrData,
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
              const SizedBox(height: 8),
              if (_paymentNote != null)
                Text(
                  _paymentNote!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _copyUpiId();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy UPI ID'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateQrCodeString() {
    if (_upiId == null) return '';
    
    final amount = double.parse(_amountController.text);
    final note = (_paymentNote ?? '').length > 30 
        ? (_paymentNote ?? '').substring(0, 30) 
        : (_paymentNote ?? '');
    
    final encodedUpiId = Uri.encodeComponent(_upiId!);
    final encodedPayeeName = Uri.encodeComponent(_accountHolderName ?? '');
    final encodedNote = Uri.encodeComponent(note);
    
    return 'upi://pay?pa=$encodedUpiId&pn=$encodedPayeeName&am=${amount.toStringAsFixed(2)}&cu=INR&tn=$encodedNote';
  }

  void _copyUpiId() {
    if (_upiId == null) return;
    
    Clipboard.setData(ClipboardData(text: _upiId!));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('UPI ID copied: $_upiId'),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
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
        title: const Text('Pay via UPI'),
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
              
              // Error message if deep link failed
              if (_deepLinkFailed)
                Card(
                  color: AppColors.warning.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.warning),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'UPI payment declined for security reasons. Please use QR code or manual payment.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You can:\n• Scan QR code to pay\n• Copy UPI ID and pay manually\n• Mark as paid after completing payment',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_deepLinkFailed) const SizedBox(height: 16),
              
              // UPI info
              if (_upiId != null)
                Card(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Text(
                              'Pay to',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _accountHolderName ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _upiId ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_paymentNote != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Note: $_paymentNote',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              
              // Fallback options
              if (_deepLinkFailed || _payment != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Alternative Payment Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // QR Code option
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: _upiId != null ? _showQrCodeDialog : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.qr_code, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Scan QR Code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Open any UPI app and scan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Copy UPI ID option
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: _upiId != null ? _copyUpiId : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.copy, color: AppColors.success, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Copy UPI ID',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Copy and paste in your UPI app',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Mark as Paid option
                if (_payment != null)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      onTap: _showMarkAsPaidDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.info.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.check_circle, color: AppColors.info, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mark as Paid',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Enter transaction ID after payment (Invoice will be generated)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              
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
                            'Continue to UPI Payment',
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

