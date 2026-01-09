import '../../../core/imports/app_imports.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/user_data.dart';
import '../../../core/constants/app_constants.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../home/home_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../staff/staff_dashboard_screen.dart';
import 'admin_login_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String email; // Email address for OTP verification
  final String purpose; // 'registration', 'login', 'forgot-password', or 'admin_registration'
  final Map<String, dynamic>? userData; // For registration only
  final String? roleContext; // For role-based routing

  const OTPVerificationScreen({
    super.key,
    required this.email,
    required this.purpose,
    this.userData,
    this.roleContext,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendTimer = 60;
  String? _errorMessage;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto-focus first field
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _startResendTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendTimer > 0) {
          setState(() => _resendTimer--);
        } else {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  String _getOTP() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _clearOTP() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    if (mounted) {
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _getOTP();
    
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter complete 6-digit OTP';
      });
      // Haptic feedback
      HapticFeedback.mediumImpact();
      return;
    }

    // Validate OTP contains only digits
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() {
        _errorMessage = 'OTP must contain only numbers';
      });
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Haptic feedback for verification start
    HapticFeedback.lightImpact();

    try {
      if (widget.purpose == 'registration') {
        // User registration flow
        final response = await ApiService.post(
          ApiConstants.verifyOTPRegister,
          {
            'email': widget.email,
            'otp': otp,
            'userData': widget.userData,
          },
        );

        if (response['success'] == true) {
          final token = response['data']?['token'];
          final userData = response['data']?['user'];

          if (token != null) {
            ApiService.setToken(token);
            await StorageService.setString(AppConstants.tokenKey, token);

            if (userData != null) {
              await StorageService.setString(
                AppConstants.userKey,
                jsonEncode(userData),
              );
            }

            // Send FCM token after successful registration/login
            try {
              await NotificationService.sendPendingToken();
            } catch (e) {
              print('⚠️ Error sending FCM token after registration: $e');
            }

            if (mounted) {
              AppMessageHandler.showSuccess(
                context,
                response['message'] ?? 'Registration successful',
                onOkPressed: () {
                  // Navigate based on status
                  if (userData?['status'] == 'active') {
                    final user = UserData.fromJson(userData);
                    // Connect socket
                    SocketService().connect(user.id);
                    
                    if (user.role == AppConstants.roleAdmin) {
                      // This shouldn't happen for user registration, but handle it
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                        (route) => false,
                      );
                    } else {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    }
                  } else {
                    // Pending approval - go back to login
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  }
                },
              );
            }
          }
        } else {
          // Clear OTP on error
          _clearOTP();
          setState(() {
            _errorMessage = response['message'] ?? 'Invalid OTP. Please try again.';
          });
          HapticFeedback.mediumImpact();
        }
      } else if (widget.purpose == 'admin_registration') {
        // Admin registration flow
        final response = await ApiService.post(
          ApiConstants.adminVerifyOTPRegister,
          {
            'email': widget.email,
            'otp': otp,
            'fullName': widget.userData?['fullName'],
            'password': widget.userData?['password'],
            'phoneNumber': widget.userData?['phoneNumber'], // Optional
          },
        );

        if (response['success'] == true) {
          final token = response['data']?['token'];
          final userData = response['data']?['user'];

          if (token != null) {
            ApiService.setToken(token);
            await StorageService.setString(AppConstants.tokenKey, token);

            if (userData != null) {
              await StorageService.setString(
                AppConstants.userKey,
                jsonEncode(userData),
              );
            }

            // Send FCM token after successful registration
            try {
              await NotificationService.sendPendingToken();
            } catch (e) {
              print('⚠️ Error sending FCM token after admin registration: $e');
            }

            if (mounted) {
              AppMessageHandler.showSuccess(
                context,
                response['message'] ?? 'Admin registration successful. Please login to continue.',
                showDialog: true,
                onOkPressed: () {
                  // Navigate back to admin login screen
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                    (route) => false,
                  );
                },
              );
            }
          }
        } else {
          // Clear OTP on error
          _clearOTP();
          HapticFeedback.mediumImpact();
          
          if (mounted) {
            // Show error as dialog popup
            AppMessageHandler.showError(
              context,
              response['message'] ?? 'Invalid OTP. Please try again.',
              showDialog: true,
            );
          }
          
          setState(() {
            _errorMessage = response['message'] ?? 'Invalid OTP. Please try again.';
          });
        }
      } else {
        // Login flow
        final response = await ApiService.post(
          ApiConstants.verifyOTPLogin,
          {
            'email': widget.email,
            'otp': otp,
          },
        );

        if (response['success'] == true) {
          // Success haptic feedback
          HapticFeedback.heavyImpact();
          final token = response['data']?['token'];
          final userData = response['data']?['user'];

          if (token != null) {
            ApiService.setToken(token);
            await StorageService.setString(AppConstants.tokenKey, token);

            if (userData != null) {
              await StorageService.setString(
                AppConstants.userKey,
                jsonEncode(userData),
              );

              // Send FCM token after successful login
              try {
                await NotificationService.sendPendingToken();
              } catch (e) {
                print('⚠️ Error sending FCM token after login: $e');
              }

              // Connect socket
              final user = UserData.fromJson(userData);
              SocketService().connect(user.id);

              if (mounted) {
                // Verify role matches expected role context if provided
                if (widget.roleContext != null && user.role != widget.roleContext) {
                  AppMessageHandler.showError(
                    context,
                    'Invalid role. Please use the correct login page.',
                  );
                  Navigator.pop(context);
                  return;
                }

                // Navigate based on role
                if (user.role == AppConstants.roleAdmin) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                    (route) => false,
                  );
                } else if (user.role == AppConstants.roleStaff) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const StaffDashboardScreen()),
                    (route) => false,
                  );
                } else {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                }
              }
            }
          }
        } else {
          // Clear OTP on error
          _clearOTP();
          setState(() {
            _errorMessage = response['message'] ?? 'Invalid OTP. Please try again.';
          });
          HapticFeedback.mediumImpact();
        }
      }
    } catch (e) {
      _clearOTP();
      setState(() {
        _errorMessage = AppMessageHandler.getErrorMessage(e) ?? 'An error occurred. Please try again.';
      });
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

  Future<void> _resendOTP() async {
    if (_resendTimer > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    // Haptic feedback
    HapticFeedback.lightImpact();

    try {
      final response = await ApiService.post(
        ApiConstants.sendOTP,
        {
          'email': widget.email,
          'purpose': widget.purpose,
        },
      );

      if (response['success'] == true) {
        // Clear current OTP
        _clearOTP();
        
        setState(() {
          _resendTimer = 60;
          _isResending = false;
        });
        _startResendTimer();
        
        if (mounted) {
          HapticFeedback.mediumImpact();
          AppMessageHandler.showSuccess(
            context,
            'OTP sent successfully to ${widget.email}',
          );
        }
      } else {
        if (mounted) {
          AppMessageHandler.handleResponse(context, response);
        }
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to resend OTP. Please try again.';
          _isResending = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppMessageHandler.getErrorMessage(e) ?? 'Failed to resend OTP. Please try again.';
        _isResending = false;
      });
      HapticFeedback.mediumImpact();
      
      if (mounted) {
        AppMessageHandler.handleError(context, e);
      }
    }
  }

  void _onOTPChanged(int index, String value) {
    // Only allow digits
    if (value.isNotEmpty && !RegExp(r'^\d$').hasMatch(value)) {
      _otpControllers[index].clear();
      return;
    }

    // Clear error message when user starts typing
    if (_errorMessage != null && value.isNotEmpty) {
      setState(() {
        _errorMessage = null;
      });
    }

    // Move to next field
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
      HapticFeedback.selectionClick();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all 6 digits are entered
    if (_getOTP().length == 6) {
      // Small delay to ensure all fields are updated
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _verifyOTP();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sms,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            // Title
            const Text(
              'Enter Verification Code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              'We sent a 6-digit code to\n${widget.email}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // OTP Input Fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 50,
                  height: 60,
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _errorMessage != null
                              ? Colors.red
                              : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _errorMessage != null
                              ? Colors.red
                              : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => _onOTPChanged(index, value),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            // Verify Button
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOTP,
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Verify OTP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            // Resend OTP
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Didn't receive code? ",
                  style: TextStyle(color: Colors.grey),
                ),
                if (_resendTimer > 0)
                  Text(
                    'Resend in ${_resendTimer}s',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  TextButton(
                    onPressed: _isResending ? null : _resendOTP,
                    child: _isResending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Resend OTP',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Change Email
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Change Email',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

