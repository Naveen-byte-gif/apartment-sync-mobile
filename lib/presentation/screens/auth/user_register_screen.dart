import '../../../core/imports/app_imports.dart';
import '../../../core/utils/phone_formatter.dart';
import 'otp_verification_screen.dart';
import 'package:flutter/services.dart';

class UserRegisterScreen extends StatefulWidget {
  const UserRegisterScreen({super.key});

  @override
  State<UserRegisterScreen> createState() => _UserRegisterScreenState();
}

class _UserRegisterScreenState extends State<UserRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _apartmentCodeController = TextEditingController();
  final _wingController = TextEditingController();
  final _flatNumberController = TextEditingController();
  final _floorNumberController = TextEditingController();
  
  String? _selectedFlatType;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  final List<String> _flatTypes = ['1BHK', '2BHK', '3BHK', '4BHK', 'Duplex', 'Penthouse'];

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    final phoneNumber = PhoneFormatter.formatForAPI(_phoneController.text.trim());
    
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
      final response = await ApiService.post(
        ApiConstants.sendOTP,
        {
          'phoneNumber': phoneNumber,
          'purpose': 'registration',
        },
      );

      if (response['success'] == true) {
        if (mounted) {
          HapticFeedback.mediumImpact();
          // Navigate to OTP verification screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OTPVerificationScreen(
                phoneNumber: phoneNumber,
                purpose: 'registration',
                userData: {
                  'fullName': _fullNameController.text.trim(),
                  'email': _emailController.text.trim().isEmpty 
                      ? null 
                      : _emailController.text.trim(),
                  'password': _passwordController.text,
                  'role': 'resident',
                  'apartmentCode': _apartmentCodeController.text.trim().toUpperCase(),
                  'wing': _wingController.text.trim().toUpperCase(),
                  'flatNumber': _flatNumberController.text.trim().toUpperCase(),
                  'floorNumber': int.tryParse(_floorNumberController.text.trim()) ?? 0,
                  'flatType': _selectedFlatType,
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
        title: const Text('Register as Resident'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create Resident Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fill in your details to register',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              
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
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
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
                      _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
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
              const SizedBox(height: 24),
              
              const Divider(),
              const SizedBox(height: 16),
              
              const Text(
                'Apartment Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Apartment Code
              TextFormField(
                controller: _apartmentCodeController,
                decoration: const InputDecoration(
                  labelText: 'Apartment Code *',
                  prefixIcon: Icon(Icons.apartment),
                  hintText: 'e.g., APT001',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter apartment code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Wing
              TextFormField(
                controller: _wingController,
                decoration: const InputDecoration(
                  labelText: 'Wing *',
                  prefixIcon: Icon(Icons.home),
                  hintText: 'e.g., A, B, C',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter wing';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Flat Number
              TextFormField(
                controller: _flatNumberController,
                decoration: const InputDecoration(
                  labelText: 'Flat Number *',
                  prefixIcon: Icon(Icons.door_front_door),
                  hintText: 'e.g., 402',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter flat number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Floor Number
              TextFormField(
                controller: _floorNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Floor Number *',
                  prefixIcon: Icon(Icons.stairs),
                  hintText: 'e.g., 4',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter floor number';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Flat Type
              DropdownButtonFormField<String>(
                value: _selectedFlatType,
                decoration: const InputDecoration(
                  labelText: 'Flat Type *',
                  prefixIcon: Icon(Icons.home_work),
                ),
                items: _flatTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedFlatType = value);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select flat type';
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Sign In'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

