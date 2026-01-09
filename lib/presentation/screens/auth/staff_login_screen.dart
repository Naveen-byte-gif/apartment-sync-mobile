import '../../../core/imports/app_imports.dart';
import 'forgot_password_screen.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';
import '../staff/staff_dashboard_screen.dart';
import '../staff/assigned_buildings_screen.dart';
import 'otp_verification_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  final String roleContext;
  
  const StaffLoginScreen({
    super.key,
    required this.roleContext,
  });

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isOTPLogin = false;

  Future<void> _sendOTPForLogin() async {
    final email = _identifierController.text.trim();

    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      AppMessageHandler.showError(
        context,
        'Please enter a valid email address',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post(ApiConstants.sendOTP, {
        'email': email,
        'purpose': 'login',
      });

      if (mounted) {
        AppMessageHandler.handleResponse(
          context,
          response,
          onSuccess: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OTPVerificationScreen(
                  email: email,
                  purpose: 'login',
                  roleContext: widget.roleContext,
                ),
              ),
            );
          },
        );
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

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

        // Verify role matches
        final user = UserData.fromJson(userData);
        if (user.role != widget.roleContext) {
          throw Exception('Invalid role. Please use the correct login page.');
        }

        // Check user status
        if (user.status != 'active') {
          throw Exception('Your account is ${user.status}. Please contact admin.');
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

        // Connect socket
        SocketService().connect(user.id);

        // Send FCM token after successful login
        try {
          await NotificationService.sendPendingToken();
        } catch (e) {
          print('⚠️ Error sending FCM token after login: $e');
        }

        // Navigate to assigned buildings screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AssignedBuildingsScreen()),
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
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.badge,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Staff Login',
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
                        'Access to assigned buildings only',
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
                        'Sign in to manage assigned buildings',
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
                            // Email
                            TextFormField(
                              controller: _identifierController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'Enter your email address',
                                prefixIcon: const Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email address';
                                }
                                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                if (!emailRegex.hasMatch(value)) {
                                  return 'Please enter a valid email address';
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
                                        _isPasswordVisible = !_isPasswordVisible;
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
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ForgotPasswordScreen(),
                                        ),
                                      );
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
                            // Sign In Button
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
                            const Center(
                              child: Text(
                                'Contact admin for account access',
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

