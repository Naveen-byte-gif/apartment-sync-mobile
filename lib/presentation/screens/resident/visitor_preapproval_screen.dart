import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';

class VisitorPreApprovalScreen extends StatefulWidget {
  const VisitorPreApprovalScreen({super.key});

  @override
  State<VisitorPreApprovalScreen> createState() =>
      _VisitorPreApprovalScreenState();
}

class _VisitorPreApprovalScreenState extends State<VisitorPreApprovalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _purposeController = TextEditingController();
  final _expectedCheckOutController = TextEditingController();

  String? _visitorType;
  bool _isPreApproved = true;
  bool _nightTimeAccess = false;
  int _numberOfVisitors = 1;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _purposeController.dispose();
    _expectedCheckOutController.dispose();
    super.dispose();
  }

  Future<void> _createVisitor() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userJson = StorageService.getString(AppConstants.userKey);
      if (userJson == null) {
        AppMessageHandler.showError(context, 'User not found');
        return;
      }

      final userData = jsonDecode(userJson);

      final visitorData = {
        'visitorName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'visitorType': _visitorType ?? 'Guest',
        'purpose': _purposeController.text.trim(),
        'isPreApproved': _isPreApproved,
        'numberOfVisitors': _numberOfVisitors,
        'nightTimeAccess': {
          'allowed': _nightTimeAccess,
          'requiresApproval': true,
        },
        'expectedCheckOutTime': _expectedCheckOutController.text.trim().isEmpty
            ? null
            : _expectedCheckOutController.text.trim(),
        'checkInMethod': _isPreApproved ? 'Pre-Approved' : 'Manual',
      };

      final response = await ApiService.post(
        ApiConstants.visitors,
        visitorData,
      );

      if (response['success'] == true) {
        final visitor = response['data']?['visitor'];
        AppMessageHandler.showSuccess(
          context,
          _isPreApproved
              ? 'Visitor pre-approved successfully'
              : 'Visitor entry created successfully',
        );

        // If pre-approved, show QR/OTP options
        if (_isPreApproved && visitor != null) {
          _showQRAndOTPOptions(visitor['_id']);
        } else {
          Navigator.pop(context, true);
        }
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showQRAndOTPOptions(String visitorId) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Check-In Code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.qr_code, size: 40),
              title: const Text('Generate QR Code'),
              subtitle: const Text('Share QR code for easy check-in'),
              onTap: () async {
                Navigator.pop(context);
                await _generateQRCode(visitorId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.pin, size: 40),
              title: const Text('Generate OTP'),
              subtitle: const Text('Share 6-digit OTP for check-in'),
              onTap: () async {
                Navigator.pop(context);
                await _generateOTP(visitorId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateQRCode(String visitorId) async {
    try {
      final response = await ApiService.post(
        ApiConstants.visitorGenerateQR(visitorId),
        {},
      );

      if (response['success'] == true) {
        final qrCode = response['data']?['qrCode'];
        // Show QR code dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('QR Code Generated'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // TODO: Display QR code image
                Text('QR Code: $qrCode'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Share QR code
                  },
                  child: const Text('Share QR Code'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  Future<void> _generateOTP(String visitorId) async {
    try {
      final response = await ApiService.post(
        ApiConstants.visitorGenerateOTP(visitorId),
        {},
      );

      if (response['success'] == true) {
        final otp = response['data']?['otp'];
        // Show OTP dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('OTP Generated'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  otp ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Share OTP via SMS/WhatsApp
                  },
                  child: const Text('Share OTP'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-approve Visitor'),
        backgroundColor: AppColors.primary,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Visitor Type
              DropdownButtonFormField<String>(
                value: _visitorType,
                decoration: const InputDecoration(
                  labelText: 'Visitor Type *',
                  border: OutlineInputBorder(),
                ),
                items:
                    [
                      'Guest',
                      'Delivery Partner',
                      'Cab Driver',
                      'Service Provider',
                      'Contractor',
                      'Other',
                    ].map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                onChanged: (value) {
                  setState(() => _visitorType = value);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select visitor type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Visitor Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Visitor Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Visitor name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '10-digit phone number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Phone number is required';
                  }
                  if (value.length != 10) {
                    return 'Please enter valid 10-digit phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email (Optional)
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Purpose
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(
                  labelText: 'Purpose of Visit *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Purpose is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Number of Visitors
              Row(
                children: [
                  const Text('Number of Visitors: '),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (_numberOfVisitors > 1) {
                        setState(() => _numberOfVisitors--);
                      }
                    },
                  ),
                  Text(
                    '$_numberOfVisitors',
                    style: const TextStyle(fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_numberOfVisitors < 10) {
                        setState(() => _numberOfVisitors++);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Expected Check-out Time
              TextFormField(
                controller: _expectedCheckOutController,
                decoration: const InputDecoration(
                  labelText: 'Expected Check-out Time',
                  hintText: 'YYYY-MM-DD HH:MM',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Pre-approve Toggle
              SwitchListTile(
                title: const Text('Pre-approve Visitor'),
                subtitle: const Text('Generate QR/OTP for easy check-in'),
                value: _isPreApproved,
                onChanged: (value) {
                  setState(() => _isPreApproved = value);
                },
              ),

              // Night-time Access
              SwitchListTile(
                title: const Text('Allow Night-time Access'),
                subtitle: const Text('Allow access between 10 PM - 6 AM'),
                value: _nightTimeAccess,
                onChanged: (value) {
                  setState(() => _nightTimeAccess = value);
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _createVisitor,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Create Visitor Entry',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
