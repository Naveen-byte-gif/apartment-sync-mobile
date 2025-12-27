import '../../../core/imports/app_imports.dart';
import 'admin_dashboard_screen.dart';

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

  String _selectedRole = 'resident';
  String? _selectedBuildingCode;
  List<Map<String, dynamic>> _allBuildings = [];
  int? _selectedFloor;
  String? _selectedFlatNumber;
  String? _selectedFlatType;
  String _residentType = 'owner'; // 'owner' or 'tenant'
  bool _isPrimaryResident = false;

  List<Map<String, dynamic>> _availableFlats = [];
  bool _isLoadingBuildings = false;
  bool _isLoadingFlats = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
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
          // Set default building
          if (_allBuildings.isNotEmpty) {
            _selectedBuildingCode =
                StorageService.getString(AppConstants.selectedBuildingKey) ??
                _allBuildings.first['code'];
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
    print('🖱️ [FLUTTER] Create User button clicked');
    print('👤 [FLUTTER] Selected Role: $_selectedRole');

    if (!_formKey.currentState!.validate()) {
      print('❌ [FLUTTER] Form validation failed');
      return;
    }

    if (_selectedRole == 'resident') {
      if (_selectedFloor == null || _selectedFlatNumber == null) {
        AppMessageHandler.showError(
          context,
          'Please select floor and flat for resident',
        );
        return;
      }
      print(
        '🏠 [FLUTTER] Selected Flat: Floor $_selectedFloor, Flat $_selectedFlatNumber, Type $_selectedFlatType',
      );
    }

    print('📋 [FLUTTER] User Data:');
    print('  - Name: ${_fullNameController.text}');
    print('  - Phone: ${_phoneController.text}');
    print('  - Email: ${_emailController.text}');
    print('  - Role: $_selectedRole');

    setState(() => _isCreating = true);

    try {
      final Map<String, dynamic> userData = {
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'password': _passwordController.text,
        'role': _selectedRole,
      };

      if (_selectedRole == 'resident') {
        // Convert int? to int, backend expects number
        if (_selectedFloor != null) {
          userData['floorNumber'] = _selectedFloor!;
        }
        userData['flatNumber'] = _selectedFlatNumber;
        userData['flatType'] = _selectedFlatType;
        userData['residentType'] = _residentType;
        userData['isPrimaryResident'] = _isPrimaryResident;
        print('🏠 [FLUTTER] Adding flat details to userData:');
        print(
          '  - floorNumber: ${userData['floorNumber']} (type: ${userData['floorNumber'].runtimeType})',
        );
        print('  - flatNumber: ${userData['flatNumber']}');
        print('  - flatType: ${userData['flatType']}');
        print('  - residentType: ${userData['residentType']}');
        print('  - isPrimaryResident: ${userData['isPrimaryResident']}');
      }

      // Add building code to request
      if (_selectedBuildingCode != null) {
        userData['buildingCode'] = _selectedBuildingCode;
      } else {
        AppMessageHandler.showError(context, 'Please select a building');
        setState(() => _isCreating = false);
        return;
      }

      print('📤 [FLUTTER] Sending user creation request...');
      final response = await ApiService.post(ApiConstants.adminUsers, userData);

      print('✅ [FLUTTER] User creation response received');
      print('📦 [FLUTTER] Response: ${response.toString()}');

      if (mounted) {
        AppMessageHandler.handleResponse(
          context,
          response,
          onSuccess: () {
            Navigator.pop(context);
          },
        );
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

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isCreating,
      message: 'Creating user...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create User'),
          backgroundColor: AppColors.primary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Role Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'User Type *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                            _onRoleChanged(newSelection.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Building Selection (if multiple buildings)
                if (_allBuildings.length > 1)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.apartment, color: AppColors.primary),
                              const SizedBox(width: 8),
                              const Text(
                                'Select Building *',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedBuildingCode,
                            decoration: InputDecoration(
                              labelText: 'Building',
                              prefixIcon: const Icon(Icons.business),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: AppColors.surface,
                            ),
                            items: _allBuildings.map((building) {
                              return DropdownMenuItem<String>(
                                value: building['code'],
                                child: SizedBox(
                                  height: 50,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        building['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        building['code'] ?? '',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
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
                              if (value != null &&
                                  _selectedRole == 'resident') {
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
                  ),
                if (_allBuildings.length > 1) const SizedBox(height: 16),
                // User Information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'User Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter phone number';
                            }
                            if (value.length != 10) {
                              return 'Please enter valid 10-digit phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter password';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Flat Selection (only for residents)
                if (_selectedRole == 'resident') ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Select Flat *',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () {
                                  print(
                                    '🖱️ [FLUTTER] Refresh available flats button clicked',
                                  );
                                  _loadAvailableFlats();
                                },
                              ),
                            ],
                          ),
                          if (_selectedBuildingCode == null)
                            const SizedBox.shrink()
                          else if (_isLoadingFlats)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_availableFlats.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: AppColors.info.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.home_outlined,
                                    size: 48,
                                    color: AppColors.info,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No Available Flats',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'All flats in this building are occupied',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableFlats.map((flat) {
                                final isSelected =
                                    _selectedFloor == flat['floorNumber'] &&
                                    _selectedFlatNumber == flat['flatNumber'];
                                return FilterChip(
                                  label: Text(
                                    'Floor ${flat['floorNumber']} - ${flat['flatNumber']}\n'
                                    '${flat['flatType']}',
                                    textAlign: TextAlign.center,
                                  ),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      _onFlatSelected(flat);
                                    }
                                  },
                                  selectedColor: AppColors.primary.withOpacity(
                                    0.2,
                                  ),
                                  checkmarkColor: AppColors.primary,
                                );
                              }).toList(),
                            ),
                            if (_selectedFloor != null &&
                                _selectedFlatNumber != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.success.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Selected: Floor $_selectedFloor, Flat $_selectedFlatNumber ($_selectedFlatType)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppColors.success,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Resident Type Selection
                              DropdownButtonFormField<String>(
                                value: _residentType,
                                decoration: const InputDecoration(
                                  labelText: 'Resident Type *',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                  helperText: 'Owner or Tenant',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'owner',
                                    child: Text('Owner'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'tenant',
                                    child: Text('Tenant'),
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
                              Card(
                                color: AppColors.warning.withOpacity(0.1),
                                child: SwitchListTile(
                                  title: const Text(
                                    'Primary Resident (Head of Family)',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: const Text(
                                    'Only one primary resident per flat. This person is the main contact.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  value: _isPrimaryResident,
                                  onChanged: (value) {
                                    setState(() {
                                      _isPrimaryResident = value;
                                    });
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
                  ),
                ],
                const SizedBox(height: 24),
                LoadingButton(
                  text: 'Create User',
                  isLoading: _isCreating,
                  onPressed: _createUser,
                  icon: Icons.person_add,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
