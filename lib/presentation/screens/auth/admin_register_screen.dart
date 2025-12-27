import 'package:apartment_aync_mobile/presentation/screens/auth/admin_login_screen.dart';

import '../../../core/imports/app_imports.dart';
import '../../../core/utils/phone_formatter.dart';
import 'otp_verification_screen.dart';
import 'package:flutter/services.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      HapticFeedback.mediumImpact();
      AppMessageHandler.showError(context, 'Passwords do not match');
      return;
    }

    final phoneNumber = PhoneFormatter.formatForAPI(
      _phoneController.text.trim(),
    );

    if (!PhoneFormatter.isValidIndianPhone(phoneNumber)) {
      HapticFeedback.mediumImpact();
      AppMessageHandler.showError(
        context,
        'Please enter a valid 10-digit Indian phone number',
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final response = await ApiService.post(ApiConstants.sendOTP, {
        'phoneNumber': phoneNumber,
        'purpose': 'admin_registration',
      });

      if (response['success'] == true) {
        if (mounted) {
          HapticFeedback.mediumImpact();
          // Navigate to OTP verification screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OTPVerificationScreen(
                phoneNumber: phoneNumber,
                purpose: 'admin_registration',
                userData: {
                  'fullName': _fullNameController.text.trim(),
                  'email': _emailController.text.trim().isEmpty
                      ? null
                      : _emailController.text.trim(),
                  'password': _passwordController.text,
                  'role': 'admin',
                },
              ),
            ),
          );
        }
      } else {
        HapticFeedback.mediumImpact();
        if (mounted) {
          AppMessageHandler.handleResponse(context, response);
        }
      }
    } catch (e) {
      HapticFeedback.mediumImpact();
      if (mounted) {
        AppMessageHandler.handleError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Sending OTP...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Register as Admin'),
          backgroundColor: AppColors.primary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Admin Registration',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Create your admin account to manage your apartment community',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    final cleaned = PhoneFormatter.formatForAPI(value);
                    if (!PhoneFormatter.isValidIndianPhone(cleaned)) {
                      return 'Please enter a valid 10-digit Indian phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Full Name
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (Optional)',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        );
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(
                          () => _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible,
                        );
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Send OTP Button
                LoadingButton(
                  text: 'Send OTP',
                  isLoading: _isLoading,
                  onPressed: _sendOTP,
                  icon: Icons.send,
                ),
                const SizedBox(height: 16),

                // Login Link
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => AdminLoginScreen()),
                    );
                  },
                  child: const Text('Already have an admin account? Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
