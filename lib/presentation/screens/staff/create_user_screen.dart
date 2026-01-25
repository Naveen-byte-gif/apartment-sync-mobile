import '../../../core/imports/app_imports.dart';
import 'dart:convert';
import '../../../core/constants/api_constants.dart';

class StaffCreateUserScreen extends StatefulWidget {
  const StaffCreateUserScreen({super.key});

  @override
  State<StaffCreateUserScreen> createState() => _StaffCreateUserScreenState();
}

class _StaffCreateUserScreenState extends State<StaffCreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _scrollController = ScrollController();

  String? _selectedBuildingCode;
  List<Map<String, dynamic>> _assignedBuildings = [];
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

  // Password strength tracking
  String _passwordStrength = '';
  Color _passwordStrengthColor = Colors.grey;

  // Validation states
  bool _isPhoneValid = false;
  bool _isEmailValid = false;

  @override
  void initState() {
    super.initState();
    _loadAssignedBuildings();
    _passwordController.addListener(_checkPasswordStrength);
    _phoneController.addListener(_validatePhone);
    _emailController.addListener(_validateEmail);
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

  Future<void> _loadAssignedBuildings() async {
    setState(() => _isLoadingBuildings = true);
    try {
      final response = await ApiService.get(ApiConstants.staffBuildings);
      if (response['success'] == true) {
        setState(() {
          _assignedBuildings = List<Map<String, dynamic>>.from(
            response['data']?['buildings'] ?? [],
          );
          
          // Auto-select primary building or first building
          if (_assignedBuildings.isNotEmpty) {
            final primaryBuilding = _assignedBuildings.firstWhere(
              (b) => b['isPrimary'] == true,
              orElse: () => _assignedBuildings.first,
            );
            _selectedBuildingCode = primaryBuilding['code'];
            _loadAvailableFlats();
          }
        });
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading assigned buildings: $e');
      if (mounted) {
        AppMessageHandler.handleError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingBuildings = false);
      }
    }
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
      
      if (response['success'] == true) {
        final flats = List<Map<String, dynamic>>.from(
          response['data']?['availableFlats'] ?? response['data']?['flats'] ?? [],
        );
        print('🏠 [FLUTTER] Found ${flats.length} available flats');
        setState(() {
          _availableFlats = flats;
        });
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading flats: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingFlats = false);
      }
    }
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

  Future<void> _createUser() async {
    HapticFeedback.mediumImpact();

    if (!_formKey.currentState!.validate()) {
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (_selectedFloor == null || _selectedFlatNumber == null || _selectedFlatType == null) {
      AppMessageHandler.showError(
        context,
        'Please select floor, flat number, and flat type',
      );
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent * 0.6,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (_selectedBuildingCode == null || _selectedBuildingCode!.isEmpty) {
      AppMessageHandler.showError(context, 'Please select a building');
      return;
    }

    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phoneDigits)) {
      AppMessageHandler.showError(
        context,
        'Please enter a valid 10-digit Indian phone number',
      );
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppMessageHandler.showError(context, 'Email is required');
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      AppMessageHandler.showError(context, 'Please enter a valid email address');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
      final email = _emailController.text.trim();
      
      final userData = {
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': phoneDigits,
        'email': email.toLowerCase(),
        'password': _passwordController.text,
        'role': 'resident',
        'buildingCode': _selectedBuildingCode,
        'floorNumber': _selectedFloor,
        'flatNumber': _selectedFlatNumber,
        'flatType': _selectedFlatType,
        'residentType': _residentType,
        'isPrimaryResident': _isPrimaryResident,
      };

      final response = await ApiService.post(ApiConstants.staffUsers, userData);

      if (mounted) {
        if (response['success'] == true) {
          AppMessageHandler.showSuccess(
            context,
            'Resident created successfully',
          );
          Navigator.pop(context, true);
        } else {
          AppMessageHandler.handleResponse(context, response);
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
    if (_isLoadingBuildings) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create Resident'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_assignedBuildings.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create Resident'),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.business_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No buildings assigned',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please contact admin to assign buildings',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return LoadingOverlay(
      isLoading: _isCreating,
      message: 'Creating resident...',
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
                child: _selectedFloor != null &&
                        _selectedFlatNumber != null &&
                        _selectedBuildingCode != null
                    ? LinearProgressIndicator(
                        value: 1.0,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.success,
                        ),
                      )
                    : _selectedBuildingCode != null
                    ? LinearProgressIndicator(
                        value: 0.7,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.info,
                        ),
                      )
                    : LinearProgressIndicator(
                        value: 0.3,
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
                      _buildBuildingSelectionCard(),
                      const SizedBox(height: 20),
                      // User Information Section
                      _buildUserInformationCard(),
                      const SizedBox(height: 20),
                      // Flat Selection
                      _buildFlatSelectionCard(),
                      const SizedBox(height: 20),

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
                  'Create Resident Account',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fill in the details to create a new resident account',
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.home, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Creating Resident Account',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Add a new resident to the apartment',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Resident',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.apartment, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Building *',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Choose from your assigned buildings',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_assignedBuildings.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No buildings assigned. Please contact admin.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedBuildingCode,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Building Name',
                    hintText: _selectedBuildingCode == null
                        ? (_assignedBuildings.length == 1 && _assignedBuildings.isNotEmpty
                            ? _assignedBuildings.first['name'] ?? 'Select building'
                            : 'Choose a building')
                        : null,
                    prefixIcon: const Icon(Icons.business, color: AppColors.primary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  dropdownColor: Colors.white,
                  icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                  items: _assignedBuildings.map((building) {
                    final isSelected = _selectedBuildingCode == building['code'];
                    return DropdownMenuItem<String>(
                      value: building['code'],
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (building['isPrimary'] == true)
                              Icon(Icons.star, size: 16, color: AppColors.warning),
                            if (building['isPrimary'] == true)
                              const SizedBox(width: 8),
                            Icon(
                              Icons.apartment,
                              size: 16,
                              color: isSelected 
                                  ? AppColors.primary 
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected 
                                        ? AppColors.primary 
                                        : AppColors.textPrimary,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: building['name'] ?? 'Unknown Building',
                                    ),
                                    TextSpan(
                                      text: ' (${building['code'] ?? 'N/A'})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.normal,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedBuildingCode = value;
                      _selectedFloor = null;
                      _selectedFlatNumber = null;
                      _selectedFlatType = null;
                      _availableFlats = [];
                    });
                    if (value != null) {
                      StorageService.setString(
                        AppConstants.selectedBuildingKey,
                        value,
                      );
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

  Widget _buildSubmitButton() {
    final isFormValid =
        _fullNameController.text.trim().isNotEmpty &&
        _phoneController.text.length == 10 &&
        _isPhoneValid &&
        _emailController.text.trim().isNotEmpty &&
        _isEmailValid &&
        _passwordController.text.isNotEmpty &&
        _selectedBuildingCode != null &&
        _selectedFloor != null &&
        _selectedFlatNumber != null &&
        _selectedFlatType != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isFormValid
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: LoadingButton(
        text: 'Create Resident Account',
        isLoading: _isCreating,
        onPressed: isFormValid ? _createUser : null,
        icon: Icons.person_add_alt_1,
        backgroundColor: isFormValid ? AppColors.primary : AppColors.border,
      ),
    );
  }
}

