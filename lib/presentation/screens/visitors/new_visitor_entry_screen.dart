import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  // Step 1: Visitor Details
  File? _visitorPhoto;
  final _visitorNameController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  String? _selectedVisitorType;

  // Step 2: Location
  String? _selectedBuilding;
  int? _selectedFloor;
  String? _selectedFlatNumber;
  final _purposeController = TextEditingController();

  // Step 3: Additional Info
  final _vehicleNumberController = TextEditingController();
  bool _carryingMaterial = false;

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

  @override
  void dispose() {
    _visitorNameController.dispose();
    _mobileNumberController.dispose();
    _purposeController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show options: Camera or Gallery
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: const Color(0xFF1A2332),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red),
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

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_visitorNameController.text.trim().isEmpty) {
          AppMessageHandler.showError(context, 'Please enter visitor name');
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
        'phoneNumber': _mobileNumberController.text.trim().isEmpty
            ? null
            : _mobileNumberController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Visitor Entry',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _buildProgressStep(0, 'Visitor Details'),
                  _buildProgressStep(1, 'Location'),
                  _buildProgressStep(2, 'Review'),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: Form(key: _formKey, child: _buildStepContent()),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
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
                          onPressed: () {
                            setState(() => _currentStep--);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.white30),
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: _currentStep == 0 ? 1 : 1,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_currentStep < 2) {
                                  if (_validateStep(_currentStep)) {
                                    setState(() => _currentStep++);
                                  }
                                } else {
                                  _submitEntry();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _currentStep < 2 ? 'Continue' : 'Record Entry',
                                style: const TextStyle(
                                  color: Colors.white,
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

  Widget _buildProgressStep(int step, String label) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;

    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isCompleted || isActive
                      ? Colors.green
                      : Colors.grey.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              if (step < 2)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted
                        ? Colors.green
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white60,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: _buildVisitorDetailsStep(),
        );
      case 1:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: _buildLocationStep(),
        );
      case 2:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: _buildAdditionalInfoStep(),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildVisitorDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visitor Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter basic information',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Photo (Optional)
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white30, width: 2),
              ),
              child: _visitorPhoto != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _visitorPhoto!,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
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
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.white70, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'Take Photo (Optional)',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Visitor Name
        TextFormField(
          controller: _visitorNameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Visitor Name *',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: 'Enter full name',
            hintStyle: TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Mobile Number
        TextFormField(
          controller: _mobileNumberController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Mobile Number',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: 'Optional',
            hintStyle: TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Visitor Type
        DropdownButtonFormField<String>(
          value: _selectedVisitorType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Visitor Type *',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green, width: 2),
            ),
          ),
          dropdownColor: const Color(0xFF1A2332),
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
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedVisitorType = value);
          },
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Where is the visitor going?',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Building/Block
        const Text(
          'Building / Block *',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingBuildingData)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          )
        else if (_buildings.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No buildings available',
              style: TextStyle(color: Colors.white70),
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
                  width: (MediaQuery.of(context).size.width - 64) / 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.green.withOpacity(0.2)
                        : const Color(0xFF1A2332),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.green : Colors.white30,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      building,
                      style: TextStyle(
                        color: isSelected ? Colors.green : Colors.white,
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
          const Text(
            'Floor *',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
                            ? Colors.green.withOpacity(0.2)
                            : const Color(0xFF1A2332),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.green : Colors.white30,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Floor $floorNumber',
                          style: TextStyle(
                            color: isSelected ? Colors.green : Colors.white,
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
          const Text(
            'Flat Number *',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
                    width: (MediaQuery.of(context).size.width - 64) / 2,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.green.withOpacity(0.2)
                          : const Color(0xFF1A2332),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.green
                            : isOccupied
                            ? Colors.white30
                            : Colors.red.withOpacity(0.5),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            flatNumber,
                            style: TextStyle(
                              color: isSelected ? Colors.green : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (!isOccupied)
                            Text(
                              '(Vacant)',
                              style: TextStyle(
                                color: Colors.red.withOpacity(0.7),
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
        const Text(
          'Purpose of Visit',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _purposeController,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Brief description...',
            hintStyle: TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Additional Info Section
        const Text(
          'Additional Info',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Optional details',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Vehicle Number
        const Text(
          'Vehicle Number',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _vehicleNumberController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g., MH 01 AB 1234',
            hintStyle: TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Carrying Material
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2332),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Carrying Material?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Packages, tools, etc.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _carryingMaterial,
                onChanged: (value) {
                  setState(() => _carryingMaterial = value);
                },
                activeColor: Colors.green,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Entry Summary
        const Text(
          'Entry Summary',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2332),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                'Visitor Name',
                _visitorNameController.text.isEmpty
                    ? 'Not provided'
                    : _visitorNameController.text,
              ),
              const Divider(color: Colors.white30),
              _buildSummaryRow(
                'Mobile Number',
                _mobileNumberController.text.isEmpty
                    ? 'Not provided'
                    : _mobileNumberController.text,
              ),
              const Divider(color: Colors.white30),
              _buildSummaryRow(
                'Visitor Type',
                _selectedVisitorType ?? 'Not selected',
              ),
              const Divider(color: Colors.white30),
              _buildSummaryRow(
                'Building / Block',
                _selectedBuilding ?? 'Not selected',
              ),
              const Divider(color: Colors.white30),
              _buildSummaryRow(
                'Floor',
                _selectedFloor != null
                    ? 'Floor $_selectedFloor'
                    : 'Not selected',
              ),
              const Divider(color: Colors.white30),
              _buildSummaryRow(
                'Flat Number',
                _selectedFlatNumber ?? 'Not selected',
              ),
              if (_purposeController.text.isNotEmpty) ...[
                const Divider(color: Colors.white30),
                _buildSummaryRow('Purpose', _purposeController.text),
              ],
              if (_vehicleNumberController.text.isNotEmpty) ...[
                const Divider(color: Colors.white30),
                _buildSummaryRow(
                  'Vehicle Number',
                  _vehicleNumberController.text,
                ),
              ],
              const Divider(color: Colors.white30),
              _buildSummaryRow(
                'Carrying Material',
                _carryingMaterial ? 'Yes' : 'No',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
