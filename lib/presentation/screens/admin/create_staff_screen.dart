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
  Set<String> _selectedBuildings = {}; // Set of building codes

  // Permission toggles
  bool _canCreateBuildings = false;
  bool _canEditBuildingDetails = false;
  bool _canChangeFlatStatus = false;
  bool _canAddRemoveResidents = false;
  bool _canLogVisitorEntry = false;
  bool _canViewVisitorHistory = false;
  bool _fullAccess = false;

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
        _fullAccess = true;
        _canCreateBuildings = true;
        _canEditBuildingDetails = true;
        _canChangeFlatStatus = true;
        _canAddRemoveResidents = true;
        _canLogVisitorEntry = true;
        _canViewVisitorHistory = true;
      } else if (role == 'Security') {
        _canLogVisitorEntry = true;
        _canViewVisitorHistory = true;
        _fullAccess = false;
        _canCreateBuildings = false;
        _canEditBuildingDetails = false;
        _canChangeFlatStatus = false;
        _canAddRemoveResidents = false;
      } else if (role == 'Manager') {
        _canChangeFlatStatus = true;
        _canViewVisitorHistory = true;
        _canLogVisitorEntry = true;
        _fullAccess = false;
        _canCreateBuildings = false;
        _canEditBuildingDetails = false;
        _canAddRemoveResidents = false;
      } else if (role == 'Maintenance') {
        _canChangeFlatStatus = false; // Maintenance staff typically don't change flat status
        _canViewVisitorHistory = false;
        _canLogVisitorEntry = false;
        _fullAccess = false;
        _canCreateBuildings = false;
        _canEditBuildingDetails = false;
        _canAddRemoveResidents = false;
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
          'canCreateBuildings': _canCreateBuildings,
          'canEditBuildingDetails': _canEditBuildingDetails,
          'canChangeFlatStatus': _canChangeFlatStatus,
          'canManageResidents': _canAddRemoveResidents,
          'canLogVisitorEntry': _canLogVisitorEntry,
          'canViewVisitorHistory': _canViewVisitorHistory,
          'fullAccess': _fullAccess,
        },
      };

      final response = await ApiService.post('/admin/staff', staffData);

      if (mounted) {
        final statusCode = response['_statusCode'] as int?;
        AppMessageHandler.handleResponse(
          context,
          response,
          statusCode: statusCode,
          showDialog: true,
          onSuccess: () {
            // Show password if auto-generated
            if (_autoGeneratePassword && response['data']?['password'] != null) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Staff Created Successfully'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Staff account has been created.'),
                      const SizedBox(height: 12),
                      const Text(
                        'Generated Password:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          response['data']['password'],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please share this password with the staff member securely.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
              Navigator.pop(context, true);
            }
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
                'Select buildings this staff can access',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoadingBuildings)
                const Center(child: CircularProgressIndicator())
              else if (_allBuildings.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.apartment_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text('No buildings found'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/create-building');
                          },
                          child: const Text('Create Building First'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: _allBuildings.map((building) {
                      final code = building['code'] as String? ?? '';
                      final name = building['name'] as String? ?? code;
                      final isSelected = _selectedBuildings.contains(code);
                      
                      return CheckboxListTile(
                        title: Text(name),
                        subtitle: Text('Code: $code'),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedBuildings.add(code);
                            } else {
                              _selectedBuildings.remove(code);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 24),
              // Permissions Section
              Text(
                'Permissions & Authority',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Control what this staff can access',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Full Access (Admin Staff)'),
                      subtitle: const Text('Grants all permissions'),
                      value: _fullAccess,
                      onChanged: (value) {
                        setState(() {
                          _fullAccess = value;
                          if (value) {
                            // Enable all permissions
                            _canCreateBuildings = true;
                            _canEditBuildingDetails = true;
                            _canChangeFlatStatus = true;
                            _canAddRemoveResidents = true;
                            _canLogVisitorEntry = true;
                            _canViewVisitorHistory = true;
                          }
                        });
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Can Create Building'),
                      value: _canCreateBuildings,
                      onChanged: _fullAccess ? null : (value) {
                        setState(() => _canCreateBuildings = value);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Can Edit Building Details'),
                      value: _canEditBuildingDetails,
                      onChanged: _fullAccess ? null : (value) {
                        setState(() => _canEditBuildingDetails = value);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Can Change Flat Status'),
                      value: _canChangeFlatStatus,
                      onChanged: _fullAccess ? null : (value) {
                        setState(() => _canChangeFlatStatus = value);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Can Add / Remove Residents'),
                      value: _canAddRemoveResidents,
                      onChanged: _fullAccess ? null : (value) {
                        setState(() => _canAddRemoveResidents = value);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Can Log Visitor Entry'),
                      value: _canLogVisitorEntry,
                      onChanged: _fullAccess ? null : (value) {
                        setState(() => _canLogVisitorEntry = value);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Can View Visitor History'),
                      value: _canViewVisitorHistory,
                      onChanged: _fullAccess ? null : (value) {
                        setState(() => _canViewVisitorHistory = value);
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

