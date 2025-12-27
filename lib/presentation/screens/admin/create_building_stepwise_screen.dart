import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import 'admin_dashboard_screen.dart';
import 'flat_layout_configuration_screen.dart';

class CreateBuildingStepwiseScreen extends StatefulWidget {
  const CreateBuildingStepwiseScreen({super.key});

  @override
  State<CreateBuildingStepwiseScreen> createState() => _CreateBuildingStepwiseScreenState();
}

class _CreateBuildingStepwiseScreenState extends State<CreateBuildingStepwiseScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Step 1: Basic Information
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  String? _buildingCategory;
  String? _buildingType;

  // Step 2: Address
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  // Step 3: Contact
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _managerNameController = TextEditingController();

  // Step 4: Building Configuration
  final _totalFloorsController = TextEditingController(text: '5');
  final _flatsPerFloorController = TextEditingController(text: '4');
  List<FloorFlatConfig>? _floorLayoutConfig;

  final List<String> _buildingCategories = ['Residential', 'Commercial', 'Mixed Use'];
  final List<String> _buildingTypes = ['Apartment', 'Independent Building', 'Villa Block', 'Gated Community'];

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _managerNameController.dispose();
    _totalFloorsController.dispose();
    _flatsPerFloorController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (_validateCurrentStep()) {
        setState(() {
          _currentStep++;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
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

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nameController.text.isEmpty || _codeController.text.isEmpty ||
            _buildingCategory == null || _buildingType == null) {
          AppMessageHandler.showError(context, 'Please fill all required fields');
          return false;
        }
        return true;
      case 1:
        if (_streetController.text.isEmpty || _cityController.text.isEmpty ||
            _stateController.text.isEmpty || _pincodeController.text.isEmpty) {
          AppMessageHandler.showError(context, 'Please fill all address fields');
          return false;
        }
        return true;
      case 2:
        return true; // Contact is optional
      case 3:
        final totalFloors = int.tryParse(_totalFloorsController.text);
        final flatsPerFloor = int.tryParse(_flatsPerFloorController.text);
        if (totalFloors == null || totalFloors < 1 || totalFloors > 100) {
          AppMessageHandler.showError(context, 'Total floors must be between 1 and 100');
          return false;
        }
        if (flatsPerFloor == null || flatsPerFloor < 1 || flatsPerFloor > 50) {
          AppMessageHandler.showError(context, 'Flats per floor must be between 1 and 50');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _openFlatConfiguration() async {
    final totalFloors = int.tryParse(_totalFloorsController.text);
    final flatsPerFloor = int.tryParse(_flatsPerFloorController.text);

    if (totalFloors == null || flatsPerFloor == null) {
      AppMessageHandler.showError(context, 'Please enter valid floor and flat counts');
      return;
    }

    final result = await Navigator.push<List<FloorFlatConfig>>(
      context,
      MaterialPageRoute(
        builder: (context) => FlatLayoutConfigurationScreen(
          totalFloors: totalFloors,
          flatsPerFloor: flatsPerFloor,
          onConfigurationComplete: (configs) {
            Navigator.pop(context, configs);
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _floorLayoutConfig = result;
      });
      // Automatically proceed to create building after configuration
      _createBuilding();
    }
  }

  Future<void> _createBuilding() async {
    if (!_validateCurrentStep()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final totalFloors = int.parse(_totalFloorsController.text);
      final flatsPerFloor = int.parse(_flatsPerFloorController.text);

      // Simple building data - backend will auto-generate flat numbers
      final buildingData = {
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim().toUpperCase(),
        'buildingCategory': _buildingCategory,
        'buildingType': _buildingType,
        'totalFloors': totalFloors,
        'flatsPerFloor': flatsPerFloor,
        'address': {
          'street': _streetController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'pincode': _pincodeController.text.trim(),
          'country': 'India',
        },
        'contact': {
          'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          'managerName': _managerNameController.text.trim().isEmpty ? null : _managerNameController.text.trim(),
        },
        // Include floor layout config if available (only for custom layouts)
        if (_floorLayoutConfig != null && _floorLayoutConfig!.isNotEmpty)
          'floorLayoutConfig': _floorLayoutConfig!.map((config) => config.toJson()).toList(),
      };

      final response = await ApiService.post(ApiConstants.adminBuildings, buildingData);

      if (mounted) {
        AppMessageHandler.handleResponse(
          context,
          response,
          onSuccess: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
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

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Creating building...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Building'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.primary.withOpacity(0.1),
              child: Column(
                children: [
                  Row(
                    children: List.generate(4, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 4,
                          decoration: BoxDecoration(
                            color: index <= _currentStep
                                ? AppColors.primary
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStepTitle(_currentStep),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Form Content
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1BasicInfo(),
                    _buildStep2Address(),
                    _buildStep3Contact(),
                    _buildStep4Configuration(),
                  ],
                ),
              ),
            ),
            
            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _currentStep == 3
                        ? LoadingButton(
                            text: 'Configure Flat Layout',
                            isLoading: _isLoading,
                            onPressed: _openFlatConfiguration,
                            icon: Icons.layers,
                          )
                        : ElevatedButton(
                            onPressed: _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Next'),
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

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Step 1: Basic Information';
      case 1:
        return 'Step 2: Address';
      case 2:
        return 'Step 3: Contact Information';
      case 3:
        return 'Step 4: Building Configuration';
      default:
        return '';
    }
  }

  Widget _buildStep1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Basic Building Information', Icons.business),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Building Name *',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Building Code *',
              prefixIcon: Icon(Icons.tag),
              border: OutlineInputBorder(),
              helperText: 'Unique identifier for the building',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _buildingCategory,
            decoration: const InputDecoration(
              labelText: 'Building Category *',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
            items: _buildingCategories
                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                .toList(),
            onChanged: (value) => setState(() => _buildingCategory = value),
            validator: (value) => value == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _buildingType,
            decoration: const InputDecoration(
              labelText: 'Building Type *',
              prefixIcon: Icon(Icons.apartment),
              border: OutlineInputBorder(),
            ),
            items: _buildingTypes
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) => setState(() => _buildingType = value),
            validator: (value) => value == null ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Address() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Address Details', Icons.location_on),
          const SizedBox(height: 16),
          TextFormField(
            controller: _streetController,
            decoration: const InputDecoration(
              labelText: 'Street Address *',
              prefixIcon: Icon(Icons.streetview),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'City *',
              prefixIcon: Icon(Icons.location_city),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _stateController,
            decoration: const InputDecoration(
              labelText: 'State *',
              prefixIcon: Icon(Icons.map),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pincodeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Pincode *',
              prefixIcon: Icon(Icons.pin),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Contact() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Contact Information', Icons.contact_phone),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _managerNameController,
            decoration: const InputDecoration(
              labelText: 'Manager Name',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Configuration() {
    final totalFloors = int.tryParse(_totalFloorsController.text) ?? 5;
    final flatsPerFloor = int.tryParse(_flatsPerFloorController.text) ?? 4;
    final totalFlats = totalFloors * flatsPerFloor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Building Configuration', Icons.layers),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _totalFloorsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total Floors *',
                    prefixIcon: Icon(Icons.layers),
                    border: OutlineInputBorder(),
                    helperText: 'Number of floors in building',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final num = int.tryParse(value);
                    if (num == null || num < 1 || num > 100) return '1-100';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _flatsPerFloorController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Flats per Floor *',
                    prefixIcon: Icon(Icons.home),
                    border: OutlineInputBorder(),
                    helperText: 'Flats on each floor',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final num = int.tryParse(value);
                    if (num == null || num < 1 || num > 50) return '1-50';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Auto-generation Preview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.secondary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Auto Layout Mode Enabled',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPreviewItem(
                  Icons.calculate,
                  'Total Flats',
                  '$totalFlats flats will be created',
                ),
                const SizedBox(height: 12),
                _buildPreviewItem(
                  Icons.format_list_numbered,
                  'Flat Numbering',
                  'Floor 1 → 101, 102, 103...\nFloor 2 → 201, 202, 203...\nFloor 3 → 301, 302, 303...',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Click "Configure Flat Layout" to customize flat types per floor. Default auto-layout will distribute flat types automatically.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_floorLayoutConfig != null && _floorLayoutConfig!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Custom flat layout configured for ${_floorLayoutConfig!.length} floor(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Example Preview
          if (totalFloors > 0 && flatsPerFloor > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview (First 3 floors):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(
                    totalFloors > 3 ? 3 : totalFloors,
                    (floorIndex) {
                      final floorNum = floorIndex + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Floor $floorNum',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: List.generate(
                                  flatsPerFloor > 5 ? 5 : flatsPerFloor,
                                  (flatIndex) {
                                    final flatNum = flatIndex + 1;
                                    final flatNumber = '$floorNum${flatNum.toString().padLeft(2, '0')}';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        flatNumber,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            if (flatsPerFloor > 5)
                              Text(
                                '+${flatsPerFloor - 5} more',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}

