import '../../../core/imports/app_imports.dart';
import 'dart:math';

class CreateStaffScreen extends StatefulWidget {
  const CreateStaffScreen({super.key});

  @override
  State<CreateStaffScreen> createState() => _CreateStaffScreenState();
}

class _CreateStaffScreenState extends State<CreateStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedStaffRole;
  String _selectedStatus = 'active';
  bool _autoGeneratePassword = true;
  String? _generatedPassword;
  bool _isLoading = false;
  bool _isLoadingBuildings = true;

  List<Map<String, dynamic>> _allBuildings = [];
  List<String> _selectedBuildings = []; // List to preserve order (first is primary)

  // Permission toggles (matching backend Staff model)
  bool _canManageVisitors = false;
  bool _canManageComplaints = false;
  bool _canManageMaintenance = false;
  bool _canAccessReports = false;
  bool _canManageAccess = false;

  final List<String> _staffRoles = ['Security', 'Manager', 'Maintenance', 'Admin Staff'];
  final List<String> _statusOptions = ['active', 'inactive', 'suspended'];

  @override
  void initState() {
    super.initState();
    _loadBuildings();
    _generatePassword();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random();
    _generatedPassword = String.fromCharCodes(Iterable.generate(
      12,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ));
    return _generatedPassword!;
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
        });
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoadingBuildings = false);
      }
    }
  }

  void _onRoleChanged(String? role) {
    setState(() {
      _selectedStaffRole = role;
      // Auto-set permissions based on role
      if (role == 'Admin Staff') {
        // Full access - can manage everything
        _canManageVisitors = true;
        _canManageComplaints = true;
        _canManageMaintenance = true;
        _canAccessReports = true;
        _canManageAccess = true;
      } else if (role == 'Security') {
        // Security can manage visitors
        _canManageVisitors = true;
        _canManageComplaints = false;
        _canManageMaintenance = false;
        _canAccessReports = false;
        _canManageAccess = false;
      } else if (role == 'Manager') {
        // Manager can manage complaints, visitors, and access
        _canManageVisitors = true;
        _canManageComplaints = true;
        _canManageMaintenance = false;
        _canAccessReports = true;
        _canManageAccess = true;
      } else if (role == 'Maintenance') {
        // Maintenance can manage complaints and maintenance
        _canManageVisitors = false;
        _canManageComplaints = true;
        _canManageMaintenance = true;
        _canAccessReports = false;
        _canManageAccess = false;
      } else {
        // Default: no permissions
        _canManageVisitors = false;
        _canManageComplaints = false;
        _canManageMaintenance = false;
        _canAccessReports = false;
        _canManageAccess = false;
      }
    });
  }

  Future<void> _createStaff() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStaffRole == null) {
      AppMessageHandler.showError(context, 'Please select a staff role');
      return;
    }

    if (_selectedBuildings.isEmpty) {
      AppMessageHandler.showError(context, 'Please assign at least one building');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final password = _autoGeneratePassword ? _generatedPassword! : _passwordController.text;

      final staffData = {
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'email': _emailController.text.trim(),
        'password': password,
        'staffRole': _selectedStaffRole,
        'assignedBuildings': _selectedBuildings.toList(),
        'status': _selectedStatus,
        'autoGeneratePassword': _autoGeneratePassword,
        'permissions': {
          'canManageVisitors': _canManageVisitors,
          'canManageComplaints': _canManageComplaints,
          'canManageMaintenance': _canManageMaintenance,
          'canAccessReports': _canAccessReports,
          'canManageAccess': _canManageAccess,
        },
      };

      // Use the proper staff creation endpoint
      // First create user with staff role, then onboard as staff
      // Backend requires buildingCode, so use first selected building (primary)
      final primaryBuildingCode = _selectedBuildings.isNotEmpty 
          ? _selectedBuildings.first 
          : null;
      
      if (primaryBuildingCode == null) {
        throw Exception('Please select at least one building');
      }

      final userData = {
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'email': _emailController.text.trim(),
        'password': password,
        'role': 'staff',
        'buildingCode': primaryBuildingCode, // Use primary building for user creation
      };

      // Create user first (staff role doesn't require apartmentCode)
      final userResponse = await ApiService.post(
        ApiConstants.adminUsers,
        userData,
      );

      if (userResponse['success'] != true) {
        throw Exception(userResponse['message'] ?? 'Failed to create user');
      }

      final userId = userResponse['data']?['user']?['id'] ?? 
                     userResponse['data']?['user']?['_id'] ??
                     userResponse['data']?['id'];

      if (userId == null) {
        throw Exception('User created but ID not returned');
      }

      // Prepare building assignment data (first in list is primary)
      final buildingAssignments = _selectedBuildings.asMap().entries.map((entry) {
        final index = entry.key;
        final code = entry.value;
        final building = _allBuildings.firstWhere(
          (b) => b['code'] == code,
          orElse: () => {'name': code},
        );
        return {
          'buildingCode': code,
          'buildingName': building['name'] ?? code,
          'isPrimary': index == 0, // First selected is primary
        };
      }).toList();

      // Onboard staff with permissions
      final onboardingData = {
        'userId': userId,
        'employeeId': 'EMP${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'specialization': [],
        'assignedBuildings': buildingAssignments,
        'permissions': {
          'canManageVisitors': _canManageVisitors,
          'canManageComplaints': _canManageComplaints,
          'canManageMaintenance': _canManageMaintenance,
          'canAccessReports': _canAccessReports,
          'canManageAccess': _canManageAccess,
        },
        'availability': {
          'currentStatus': 'Available',
        },
      };

      final response = await ApiService.post(
        ApiConstants.adminStaffOnboard,
        onboardingData,
      );

      if (mounted) {
        if (response['success'] == true) {
          // Show password if auto-generated
          if (_autoGeneratePassword) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Staff Created Successfully'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Staff account has been created and onboarded successfully.'),
                    const SizedBox(height: 16),
                    const Text(
                      'Generated Password:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: SelectableText(
                        _generatedPassword ?? password,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, 
                            color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please share this password with the staff member securely.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ).then((_) => Navigator.pop(context, true));
          } else {
            AppMessageHandler.showSuccess(
              context,
              'Staff created and onboarded successfully',
            );
            Navigator.pop(context, true);
          }
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Staff'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information Section
              Text(
                'Basic Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'Enter full name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: 'Enter 10-digit phone number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (value.length != 10) {
                    return 'Please enter a valid 10-digit phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  hintText: 'Enter email address',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter email address';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStaffRole,
                decoration: const InputDecoration(
                  labelText: 'Staff Role *',
                  prefixIcon: Icon(Icons.work),
                  border: OutlineInputBorder(),
                ),
                items: _staffRoles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: _onRoleChanged,
                validator: (value) {
                  if (value == null) {
                    return 'Please select a staff role';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status *',
                  prefixIcon: Icon(Icons.info),
                  border: OutlineInputBorder(),
                ),
                items: _statusOptions.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedStatus = value!);
                },
              ),
              const SizedBox(height: 24),
              // Password Section
              Text(
                'Account Setup',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Auto-generate Password'),
                subtitle: const Text('Recommended for security'),
                value: _autoGeneratePassword,
                onChanged: (value) {
                  setState(() {
                    _autoGeneratePassword = value;
                    if (value) {
                      _generatePassword();
                    }
                  });
                },
              ),
              if (_autoGeneratePassword)
                Card(
                  color: AppColors.success.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success),
                            const SizedBox(width: 8),
                            Text(
                              'Generated Password',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: Text(
                            _generatedPassword ?? '',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    hintText: 'Enter password (min 8 characters)',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 24),
              // Building Assignment Section
              Text(
                'Building Assignment *',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select buildings this staff can access. First selected building will be primary.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoadingBuildings)
                const Center(child: CircularProgressIndicator())
              else if (_allBuildings.isEmpty)
                Card(
                  color: AppColors.warning.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.apartment_outlined, size: 48, color: AppColors.warning),
                        const SizedBox(height: 8),
                        const Text(
                          'No buildings found',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You need to create at least one building before creating staff.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // Navigate to create building - adjust route as needed
                          },
                          icon: const Icon(Icons.add_business),
                          label: const Text('Create Building First'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: _allBuildings.asMap().entries.map((entry) {
                      final index = entry.key;
                      final building = entry.value;
                      final code = building['code'] as String? ?? '';
                      final name = building['name'] as String? ?? code;
                      final isSelected = _selectedBuildings.contains(code);
                      final isPrimary = isSelected && _selectedBuildings.isNotEmpty && _selectedBuildings.first == code;
                      
                      return CheckboxListTile(
                        title: Row(
                          children: [
                            Expanded(child: Text(name)),
                            if (isPrimary)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Primary',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text('Code: $code'),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              // Add to list (preserves order - first is primary)
                              if (!_selectedBuildings.contains(code)) {
                                _selectedBuildings.add(code);
                              }
                            } else {
                              _selectedBuildings.remove(code);
                            }
                          });
                        },
                        secondary: isPrimary
                            ? Icon(Icons.star, color: AppColors.primary)
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 24),
              // Permissions Section
              Text(
                'Permissions & Access Control',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Control what this staff can access based on assigned buildings',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Manage Visitors'),
                      subtitle: const Text('Can check-in/out visitors and view visitor logs'),
                      value: _canManageVisitors,
                      onChanged: (value) {
                        setState(() => _canManageVisitors = value);
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Manage Complaints'),
                      subtitle: const Text('Can view, assign, and update complaint status'),
                      value: _canManageComplaints,
                      onChanged: (value) {
                        setState(() => _canManageComplaints = value);
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Manage Maintenance'),
                      subtitle: const Text('Can manage maintenance tasks and schedules'),
                      value: _canManageMaintenance,
                      onChanged: (value) {
                        setState(() => _canManageMaintenance = value);
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Access Reports'),
                      subtitle: const Text('Can view analytics and reports'),
                      value: _canAccessReports,
                      onChanged: (value) {
                        setState(() => _canAccessReports = value);
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Manage Users/Residents'),
                      subtitle: const Text('Can create and manage residents for assigned buildings'),
                      value: _canManageAccess,
                      onChanged: (value) {
                        setState(() => _canManageAccess = value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createStaff,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Create Staff',
                          style: TextStyle(fontSize: 16),
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

