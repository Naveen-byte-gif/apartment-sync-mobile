import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';
import 'dart:io';

class NewVisitorEntryScreen extends StatefulWidget {
  const NewVisitorEntryScreen({super.key});

  @override
  State<NewVisitorEntryScreen> createState() => _NewVisitorEntryScreenState();
}

class _NewVisitorEntryScreenState extends State<NewVisitorEntryScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  // Step 1: Visitor Details
  File? _visitorPhoto;
  final _visitorNameController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedVisitorType;

  // Step 2: Location
  String? _selectedBuilding;
  int? _selectedFloor;
  String? _selectedFlatNumber;
  final _purposeController = TextEditingController();

  // Step 3: Additional Info
  final _vehicleNumberController = TextEditingController();
  bool _carryingMaterial = false;
  int _numberOfVisitors = 1;
  DateTime? _expectedCheckOutTime;

  // User data
  Map<String, dynamic>? _user;
  List<String> _buildings = [];
  List<Map<String, dynamic>> _floors = [];
  List<Map<String, dynamic>> _flats = [];
  bool _isLoading = false;
  bool _isLoadingBuildingData = false;

  final List<Map<String, String>> _visitorTypes = [
    {'value': 'Guest', 'label': 'Guest', 'icon': '👤'},
    {'value': 'Delivery', 'label': 'Delivery', 'icon': '📦'},
    {'value': 'Vendor', 'label': 'Vendor', 'icon': '🔧'},
    {'value': 'Cab / Ride', 'label': 'Cab / Ride', 'icon': '🚗'},
    {'value': 'Domestic Help', 'label': 'Domestic Help', 'icon': '🏠'},
    {'value': 'Realtor / Sales', 'label': 'Realtor / Sales', 'icon': '🏢'},
    {
      'value': 'Emergency Services',
      'label': 'Emergency Services',
      'icon': '🚨',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadBuildings();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          socketService.connect(userId);

          // Remove old listeners to prevent duplicates
          socketService.off('visitor_created');

          socketService.on('visitor_created', (data) {
            print('🔔 [SOCKET] Visitor created event received');
            // Visitor created successfully, can show confirmation
          });
        }
      } catch (e) {
        print('Error setting up socket: $e');
      }
    }
  }

  @override
  void dispose() {
    _visitorNameController.dispose();
    _mobileNumberController.dispose();
    _emailController.dispose();
    _purposeController.dispose();
    _vehicleNumberController.dispose();
    _pageController.dispose();
    // Clean up socket listeners
    final socketService = SocketService();
    socketService.off('visitor_created');
    super.dispose();
  }

  void _loadUserData() {
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        setState(() {
          _user = jsonDecode(userJson);
          // Auto-set building from user data if available
          if (_user?['wing'] != null) {
            _selectedBuilding = _user!['wing'];
            _loadFloorsAndFlats();
          }
        });
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }
  }

  Future<void> _loadBuildings() async {
    try {
      final userRole = _user?['role'] ?? 'staff';

      if (userRole == 'admin') {
        final response = await ApiService.get(ApiConstants.adminBuildings);
        if (response['success'] == true) {
          final buildings = List<Map<String, dynamic>>.from(
            response['data']?['buildings'] ?? [],
          );
          setState(() {
            _buildings = buildings
                .map((b) => (b['code'] ?? b['name'] ?? '').toString())
                .where((b) => b.isNotEmpty)
                .toList()
                .cast<String>();
          });
        }
      } else {
        // For staff, get building from user data
        if (_user?['apartmentCode'] != null) {
          final wing = (_user?['wing'] ?? 'Block A').toString();
          setState(() {
            _buildings = [wing];
            _selectedBuilding = wing;
          });
          _loadFloorsAndFlats();
        }
      }
    } catch (e) {
      print('Error loading buildings: $e');
    }
  }

  Future<void> _loadFloorsAndFlats() async {
    if (_selectedBuilding == null) return;

    setState(() => _isLoadingBuildingData = true);

    try {
      final userRole = _user?['role'] ?? 'staff';
      String endpoint;

      if (userRole == 'admin') {
        // Find building code from building name
        final buildingsResponse = await ApiService.get(
          ApiConstants.adminBuildings,
        );
        if (buildingsResponse['success'] == true) {
          final buildings = List<Map<String, dynamic>>.from(
            buildingsResponse['data']?['buildings'] ?? [],
          );
          final building = buildings.firstWhere(
            (b) =>
                b['code'] == _selectedBuilding ||
                b['name'] == _selectedBuilding,
            orElse: () => {},
          );

          if (building.isNotEmpty && building['code'] != null) {
            endpoint = ApiConstants.addBuildingCode(
              ApiConstants.adminBuildingDetails,
              building['code'],
            );
          } else {
            setState(() => _isLoadingBuildingData = false);
            return;
          }
        } else {
          setState(() => _isLoadingBuildingData = false);
          return;
        }
      } else {
        // For staff, use their apartment code
        final apartmentCode = _user?['apartmentCode'];
        if (apartmentCode != null) {
          endpoint = ApiConstants.addBuildingCode(
            ApiConstants.staffBuildingDetails,
            apartmentCode,
          );
        } else {
          setState(() => _isLoadingBuildingData = false);
          return;
        }
      }

      final response = await ApiService.get(endpoint);
      if (response['success'] == true) {
        final floors = List<Map<String, dynamic>>.from(
          response['data']?['building']?['floors'] ?? [],
        );
        setState(() {
          _floors = floors;
          _flats = [];
          _selectedFloor = null;
          _selectedFlatNumber = null;
        });
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoadingBuildingData = false);
      }
    }
  }

  void _onBuildingSelected(String? building) {
    setState(() {
      _selectedBuilding = building;
      _selectedFloor = null;
      _selectedFlatNumber = null;
      _flats = [];
    });
    if (building != null) {
      _loadFloorsAndFlats();
    }
  }

  void _onFloorSelected(int? floorNumber) {
    setState(() {
      _selectedFloor = floorNumber;
      _selectedFlatNumber = null;
      _flats = [];

      if (floorNumber != null) {
        final floor = _floors.firstWhere(
          (f) => f['floorNumber'] == floorNumber,
          orElse: () => {},
        );
        if (floor.isNotEmpty) {
          _flats = List<Map<String, dynamic>>.from(floor['flats'] ?? []);
        }
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show options: Camera or Gallery
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Photo Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.primary),
                title: Text(
                  'Take Photo',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primary),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.cancel, color: AppColors.error),
                title: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );

      if (source != null) {
        final XFile? image = await picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 800,
          maxHeight: 800,
        );
        if (image != null && mounted) {
          setState(() {
            _visitorPhoto = File(image.path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.showError(context, 'Error picking image: $e');
      }
    }
  }

  Future<void> _selectExpectedCheckOutTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.textOnPrimary,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: AppColors.textOnPrimary,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _expectedCheckOutTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_visitorNameController.text.trim().isEmpty) {
          AppMessageHandler.showError(context, 'Please enter visitor name');
          return false;
        }
        if (_mobileNumberController.text.trim().isEmpty) {
          AppMessageHandler.showError(context, 'Please enter mobile number');
          return false;
        }
        // Validate phone number format (Indian)
        final phoneRegex = RegExp(r'^[6-9]\d{9}$');
        final phone = _mobileNumberController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
        if (!phoneRegex.hasMatch(phone)) {
          AppMessageHandler.showError(context, 'Please enter a valid 10-digit mobile number');
          return false;
        }
        if (_selectedVisitorType == null) {
          AppMessageHandler.showError(context, 'Please select visitor type');
          return false;
        }
        return true;
      case 1:
        if (_selectedBuilding == null) {
          AppMessageHandler.showError(context, 'Please select building/block');
          return false;
        }
        if (_selectedFloor == null) {
          AppMessageHandler.showError(context, 'Please select floor');
          return false;
        }
        if (_selectedFlatNumber == null) {
          AppMessageHandler.showError(context, 'Please select flat number');
          return false;
        }
        return true;
      case 2:
        return true; // Additional info is optional
      default:
        return true;
    }
  }

  Future<void> _submitEntry() async {
    if (!_validateStep(2)) return;

    setState(() => _isLoading = true);

    try {
      // Find resident for the selected flat
      final flat = _flats.firstWhere(
        (f) => f['flatNumber'] == _selectedFlatNumber,
        orElse: () => {},
      );

      // Check if flat is occupied
      if (flat.isEmpty ||
          flat['isOccupied'] != true ||
          flat['occupiedBy'] == null) {
        AppMessageHandler.showError(
          context,
          'This flat is not occupied. Please select an occupied flat.',
        );
        setState(() => _isLoading = false);
        return;
      }

      // Get resident ID from occupiedBy
      final residentId = flat['occupiedBy'] is Map
          ? flat['occupiedBy']['userId'] ?? flat['occupiedBy']['_id']
          : flat['occupiedBy'];

      if (residentId == null) {
        AppMessageHandler.showError(
          context,
          'Resident information not found for this flat.',
        );
        setState(() => _isLoading = false);
        return;
      }

      final visitorData = {
        'visitorName': _visitorNameController.text.trim(),
        'phoneNumber': _mobileNumberController.text.trim().replaceAll(RegExp(r'[^\d]'), ''),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'visitorType': _selectedVisitorType,
        'building': _selectedBuilding,
        'flatNumber': _selectedFlatNumber,
        'floorNumber': _selectedFloor,
        'purpose': _purposeController.text.trim().isEmpty
            ? null
            : _purposeController.text.trim(),
        'vehicleNumber': _vehicleNumberController.text.trim().isEmpty
            ? null
            : _vehicleNumberController.text.trim().toUpperCase(),
        'carryingMaterial': _carryingMaterial,
        'numberOfVisitors': _numberOfVisitors,
        'expectedCheckOutTime': _expectedCheckOutTime?.toIso8601String(),
        'hostResidentId': residentId.toString(),
        'apartmentCode': _user?['apartmentCode'],
      };

      final response = await ApiService.post(
        ApiConstants.visitors,
        visitorData,
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(
          context,
          'Visitor entry recorded successfully',
        );
        // Wait a bit for socket event to propagate
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context, true);
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextStep() {
    if (_validateStep(_currentStep)) {
      if (_currentStep < 2) {
        setState(() {
          _currentStep++;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _submitEntry();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textOnPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Visitor Entry',
          style: TextStyle(color: AppColors.textOnPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Centered Timeline Progress Indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: _buildCenteredTimeline(),
            ),

            // Form Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildVisitorDetailsStep(),
                  _buildLocationStep(),
                  _buildAdditionalInfoStep(),
                ],
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: AppColors.border),
                          ),
                          child: Text(
                            'Back',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: _currentStep == 0 ? 1 : 1,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                                  color: AppColors.textOnPrimary,
                                ),
                              )
                            : Text(
                                _currentStep < 2 ? 'Continue' : 'Record Entry',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredTimeline() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimelineStep(0, 'Visitor', Icons.person),
        _buildTimelineConnector(0),
        _buildTimelineStep(1, 'Location', Icons.location_on),
        _buildTimelineConnector(1),
        _buildTimelineStep(2, 'Review', Icons.check_circle),
      ],
    );
  }

  Widget _buildTimelineStep(int step, String label, IconData icon) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.success
                : isActive
                    ? AppColors.primary
                    : AppColors.textLight.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : isCompleted
                      ? AppColors.success
                      : AppColors.border,
              width: 2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: AppColors.textOnPrimary, size: 24)
                : Icon(
                    icon,
                    color: isActive
                        ? AppColors.textOnPrimary
                        : AppColors.textSecondary,
                    size: 24,
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive || isCompleted
                ? AppColors.primary
                : AppColors.textLight,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector(int step) {
    final isCompleted = step < _currentStep;
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.success
            : AppColors.border,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildVisitorDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'Visitor Details',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter basic information about the visitor',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Photo (Optional) - Centered
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _visitorPhoto != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                _visitorPhoto!,
                                fit: BoxFit.cover,
                                width: 140,
                                height: 140,
                                cacheWidth: 280,
                                cacheHeight: 280,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 140,
                                    height: 140,
                                    color: AppColors.surface,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: AppColors.textLight,
                                      size: 48,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _visitorPhoto = null);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: AppColors.textOnPrimary,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              color: AppColors.primary,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add Photo\n(Optional)',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Visitor Name
            Text(
              'Visitor Name *',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _visitorNameController,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter full name',
                hintStyle: TextStyle(color: AppColors.textLight),
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: Icon(Icons.person, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Mobile Number
            Text(
              'Mobile Number *',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _mobileNumberController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '10-digit mobile number',
                hintStyle: TextStyle(color: AppColors.textLight),
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: Icon(Icons.phone, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Email (Optional)
            Text(
              'Email (Optional)',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'email@example.com',
                hintStyle: TextStyle(color: AppColors.textLight),
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: Icon(Icons.email, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Visitor Type
            Text(
              'Visitor Type *',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedVisitorType,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Select visitor type',
                hintStyle: TextStyle(color: AppColors.textLight),
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: Icon(Icons.category, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              dropdownColor: AppColors.surface,
              items: _visitorTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type['value'],
                  child: Row(
                    children: [
                      Text(
                        type['icon'] ?? '',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        type['label'] ?? '',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedVisitorType = value);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  'Location Details',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Where is the visitor going?',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Building/Block
          Text(
            'Building / Block *',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingBuildingData)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_buildings.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'No buildings available',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _buildings.map((building) {
                final isSelected = _selectedBuilding == building;
                return GestureDetector(
                  onTap: () => _onBuildingSelected(building),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 72) / 2,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
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
                    child: Center(
                      child: Text(
                        building,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),

          // Floor Selection
          if (_selectedBuilding != null && _floors.isNotEmpty) ...[
            Text(
              'Floor *',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _floors.length,
                itemBuilder: (context, index) {
                  final floor = _floors[index];
                  final floorNumber = floor['floorNumber'] as int;
                  final isSelected = _selectedFloor == floorNumber;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => _onFloorSelected(floorNumber),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Floor $floorNumber',
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Flat Selection
          if (_selectedFloor != null && _flats.isNotEmpty) ...[
            Text(
              'Flat Number *',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _flats.map((flat) {
                final flatNumber = flat['flatNumber'] as String? ?? '';
                final isSelected = _selectedFlatNumber == flatNumber;
                final isOccupied = flat['isOccupied'] == true;
                return GestureDetector(
                  onTap: isOccupied
                      ? () {
                          setState(() => _selectedFlatNumber = flatNumber);
                        }
                      : null,
                  child: Opacity(
                    opacity: isOccupied ? 1.0 : 0.5,
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 72) / 2,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : isOccupied
                                  ? AppColors.border
                                  : AppColors.error.withOpacity(0.5),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              flatNumber,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (!isOccupied)
                              Text(
                                '(Vacant)',
                                style: TextStyle(
                                  color: AppColors.error.withOpacity(0.7),
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Purpose
          Text(
            'Purpose of Visit',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _purposeController,
            maxLines: 3,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Brief description of visit purpose...',
              hintStyle: TextStyle(color: AppColors.textLight),
              filled: true,
              fillColor: AppColors.surface,
              prefixIcon: Icon(Icons.description, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  'Additional Information',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Optional details and review',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Number of Visitors
          Text(
            'Number of Visitors',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Visitors',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline,
                          color: AppColors.primary),
                      onPressed: () {
                        if (_numberOfVisitors > 1) {
                          setState(() => _numberOfVisitors--);
                        }
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_numberOfVisitors',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline,
                          color: AppColors.primary),
                      onPressed: () {
                        if (_numberOfVisitors < 20) {
                          setState(() => _numberOfVisitors++);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Expected Check-out Time
          Text(
            'Expected Check-out Time',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectExpectedCheckOutTime,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        _expectedCheckOutTime != null
                            ? DateFormat('dd MMM yyyy, hh:mm a')
                                .format(_expectedCheckOutTime!)
                            : 'Select expected check-out time',
                        style: TextStyle(
                          color: _expectedCheckOutTime != null
                              ? AppColors.textPrimary
                              : AppColors.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Vehicle Number
          Text(
            'Vehicle Number (Optional)',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _vehicleNumberController,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g., MH 01 AB 1234',
              hintStyle: TextStyle(color: AppColors.textLight),
              filled: true,
              fillColor: AppColors.surface,
              prefixIcon: Icon(Icons.directions_car, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Carrying Material
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carrying Material?',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Packages, tools, etc.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _carryingMaterial,
                  onChanged: (value) {
                    setState(() => _carryingMaterial = value);
                  },
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Entry Summary
          Text(
            'Entry Summary',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  'Visitor Name',
                  _visitorNameController.text.isEmpty
                      ? 'Not provided'
                      : _visitorNameController.text,
                ),
                const Divider(color: AppColors.border),
                _buildSummaryRow(
                  'Mobile Number',
                  _mobileNumberController.text.isEmpty
                      ? 'Not provided'
                      : _mobileNumberController.text,
                ),
                if (_emailController.text.isNotEmpty) ...[
                  const Divider(color: AppColors.border),
                  _buildSummaryRow(
                    'Email',
                    _emailController.text,
                  ),
                ],
                const Divider(color: AppColors.border),
                _buildSummaryRow(
                  'Visitor Type',
                  _selectedVisitorType ?? 'Not selected',
                ),
                const Divider(color: AppColors.border),
                _buildSummaryRow(
                  'Building / Block',
                  _selectedBuilding ?? 'Not selected',
                ),
                const Divider(color: AppColors.border),
                _buildSummaryRow(
                  'Floor',
                  _selectedFloor != null
                      ? 'Floor $_selectedFloor'
                      : 'Not selected',
                ),
                const Divider(color: AppColors.border),
                _buildSummaryRow(
                  'Flat Number',
                  _selectedFlatNumber ?? 'Not selected',
                ),
                if (_purposeController.text.isNotEmpty) ...[
                  const Divider(color: AppColors.border),
                  _buildSummaryRow('Purpose', _purposeController.text),
                ],
                const Divider(color: AppColors.border),
                _buildSummaryRow(
                  'Number of Visitors',
                  '$_numberOfVisitors',
                ),
                if (_expectedCheckOutTime != null) ...[
                  const Divider(color: AppColors.border),
                  _buildSummaryRow(
                    'Expected Check-out',
                    DateFormat('dd MMM yyyy, hh:mm a')
                        .format(_expectedCheckOutTime!),
                  ),
                ],
                if (_vehicleNumberController.text.isNotEmpty) ...[
                  const Divider(color: AppColors.border),
                  _buildSummaryRow(
                    'Vehicle Number',
                    _vehicleNumberController.text,
                  ),
                ],
                const Divider(color: AppColors.border),
                _buildSummaryRow(
                  'Carrying Material',
                  _carryingMaterial ? 'Yes' : 'No',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
