import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';
import 'dart:io';

class StaffOnboardingScreen extends StatefulWidget {
  final String? userId; // Existing user ID if onboarding existing staff
  final Map<String, dynamic>? userData;

  const StaffOnboardingScreen({
    super.key,
    this.userId,
    this.userData,
  });

  @override
  State<StaffOnboardingScreen> createState() => _StaffOnboardingScreenState();
}

class _StaffOnboardingScreenState extends State<StaffOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Basic Information
  final _employeeIdController = TextEditingController();
  final _specializationController = TextEditingController();
  List<String> _selectedSpecializations = [];
  List<String> _specializationLevels = [];

  // Identity Verification
  String? _idProofType;
  final _idProofNumberController = TextEditingController();
  File? _idProofDocument;
  final ImagePicker _imagePicker = ImagePicker();

  // Emergency Contact
  final _emergencyNameController = TextEditingController();
  String? _emergencyRelationship;
  final _emergencyPhoneController = TextEditingController();
  final _emergencyAltPhoneController = TextEditingController();
  final _emergencyAddressController = TextEditingController();

  // Shift Availability
  Map<String, Map<String, dynamic>> _shiftSchedule = {};
  String? _currentStatus;

  // Multi-building Assignment
  List<Map<String, dynamic>> _allBuildings = [];
  List<Map<String, dynamic>> _selectedBuildings = [];

  // Permissions
  Map<String, bool> _permissions = {
    'canManageComplaints': true,
    'canManageVisitors': false,
    'canManageMaintenance': true,
    'canAccessReports': false,
    'canManageResidents': false,
    'canCreateBuildings': false,
  };
  List<String> _allowedActions = ['view_complaints', 'update_complaint_status', 'add_work_updates', 'view_buildings'];

  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeShiftSchedule();
    _loadBuildings();
  }

  void _initializeShiftSchedule() {
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    for (var day in days) {
      _shiftSchedule[day] = {
        'available': false,
        'start': '09:00',
        'end': '18:00',
        'shiftType': 'Full Day',
      };
    }
    _currentStatus = 'Available';
  }

  Future<void> _loadBuildings() async {
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
      print('Error loading buildings: $e');
    }
  }

  Future<void> _pickIdProofDocument() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _idProofDocument = File(image.path);
        });
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  Future<String?> _uploadDocument(File file) async {
    try {
      // TODO: Implement file upload to Cloudinary or your storage service
      // For now, return a placeholder
      return 'https://example.com/document.jpg';
    } catch (e) {
      AppMessageHandler.handleError(context, e);
      return null;
    }
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_idProofType == null || _idProofDocument == null) {
      AppMessageHandler.showError(context, 'Please upload ID proof document');
      return;
    }

    if (_selectedBuildings.isEmpty) {
      AppMessageHandler.showError(context, 'Please assign at least one building');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload ID proof document
      final documentUrl = await _uploadDocument(_idProofDocument!);
      if (documentUrl == null) {
        setState(() => _isSubmitting = false);
        return;
      }

      // Prepare onboarding data
      final onboardingData = {
        'userId': widget.userId,
        'employeeId': _employeeIdController.text.trim(),
        'specialization': _selectedSpecializations.asMap().entries.map((e) {
          return {
            'category': e.value,
            'expertiseLevel': _specializationLevels[e.key] ?? 'Intermediate',
          };
        }).toList(),
        'assignedBuildings': _selectedBuildings.map((b) {
          return {
            'buildingCode': b['code'],
            'buildingName': b['name'],
            'isPrimary': b['isPrimary'] ?? false,
          };
        }).toList(),
        'identityVerification': {
          'idProofType': _idProofType,
          'idProofNumber': _idProofNumberController.text.trim(),
          'idProofDocument': {
            'url': documentUrl,
            'publicId': null,
          },
          'verificationStatus': 'Pending',
        },
        'emergencyContact': {
          'name': _emergencyNameController.text.trim(),
          'relationship': _emergencyRelationship,
          'phoneNumber': _emergencyPhoneController.text.trim(),
          'alternatePhoneNumber': _emergencyAltPhoneController.text.trim().isEmpty
              ? null
              : _emergencyAltPhoneController.text.trim(),
          'address': {
            'street': _emergencyAddressController.text.trim(),
          },
        },
        'availability': {
          'schedule': _shiftSchedule,
          'currentStatus': _currentStatus,
        },
        'permissions': {
          ..._permissions,
          'allowedActions': _allowedActions,
        },
      };

      final response = await ApiService.post(
        ApiConstants.adminStaffOnboard,
        onboardingData,
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(context, 'Staff onboarded successfully');
        Navigator.pop(context, true);
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Onboarding'),
        backgroundColor: AppColors.primary,
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 4) {
              setState(() => _currentStep++);
            } else {
              _submitOnboarding();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
          steps: [
            _buildBasicInfoStep(),
            _buildIdentityVerificationStep(),
            _buildEmergencyContactStep(),
            _buildShiftAvailabilityStep(),
            _buildBuildingAssignmentStep(),
            _buildPermissionsStep(),
          ],
        ),
      ),
    );
  }

  Step _buildBasicInfoStep() {
    return Step(
      title: const Text('Basic Information'),
      content: Column(
        children: [
          TextFormField(
            controller: _employeeIdController,
            decoration: const InputDecoration(
              labelText: 'Employee ID *',
              hintText: 'Enter employee ID',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Employee ID is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Specialization selection
          Wrap(
            spacing: 8,
            children: [
              'Electrical',
              'Plumbing',
              'Carpentry',
              'Painting',
              'Cleaning',
              'Security',
              'Elevator',
              'Maintenance',
              'Housekeeping',
              'Gardening',
            ].map((spec) {
              final isSelected = _selectedSpecializations.contains(spec);
              return FilterChip(
                label: Text(spec),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSpecializations.add(spec);
                      _specializationLevels.add('Intermediate');
                    } else {
                      final index = _selectedSpecializations.indexOf(spec);
                      _selectedSpecializations.remove(spec);
                      if (index < _specializationLevels.length) {
                        _specializationLevels.removeAt(index);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Step _buildIdentityVerificationStep() {
    return Step(
      title: const Text('Identity Verification'),
      content: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _idProofType,
            decoration: const InputDecoration(
              labelText: 'ID Proof Type *',
            ),
            items: [
              'Aadhaar',
              'PAN',
              'Driving License',
              'Voter ID',
              'Passport',
              'Other',
            ].map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _idProofType = value);
            },
            validator: (value) {
              if (value == null) {
                return 'Please select ID proof type';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _idProofNumberController,
            decoration: const InputDecoration(
              labelText: 'ID Proof Number *',
              hintText: 'Enter ID proof number',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'ID proof number is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (_idProofDocument != null)
            Image.file(
              _idProofDocument!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ElevatedButton.icon(
            onPressed: _pickIdProofDocument,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload ID Proof Document'),
          ),
        ],
      ),
    );
  }

  Step _buildEmergencyContactStep() {
    return Step(
      title: const Text('Emergency Contact'),
      content: Column(
        children: [
          TextFormField(
            controller: _emergencyNameController,
            decoration: const InputDecoration(
              labelText: 'Contact Name *',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Contact name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _emergencyRelationship,
            decoration: const InputDecoration(
              labelText: 'Relationship *',
            ),
            items: [
              'Spouse',
              'Parent',
              'Sibling',
              'Child',
              'Relative',
              'Friend',
              'Other',
            ].map((rel) {
              return DropdownMenuItem(
                value: rel,
                child: Text(rel),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _emergencyRelationship = value);
            },
            validator: (value) {
              if (value == null) {
                return 'Please select relationship';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emergencyPhoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number *',
              hintText: '10-digit phone number',
            ),
            keyboardType: TextInputType.phone,
            maxLength: 10,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Phone number is required';
              }
              if (value.length != 10) {
                return 'Please enter valid 10-digit phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emergencyAltPhoneController,
            decoration: const InputDecoration(
              labelText: 'Alternate Phone Number',
              hintText: 'Optional',
            ),
            keyboardType: TextInputType.phone,
            maxLength: 10,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emergencyAddressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: 'Street, City, State',
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Step _buildShiftAvailabilityStep() {
    return Step(
      title: const Text('Shift Availability'),
      content: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _currentStatus,
            decoration: const InputDecoration(
              labelText: 'Current Status',
            ),
            items: [
              'Available',
              'Busy',
              'On Break',
              'Offline',
              'On Leave',
            ].map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(status),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _currentStatus = value);
            },
          ),
          const SizedBox(height: 16),
          ..._shiftSchedule.entries.map((entry) {
            return Card(
              child: ExpansionTile(
                title: Text(entry.key.toUpperCase()),
                children: [
                  SwitchListTile(
                    title: const Text('Available'),
                    value: entry.value['available'] as bool,
                    onChanged: (value) {
                      setState(() {
                        _shiftSchedule[entry.key]!['available'] = value;
                      });
                    },
                  ),
                  if (entry.value['available'] as bool) ...[
                    ListTile(
                      title: const Text('Start Time'),
                      trailing: Text(entry.value['start']),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.parse(entry.value['start'].split(':')[0]),
                            minute: int.parse(entry.value['start'].split(':')[1]),
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            _shiftSchedule[entry.key]!['start'] =
                                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('End Time'),
                      trailing: Text(entry.value['end']),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.parse(entry.value['end'].split(':')[0]),
                            minute: int.parse(entry.value['end'].split(':')[1]),
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            _shiftSchedule[entry.key]!['end'] =
                                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: entry.value['shiftType'],
                      decoration: const InputDecoration(
                        labelText: 'Shift Type',
                      ),
                      items: [
                        'Morning',
                        'Afternoon',
                        'Evening',
                        'Night',
                        'Full Day',
                      ].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _shiftSchedule[entry.key]!['shiftType'] = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Step _buildBuildingAssignmentStep() {
    return Step(
      title: const Text('Building Assignment'),
      content: Column(
        children: [
          if (_allBuildings.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No buildings available'),
              ),
            )
          else
            ..._allBuildings.map((building) {
              final isSelected = _selectedBuildings.any(
                (b) => b['code'] == building['code'],
              );
              final isPrimary = _selectedBuildings.any(
                (b) => b['code'] == building['code'] && b['isPrimary'] == true,
              );
              return Card(
                child: CheckboxListTile(
                  title: Text(building['name'] ?? building['code']),
                  subtitle: Text('Code: ${building['code']}'),
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedBuildings.add({
                          ...building,
                          'isPrimary': _selectedBuildings.isEmpty,
                        });
                      } else {
                        _selectedBuildings.removeWhere(
                          (b) => b['code'] == building['code'],
                        );
                        // If removed building was primary, make first remaining primary
                        if (isPrimary && _selectedBuildings.isNotEmpty) {
                          _selectedBuildings[0]['isPrimary'] = true;
                        }
                      }
                    });
                  },
                  secondary: isPrimary
                      ? const Icon(Icons.star, color: Colors.amber)
                      : null,
                ),
              );
            }).toList(),
          if (_selectedBuildings.length > 1)
            ..._selectedBuildings.map((building) {
              return ListTile(
                title: Text(building['name'] ?? building['code']),
                trailing: building['isPrimary'] == true
                    ? const Chip(
                        label: Text('Primary'),
                        backgroundColor: Colors.amber,
                      )
                    : TextButton(
                        onPressed: () {
                          setState(() {
                            for (var b in _selectedBuildings) {
                              b['isPrimary'] = false;
                            }
                            building['isPrimary'] = true;
                          });
                        },
                        child: const Text('Set Primary'),
                      ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Step _buildPermissionsStep() {
    return Step(
      title: const Text('Permissions'),
      content: Column(
        children: [
          SwitchListTile(
            title: const Text('Manage Complaints'),
            value: _permissions['canManageComplaints'] ?? false,
            onChanged: (value) {
              setState(() {
                _permissions['canManageComplaints'] = value;
                if (value) {
                  if (!_allowedActions.contains('view_complaints')) {
                    _allowedActions.add('view_complaints');
                  }
                  if (!_allowedActions.contains('update_complaint_status')) {
                    _allowedActions.add('update_complaint_status');
                  }
                }
              });
            },
          ),
          SwitchListTile(
            title: const Text('Manage Visitors'),
            value: _permissions['canManageVisitors'] ?? false,
            onChanged: (value) {
              setState(() {
                _permissions['canManageVisitors'] = value;
                if (value) {
                  if (!_allowedActions.contains('view_visitors')) {
                    _allowedActions.add('view_visitors');
                  }
                  if (!_allowedActions.contains('check_in_visitor')) {
                    _allowedActions.add('check_in_visitor');
                  }
                  if (!_allowedActions.contains('check_out_visitor')) {
                    _allowedActions.add('check_out_visitor');
                  }
                }
              });
            },
          ),
          SwitchListTile(
            title: const Text('Manage Maintenance'),
            value: _permissions['canManageMaintenance'] ?? false,
            onChanged: (value) {
              setState(() {
                _permissions['canManageMaintenance'] = value;
                if (value) {
                  if (!_allowedActions.contains('view_maintenance')) {
                    _allowedActions.add('view_maintenance');
                  }
                  if (!_allowedActions.contains('update_maintenance')) {
                    _allowedActions.add('update_maintenance');
                  }
                }
              });
            },
          ),
          SwitchListTile(
            title: const Text('Access Reports'),
            value: _permissions['canAccessReports'] ?? false,
            onChanged: (value) {
              setState(() {
                _permissions['canAccessReports'] = value;
                if (value) {
                  if (!_allowedActions.contains('view_reports')) {
                    _allowedActions.add('view_reports');
                  }
                }
              });
            },
          ),
          SwitchListTile(
            title: const Text('Manage Residents'),
            value: _permissions['canManageResidents'] ?? false,
            onChanged: (value) {
              setState(() {
                _permissions['canManageResidents'] = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Create Buildings'),
            subtitle: const Text('Allow staff to create and manage buildings'),
            value: _permissions['canCreateBuildings'] ?? false,
            onChanged: (value) {
              setState(() {
                _permissions['canCreateBuildings'] = value;
                if (value) {
                  if (!_allowedActions.contains('create_building')) {
                    _allowedActions.add('create_building');
                  }
                  if (!_allowedActions.contains('update_building')) {
                    _allowedActions.add('update_building');
                  }
                  if (!_allowedActions.contains('view_buildings')) {
                    _allowedActions.add('view_buildings');
                  }
                } else {
                  _allowedActions.remove('create_building');
                  _allowedActions.remove('update_building');
                }
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _idProofNumberController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyAltPhoneController.dispose();
    _emergencyAddressController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

