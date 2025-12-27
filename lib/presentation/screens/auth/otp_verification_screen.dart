import '../../../core/imports/app_imports.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/user_data.dart';
import '../../../core/constants/app_constants.dart';
import 'dart:convert';
import '../home/home_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../staff/staff_dashboard_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String purpose; // 'registration' or 'login'
  final Map<String, dynamic>? userData; // For registration only
  final String? roleContext; // For role-based routing

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
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

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto-focus first field
    Future.delayed(const Duration(milliseconds: 300), () {
      _focusNodes[0].requestFocus();
    });
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() => _resendTimer--);
        _startResendTimer();
      }
    });
  }

  String _getOTP() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOTP() async {
    final otp = _getOTP();
    
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter complete OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.purpose == 'registration') {
        // Registration flow
        final response = await ApiService.post(
          ApiConstants.verifyOTPRegister,
          {
            'phoneNumber': widget.phoneNumber,
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
          setState(() {
            _errorMessage = response['message'] ?? 'Invalid OTP';
          });
        }
      } else {
        // Login flow
        final response = await ApiService.post(
          ApiConstants.verifyOTPLogin,
          {
            'phoneNumber': widget.phoneNumber,
            'otp': otp,
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
          setState(() {
            _errorMessage = response['message'] ?? 'Invalid OTP';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOTP() async {
    if (_resendTimer > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.post(
        ApiConstants.sendOTP,
        {
          'phoneNumber': widget.phoneNumber,
          'purpose': widget.purpose,
        },
      );

      if (response['success'] == true) {
        setState(() {
          _resendTimer = 60;
          _isResending = false;
        });
        _startResendTimer();
        
        if (mounted) {
          AppMessageHandler.showSuccess(context, 'OTP sent successfully');
        }
      } else {
        if (mounted) {
          AppMessageHandler.handleResponse(context, response);
        }
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to resend OTP';
          _isResending = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isResending = false;
      });
    }
  }

  void _onOTPChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all 6 digits are entered
    if (_getOTP().length == 6) {
      _verifyOTP();
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
              'We sent a 6-digit code to\n${widget.phoneNumber}',
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
            // Change Phone Number
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Change Phone Number',
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
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

