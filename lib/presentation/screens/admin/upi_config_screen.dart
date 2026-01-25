import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/upi_config_data.dart';
import '../../../core/services/api_service.dart';

class UpiConfigScreen extends StatefulWidget {
  const UpiConfigScreen({super.key});

  @override
  State<UpiConfigScreen> createState() => _UpiConfigScreenState();
}

class _UpiConfigScreenState extends State<UpiConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upiIdController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _paymentNoteController = TextEditingController();
  
  UpiConfigData? _currentConfig;
  bool _isEnabled = true;
  bool _isLoading = false;
  bool _isSaving = false;
  File? _qrCodeImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _accountHolderNameController.dispose();
    _bankNameController.dispose();
    _paymentNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get(ApiConstants.upiConfig);
      if (response['success'] == true) {
        final config = UpiConfigData.fromJson(response['data']?['config'] ?? {});
        setState(() {
          _currentConfig = config;
          _upiIdController.text = config.upiId;
          _accountHolderNameController.text = config.accountHolderName;
          _bankNameController.text = config.bankName ?? '';
          _paymentNoteController.text = config.defaultPaymentNoteFormat;
          _isEnabled = config.isEnabled;
          _isLoading = false;
        });
      } else {
        // Config doesn't exist yet, use defaults
        setState(() {
          _paymentNoteController.text = 'Invoice No: {invoiceNumber}, Flat No: {flatNumber}';
          _isLoading = false;
        });
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickQrCodeImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _qrCodeImage = File(image.path);
        });
      }
    } catch (e) {
      AppMessageHandler.handleError(context, 'Failed to pick image');
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Create form data for multipart upload
      final request = {
        'upiId': _upiIdController.text.trim(),
        'accountHolderName': _accountHolderNameController.text.trim(),
        'bankName': _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        'defaultPaymentNoteFormat': _paymentNoteController.text.trim(),
        'isEnabled': _isEnabled,
      };

      // For file upload, we'd need to use multipart/form-data
      // For now, save without QR code if not picked
      final response = await ApiService.post(
        ApiConstants.upiConfig,
        request,
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('UPI configuration saved successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadConfig();
        }
      } else {
        AppMessageHandler.handleError(
          context,
          response['message'] ?? 'Failed to save configuration',
        );
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Configuration'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info card
                    Card(
                      color: AppColors.info.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.info),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Configure UPI payment details for your apartment society. Residents will use this to make payments.',
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
                    // UPI ID
                    TextFormField(
                      controller: _upiIdController,
                      decoration: InputDecoration(
                        labelText: 'Society UPI ID *',
                        hintText: 'society@paytm',
                        prefixIcon: const Icon(Icons.account_balance_wallet),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        helperText: 'Enter the UPI ID where payments will be received',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'UPI ID is required';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid UPI ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Account holder name
                    TextFormField(
                      controller: _accountHolderNameController,
                      decoration: InputDecoration(
                        labelText: 'Account Holder Name *',
                        hintText: 'Greenview Apartments',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Account holder name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Bank name
                    TextFormField(
                      controller: _bankNameController,
                      decoration: InputDecoration(
                        labelText: 'Bank Name (Optional)',
                        hintText: 'State Bank of India',
                        prefixIcon: const Icon(Icons.account_balance),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Payment note format
                    TextFormField(
                      controller: _paymentNoteController,
                      decoration: InputDecoration(
                        labelText: 'Default Payment Note Format',
                        hintText: 'Invoice No: {invoiceNumber}, Flat No: {flatNumber}',
                        prefixIcon: const Icon(Icons.note),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        helperText: 'Use {invoiceNumber} and {flatNumber} as placeholders',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    // QR Code image
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'UPI QR Code (Optional)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_qrCodeImage != null)
                              Image.file(
                                _qrCodeImage!,
                                height: 200,
                                width: 200,
                              )
                            else if (_currentConfig?.qrCodeImage != null)
                              Image.network(
                                _currentConfig!.qrCodeImage!.url,
                                height: 200,
                                width: 200,
                              )
                            else
                              Container(
                                height: 200,
                                width: 200,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Center(
                                  child: Icon(Icons.qr_code, size: 64),
                                ),
                              ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _pickQrCodeImage,
                              icon: const Icon(Icons.upload),
                              label: const Text('Upload QR Code'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Enable/Disable toggle
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        title: const Text('Enable UPI Payments'),
                        subtitle: const Text('Allow residents to make payments via UPI'),
                        value: _isEnabled,
                        onChanged: (value) {
                          setState(() => _isEnabled = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveConfig,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Save Configuration',
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

