import '../../../core/imports/app_imports.dart';
import 'dart:convert';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _scrollController = ScrollController();

  String _selectedRole = 'resident';
  String? _selectedBuildingCode;
  List<Map<String, dynamic>> _allBuildings = [];
  int? _selectedFloor;
  String? _selectedFlatNumber;
  String? _selectedFlatType;
  String _residentType = 'owner'; // 'owner' or 'tenant'
  bool _isPrimaryResident = false;
  bool _obscurePassword = true;

  List<Map<String, dynamic>> _availableFlats = [];
  bool _isLoadingBuildings = false;
  bool _isLoadingFlats = false;
  bool _isCreating = false;
  bool _showOTPVerification = false;
  String? _pendingUserDataJson;
  String? _adminEmail;

  // Password strength tracking
  String _passwordStrength = '';
  Color _passwordStrengthColor = Colors.grey;

  // Validation states
  bool _isPhoneValid = false;
  bool _isEmailValid = false;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
    _passwordController.addListener(_checkPasswordStrength);
    _phoneController.addListener(_validatePhone);
    _emailController.addListener(_validateEmail);
  }

  void _checkPasswordStrength() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = '';
        _passwordStrengthColor = Colors.grey;
      });
      return;
    }

    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    setState(() {
      if (strength <= 2) {
        _passwordStrength = 'Weak';
        _passwordStrengthColor = AppColors.error;
      } else if (strength <= 3) {
        _passwordStrength = 'Fair';
        _passwordStrengthColor = AppColors.warning;
      } else if (strength <= 4) {
        _passwordStrength = 'Good';
        _passwordStrengthColor = AppColors.info;
      } else {
        _passwordStrength = 'Strong';
        _passwordStrengthColor = AppColors.success;
      }
    });
  }

  void _validatePhone() {
    final phone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    setState(() {
      _isPhoneValid =
          phone.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(phone);
    });
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    setState(() {
      _isEmailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
    });
  }

  void _formatPhoneNumber(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length > 10) return;

    final formatted = digitsOnly.length > 0
        ? '${digitsOnly.substring(0, digitsOnly.length > 5 ? 5 : digitsOnly.length)}${digitsOnly.length > 5 ? ' ${digitsOnly.substring(5)}' : ''}'
        : '';

    _phoneController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _loadBuildings() async {
    setState(() => _isLoadingBuildings = true);
    try {
      final response = await ApiService.get(ApiConstants.adminBuildings);
      if (response['success'] == true) {
        setState(() {
          _allBuildings = List<Map<String, dynamic>>.from(
            response['data']?['buildings'] ?? [],
          );
          // Validate stored building code against fetched buildings
          if (_allBuildings.isNotEmpty) {
            final storedCode = StorageService.getString(AppConstants.selectedBuildingKey);
            
            // Check if stored code exists in the fetched buildings
            final isValidCode = storedCode != null && 
                _allBuildings.any((b) => b['code'] == storedCode);
            
            if (isValidCode) {
              _selectedBuildingCode = storedCode;
            } else {
              // Use first building and update storage
              _selectedBuildingCode = _allBuildings.first['code'];
              StorageService.setString(
                AppConstants.selectedBuildingKey,
                _selectedBuildingCode!,
              );
            }
            _loadAvailableFlats();
          }
        });
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading buildings: $e');
      AppMessageHandler.handleError(context, e);
    } finally {
      setState(() => _isLoadingBuildings = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    _passwordController.removeListener(_checkPasswordStrength);
    _phoneController.removeListener(_validatePhone);
    _emailController.removeListener(_validateEmail);
    super.dispose();
  }

  Future<void> _loadAvailableFlats() async {
    if (_selectedBuildingCode == null) {
      setState(() => _availableFlats = []);
      return;
    }

    print('🖱️ [FLUTTER] Loading available flats...');
    setState(() => _isLoadingFlats = true);
    try {
      String flatsUrl = ApiConstants.adminAvailableFlats;
      flatsUrl = ApiConstants.addBuildingCode(flatsUrl, _selectedBuildingCode);
      final response = await ApiService.get(flatsUrl);
      print('✅ [FLUTTER] Available flats response received');
      print('📦 [FLUTTER] Response: ${response.toString()}');

      if (response['success'] == true) {
        final flats = List<Map<String, dynamic>>.from(
          response['data']?['availableFlats'] ?? [],
        );
        print('🏠 [FLUTTER] Found ${flats.length} available flats');
        setState(() {
          _availableFlats = flats;
        });
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading flats: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading flats: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFlats = false);
      }
    }
  }

  Future<void> _createUser() async {
    // Haptic feedback for better UX
    HapticFeedback.mediumImpact();

    if (!_formKey.currentState!.validate()) {
      // Scroll to first error field
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    // Additional validation for residents
    if (_selectedRole == 'resident') {
      if (_selectedFloor == null ||
          _selectedFlatNumber == null ||
          _selectedFlatType == null) {
        AppMessageHandler.showError(
          context,
          'Please select floor, flat number, and flat type for resident',
        );
        // Scroll to flat selection section
        await Future.delayed(const Duration(milliseconds: 100));
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent * 0.6,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        return;
      }
    }

    // Validate building selection
    if (_selectedBuildingCode == null || _selectedBuildingCode!.isEmpty) {
      AppMessageHandler.showError(context, 'Please select a building');
      setState(() => _isCreating = false);
      return;
    }

    // Validate phone number format
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phoneDigits)) {
      AppMessageHandler.showError(
        context,
        'Please enter a valid 10-digit Indian phone number',
      );
      return;
    }

    // Validate email (mandatory)
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppMessageHandler.showError(
        context,
        'Email is required',
      );
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      AppMessageHandler.showError(
        context,
        'Please enter a valid email address',
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final Map<String, dynamic> userData = {
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': phoneDigits, // Send only digits
        'email': email.toLowerCase(), // Email is mandatory
        'password': _passwordController.text,
        'role': _selectedRole,
      };

      if (_selectedRole == 'resident') {
        userData['floorNumber'] = _selectedFloor!;
        userData['flatNumber'] = _selectedFlatNumber!;
        userData['flatType'] = _selectedFlatType!;
        userData['residentType'] = _residentType;
        userData['isPrimaryResident'] = _isPrimaryResident;
      }

      userData['buildingCode'] = _selectedBuildingCode;

      // First step: Request OTP for admin verification
      final otpResponse = await ApiService.post(
        '${ApiConstants.adminUsers}/request-otp',
        userData,
      );

      if (mounted) {
        if (otpResponse['success'] == true) {
          // Get admin email from response
          final adminEmail = otpResponse['data']?['adminEmail'];
          
          // Store user data for account creation after OTP verification
          _pendingUserDataJson = jsonEncode(userData);
          _adminEmail = adminEmail;
          
          setState(() {
            _isCreating = false;
            _showOTPVerification = true;
          });
          
          HapticFeedback.mediumImpact();
          AppMessageHandler.showSuccess(
            context,
            'OTP sent to your email. Please verify to create the account.',
          );
        } else {
          final errorMessage = otpResponse['message'] ?? 'Failed to send OTP';
          AppMessageHandler.showError(context, errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        // Handle network errors gracefully
        final errorMessage = e.toString();
        if (errorMessage.contains('SocketException') ||
            errorMessage.contains('Failed host lookup')) {
          AppMessageHandler.showError(
            context,
            'Network error. Please check your internet connection and try again.',
          );
        } else {
          AppMessageHandler.handleError(context, e);
        }
      }
    } finally {
      if (mounted && !_showOTPVerification) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _onRoleChanged(String? role) {
    print('🖱️ [FLUTTER] Role changed to: ${role ?? 'resident'}');
    setState(() {
      _selectedRole = role ?? 'resident';
      if (_selectedRole != 'resident') {
        _selectedFloor = null;
        _selectedFlatNumber = null;
        _selectedFlatType = null;
      }
    });
  }

  void _onFlatSelected(Map<String, dynamic> flat) {
    print(
      '🖱️ [FLUTTER] Flat selected: Floor ${flat['floorNumber']}, Flat ${flat['flatNumber']}, Type ${flat['flatType']}',
    );
    setState(() {
      _selectedFloor = flat['floorNumber'] as int;
      _selectedFlatNumber = flat['flatNumber'] as String;
      _selectedFlatType = flat['flatType'] as String;
    });
  }

  Future<void> _verifyOTPAndCreateAccount(String otp) async {
    if (_pendingUserDataJson == null) {
      AppMessageHandler.showError(context, 'Session expired. Please try again.');
      setState(() {
        _showOTPVerification = false;
      });
      return;
    }

    setState(() => _isCreating = true);

    try {
      final userData = jsonDecode(_pendingUserDataJson!);
      userData['otp'] = otp;

      final response = await ApiService.post(
        '${ApiConstants.adminUsers}/verify-otp-create',
        userData,
      );

      if (mounted) {
        if (response['success'] == true) {
          HapticFeedback.mediumImpact();
          AppMessageHandler.showSuccess(
            context,
            response['message'] ?? 'User created successfully',
          );
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            Navigator.pop(context, true);
          }
        } else {
          final errorMessage = response['message'] ?? 'Failed to create user';
          AppMessageHandler.showError(context, errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.handleError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showOTPVerification) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Verify OTP',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          elevation: 0,
        ),
        body: _buildOTPVerificationWidget(),
      );
    }

    return LoadingOverlay(
      isLoading: _isCreating,
      message: 'Sending OTP...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Create New User',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          elevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              // Progress indicator
              Container(
                width: double.infinity,
                height: 4,
                color: AppColors.background,
                child:
                    _selectedRole == 'resident' &&
                        _selectedFloor != null &&
                        _selectedFlatNumber != null
                    ? LinearProgressIndicator(
                        value: 1.0,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.success,
                        ),
                      )
                    : LinearProgressIndicator(
                        value: 0.5,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Section
                      _buildHeaderSection(),
                      const SizedBox(height: 24),

                      // Role Selection
                      _buildRoleSelectionCard(),
                      const SizedBox(height: 20),
                      // Building Selection
                      if (_allBuildings.length > 1) ...[
                        _buildBuildingSelectionCard(),
                        const SizedBox(height: 20),
                      ],
                      // User Information Section
                      _buildUserInformationCard(),
                      const SizedBox(height: 20),
                      // Flat Selection (only for residents)
                      if (_selectedRole == 'resident') ...[
                        _buildFlatSelectionCard(),
                        const SizedBox(height: 20),
                      ],

                      // Submit Button
                      _buildSubmitButton(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.person_add_alt_1,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create ${_selectedRole == 'resident' ? 'Resident' : 'Staff'} Account',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fill in the details to create a new user account',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'User Type *',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'resident',
                  label: Text('Resident'),
                  icon: Icon(Icons.person),
                ),
                ButtonSegment(
                  value: 'staff',
                  label: Text('Staff'),
                  icon: Icon(Icons.work),
                ),
              ],
              selected: {_selectedRole},
              onSelectionChanged: (Set<String> newSelection) {
                HapticFeedback.lightImpact();
                _onRoleChanged(newSelection.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingSelectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.apartment, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Select Building *',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingBuildings)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedBuildingCode,
                decoration: InputDecoration(
                  labelText: 'Building',
                  hintText: 'Select a building',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                items: _allBuildings.map((building) {
                  return DropdownMenuItem<String>(
                    value: building['code'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          building['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          building['code'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBuildingCode = value;
                    _selectedFloor = null;
                    _selectedFlatNumber = null;
                    _selectedFlatType = null;
                    _availableFlats = [];
                  });
                  if (value != null && _selectedRole == 'resident') {
                    _loadAvailableFlats();
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a building';
                  }
                  return null;
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInformationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'User Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Full Name
            TextFormField(
              controller: _fullNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                hintText: 'Enter full name',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter full name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone Number
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                hintText: '10-digit mobile number',
                prefixIcon: const Icon(Icons.phone_outlined),
                suffixIcon: _isPhoneValid
                    ? Icon(Icons.check_circle, color: AppColors.success)
                    : _phoneController.text.isNotEmpty
                    ? Icon(Icons.error, color: AppColors.error)
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                if (digits.length != 10) {
                  return 'Phone number must be 10 digits';
                }
                if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                  return 'Please enter a valid Indian mobile number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email (Mandatory)
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Email *',
                hintText: 'example@email.com',
                prefixIcon: const Icon(Icons.email_outlined),
                suffixIcon: _emailController.text.isNotEmpty
                    ? (_isEmailValid
                          ? Icon(Icons.check_circle, color: AppColors.success)
                          : Icon(Icons.error, color: AppColors.error))
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Password *',
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),

            // Password Strength Indicator
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _passwordStrength == 'Weak'
                          ? 0.25
                          : _passwordStrength == 'Fair'
                          ? 0.5
                          : _passwordStrength == 'Good'
                          ? 0.75
                          : 1.0,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _passwordStrengthColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _passwordStrength,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _passwordStrengthColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlatSelectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home_outlined, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Select Flat *',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh available flats',
                  onPressed: _selectedBuildingCode != null
                      ? () {
                          HapticFeedback.lightImpact();
                          _loadAvailableFlats();
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedBuildingCode == null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please select a building first',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )
            else if (_isLoadingFlats)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_availableFlats.isEmpty)
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.home_outlined, size: 56, color: AppColors.info),
                    const SizedBox(height: 12),
                    const Text(
                      'No Available Flats',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All flats in this building are currently occupied',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              // Group flats by floor
              ..._buildFlatSelectionGrid(),
              // Selected flat details
              if (_selectedFloor != null && _selectedFlatNumber != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success.withOpacity(0.1),
                        AppColors.success.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Flat',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Floor $_selectedFloor • Flat $_selectedFlatNumber • $_selectedFlatType',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Resident Type Selection
                DropdownButtonFormField<String>(
                  value: _residentType,
                  decoration: InputDecoration(
                    labelText: 'Resident Type *',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    helperText: 'Select whether owner or tenant',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'owner',
                      child: Row(
                        children: [
                          Icon(Icons.home, size: 20),
                          SizedBox(width: 8),
                          Text('Owner'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'tenant',
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 20),
                          SizedBox(width: 8),
                          Text('Tenant'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _residentType = value ?? 'owner';
                    });
                  },
                ),

                const SizedBox(height: 16),

                // Primary Resident Checkbox
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                    ),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Primary Resident',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: const Text(
                      'Head of family - main contact person for this flat',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _isPrimaryResident,
                    onChanged: (value) {
                      setState(() => _isPrimaryResident = value);
                    },
                    secondary: Icon(
                      Icons.person_pin,
                      color: _isPrimaryResident
                          ? AppColors.warning
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFlatSelectionGrid() {
    // Group flats by floor
    final Map<int, List<Map<String, dynamic>>> floorsMap = {};
    for (var flat in _availableFlats) {
      final floor = flat['floorNumber'] as int;
      floorsMap.putIfAbsent(floor, () => []).add(flat);
    }

    final floors = floorsMap.keys.toList()..sort();

    return floors.map((floor) {
      final flats = floorsMap[floor]!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Text(
              'Floor $floor',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: flats.map((flat) {
              final isSelected =
                  _selectedFloor == flat['floorNumber'] &&
                  _selectedFlatNumber == flat['flatNumber'];
              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _onFlatSelected(flat);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Flat ${flat['flatNumber']}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.textOnPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        flat['flatType'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? AppColors.textOnPrimary.withOpacity(0.9)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }

  Widget _buildOTPVerificationWidget() {
    final List<TextEditingController> otpControllers =
        List.generate(6, (_) => TextEditingController());
    final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verify Your Email',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a 6-digit OTP to',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_adminEmail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _adminEmail!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 45,
                        height: 55,
                        child: TextField(
                          controller: otpControllers[index],
                          focusNode: focusNodes[index],
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
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              focusNodes[index + 1].requestFocus();
                            }
                            if (value.isEmpty && index > 0) {
                              focusNodes[index - 1].requestFocus();
                            }
                            // Auto-submit when all fields are filled
                            if (index == 5 &&
                                value.isNotEmpty &&
                                otpControllers.every(
                                  (ctrl) => ctrl.text.isNotEmpty,
                                )) {
                              final otp = otpControllers
                                  .map((c) => c.text)
                                  .join();
                              _verifyOTPAndCreateAccount(otp);
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isCreating
                        ? null
                        : () {
                            final otp = otpControllers
                                .map((c) => c.text)
                                .join();
                            if (otp.length == 6) {
                              _verifyOTPAndCreateAccount(otp);
                            } else {
                              AppMessageHandler.showError(
                                context,
                                'Please enter complete 6-digit OTP',
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Verify & Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isCreating
                        ? null
                        : () {
                            setState(() {
                              _showOTPVerification = false;
                              _pendingUserDataJson = null;
                              _adminEmail = null;
                            });
                          },
                    child: const Text('Back to Form'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isFormValid =
        _fullNameController.text.trim().isNotEmpty &&
        _phoneController.text.length == 10 &&
        _emailController.text.trim().isNotEmpty &&
        _isEmailValid &&
        _passwordController.text.isNotEmpty &&
        (_selectedRole != 'resident' ||
            (_selectedFloor != null && _selectedFlatNumber != null));

    return LoadingButton(
      text:
          'Create ${_selectedRole == 'resident' ? 'Resident' : 'Staff'} Account',
      isLoading: _isCreating,
      onPressed: isFormValid ? _createUser : null,
      icon: Icons.person_add,
      backgroundColor: isFormValid ? AppColors.primary : AppColors.border,
    );
  }
}
