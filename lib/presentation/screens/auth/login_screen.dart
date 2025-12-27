import '../../../core/imports/app_imports.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/phone_formatter.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../staff/staff_dashboard_screen.dart';
import 'user_register_screen.dart';
import 'admin_login_screen.dart';
import 'otp_verification_screen.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController =
      TextEditingController(); // Can be email or phone
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isOTPLogin = false;

  Future<void> _sendOTPForLogin() async {
    print('🖱️ [FLUTTER] Send OTP button clicked');
    final identifier = _identifierController.text.trim();
    print('📱 [FLUTTER] Identifier: $identifier');

    // Check if it's a phone number (10 digits) or email
    final cleanedPhone = PhoneFormatter.formatForAPI(identifier);
    final isPhone = PhoneFormatter.isValidIndianPhone(cleanedPhone);
    print('📱 [FLUTTER] Is Phone: $isPhone');

    if (!isPhone && !identifier.contains('@')) {
      HapticFeedback.mediumImpact();
      AppMessageHandler.showError(
        context,
        'Please enter a valid phone number or email',
      );
      return;
    }

    if (isPhone && !PhoneFormatter.isValidIndianPhone(cleanedPhone)) {
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
      print('📤 [FLUTTER] Sending OTP request...');
      final response = await ApiService.post(ApiConstants.sendOTP, {
        'phoneNumber': isPhone ? cleanedPhone : null,
        'email': !isPhone ? identifier : null,
        'purpose': 'login',
      });

      print('✅ [FLUTTER] OTP response received');
      print('📦 [FLUTTER] Response: ${response.toString()}');

      if (mounted) {
        AppMessageHandler.handleResponse(
          context,
          response,
          onSuccess: () {
            if (isPhone) {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OTPVerificationScreen(
                    phoneNumber: cleanedPhone,
                    purpose: 'login',
                  ),
                ),
              );
            }
          },
        );
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

  Future<void> _handleLogin() async {
    print('🖱️ [FLUTTER] Login button clicked');

    if (!_formKey.currentState!.validate()) {
      print('❌ [FLUTTER] Login form validation failed');
      return;
    }

    final identifier = _identifierController.text.trim();
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post(ApiConstants.passwordLogin, {
        'identifier': identifier,
        'password': _passwordController.text,
      });

      if (response['success'] == true) {
        final token = response['data']?['token'];
        final userData = response['data']?['user'];

        if (token == null) {
          throw Exception('Token missing');
        }

        // Save token
        ApiService.setToken(token);
        await StorageService.setString(AppConstants.tokenKey, token);

        // Save user data
        if (userData is Map<String, dynamic>) {
          await StorageService.setString(
            AppConstants.userKey,
            jsonEncode(userData),
          );
        }

        if (!mounted) return;

        // Optional: socket connect
        final user = UserData.fromJson(userData);
        SocketService().connect(user.id);

        // Send FCM token after successful login
        try {
          await NotificationService.sendPendingToken();
        } catch (e) {
          print('⚠️ Error sending FCM token after login: $e');
        }

        // ✅ DIRECT NAVIGATION TO HOME
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        if (mounted) {
          AppMessageHandler.handleResponse(context, response);
        }
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.handleError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Future<void> _handleLogin() async {
  //   print('🖱️ [FLUTTER] Login button clicked');
  //   if (!_formKey.currentState!.validate()) {
  //     print('❌ [FLUTTER] Login form validation failed');
  //     return;
  //   }

  //   final identifier = _identifierController.text.trim();
  //   print('🔐 [FLUTTER] Login attempt with identifier: $identifier');

  //   setState(() => _isLoading = true);

  //   try {
  //     print('📤 [FLUTTER] Sending login request...');
  //     final response = await ApiService.post(ApiConstants.passwordLogin, {
  //       'identifier': identifier, // Can be email or phone
  //       'password': _passwordController.text,
  //     });

  //     print('✅ [FLUTTER] Login response received');
  //     print('📦 [FLUTTER] Response: ${response.toString()}');

  //     if (response['success'] == true) {
  //       final token = response['data']?['token'];
  //       final userData = response['data']?['user'];

  //       if (token != null) {
  //         ApiService.setToken(token);
  //         await StorageService.setString(AppConstants.tokenKey, token);

  //         // Store user data as JSON string - ensure it's a Map
  //         if (userData != null && userData is Map<String, dynamic>) {
  //           try {
  //             final userJsonString = jsonEncode(userData);
  //             await StorageService.setString(
  //               AppConstants.userKey,
  //               userJsonString,
  //             );
  //           } catch (e) {
  //             if (mounted) {
  //               AppMessageHandler.handleError(
  //                 context,
  //                 'Error saving user data',
  //               );
  //             }
  //           }
  //         }

  //         if (mounted) {
  //           // Navigate based on user role
  //           try {
  //             final user = UserData.fromJson(
  //               userData is Map<String, dynamic> ? userData : {},
  //             );

  //             // Connect to socket for real-time updates
  //             final socketService = SocketService();
  //             socketService.connect(user.id);

  //             // Show success message and navigate
  //             AppMessageHandler.showSuccess(
  //               context,
  //               'Login successful!',
  //               onOkPressed: () {
  //                 // Navigate based on role
  //                 if (user.role == AppConstants.roleAdmin) {
  //                   Navigator.pushAndRemoveUntil(
  //                     context,
  //                     MaterialPageRoute(
  //                       builder: (_) => const AdminDashboardScreen(),
  //                     ),
  //                     (route) => false,
  //                   );
  //                 } else if (user.role == 'staff') {
  //                   Navigator.pushAndRemoveUntil(
  //                     context,
  //                     MaterialPageRoute(
  //                       builder: (_) => const StaffDashboardScreen(),
  //                     ),
  //                     (route) => false,
  //                   );
  //                 } else if (user.role == AppConstants.roleResident) {
  //                   Navigator.pushAndRemoveUntil(
  //                     context,
  //                     MaterialPageRoute(builder: (_) => const HomeScreen()),
  //                     (route) => false,
  //                   );
  //                 }
  //               },
  //             );
  //           } catch (e) {
  //             if (mounted) {
  //               AppMessageHandler.handleError(context, e);
  //             }
  //           }
  //         }
  //       } else {
  //         if (mounted) {
  //           AppMessageHandler.handleResponse(context, response);
  //         }
  //       }
  //     } else {
  //       if (mounted) {
  //         AppMessageHandler.handleResponse(context, response);
  //       }
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       AppMessageHandler.handleError(context, e);
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isLoading = false);
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: _isOTPLogin ? 'Sending OTP...' : 'Signing in...',
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.apartment,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'ApartmentSync',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your Community, Connected',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to continue to your community',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                // Login Form
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            // Email or Phone Number
                            TextFormField(
                              controller: _identifierController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email or Phone Number',
                                hintText: 'Enter email or phone number',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email or phone number';
                                }
                                final isPhone = RegExp(
                                  r'^[6-9]\d{9}$',
                                ).hasMatch(value);
                                final isEmail =
                                    value.contains('@') && value.contains('.');
                                if (!isPhone && !isEmail) {
                                  return 'Please enter a valid email or phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // Password (only show if not OTP login)
                            if (!_isOTPLogin)
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ),
                            const SizedBox(height: 8),
                            // Toggle between Password and OTP Login
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    print(
                                      '🖱️ [FLUTTER] Toggle OTP/Password login clicked',
                                    );
                                    setState(() {
                                      _isOTPLogin = !_isOTPLogin;
                                    });
                                  },
                                  child: Text(
                                    _isOTPLogin ? 'Use Password' : 'Use OTP',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (!_isOTPLogin)
                                  TextButton(
                                    onPressed: () {
                                      // TODO: Implement forgot password
                                    },
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Sign In Button (Password) or Send OTP Button
                            ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _isOTPLogin
                                  ? _sendOTPForLogin
                                  : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.textOnPrimary,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isOTPLogin ? 'Send OTP' : 'Sign In',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.arrow_forward,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 16),
                            // Sign In as Admin
                            OutlinedButton(
                              onPressed: () {
                                print(
                                  '🖱️ [FLUTTER] Admin Login button clicked',
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminLoginScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Sign In as Admin',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Note: Registration is handled by admin only
                            const Center(
                              child: Text(
                                'Contact your building admin for account access',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
