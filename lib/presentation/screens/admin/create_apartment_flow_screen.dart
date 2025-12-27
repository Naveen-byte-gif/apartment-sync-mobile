import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import 'admin_dashboard_screen.dart';
import 'flat_layout_configuration_screen.dart';

/// Data model for floor configuration
class FloorConfig {
  final int floorNumber;
  final int totalFlats;
  final Map<String, int> flatTypeCounts; // e.g., {'1BHK': 2, '2BHK': 4}

  FloorConfig({
    required this.floorNumber,
    required this.totalFlats,
    Map<String, int>? flatTypeCounts,
  }) : flatTypeCounts = flatTypeCounts ?? {};

  int get totalConfiguredFlats => 
      flatTypeCounts.values.fold(0, (sum, count) => sum + count);

  bool get isValid => totalConfiguredFlats == totalFlats;

  Map<String, dynamic> toJson() {
    return {
      'floorNumber': floorNumber,
      'totalFlats': totalFlats,
      'flatTypes': flatTypeCounts.entries.map((e) => {
            'type': e.key,
            'count': e.value,
          }).toList(),
    };
  }
}

class CreateApartmentFlowScreen extends StatefulWidget {
  const CreateApartmentFlowScreen({super.key});

  @override
  State<CreateApartmentFlowScreen> createState() => _CreateApartmentFlowScreenState();
}

class _CreateApartmentFlowScreenState extends State<CreateApartmentFlowScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Basic Apartment Information
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  // Step 2: Floor Configuration
  int? _totalFloors;
  final Map<int, FloorConfig> _floorConfigs = {}; // floorNumber -> FloorConfig

  // Step 3: Flat Type Configuration (handled in separate screen)
  // Step 4: Preview (generated from configs)

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 3) {
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
        if (_nameController.text.isEmpty || 
            _codeController.text.isEmpty ||
            _streetController.text.isEmpty ||
            _cityController.text.isEmpty ||
            _stateController.text.isEmpty ||
            _pincodeController.text.isEmpty) {
          AppMessageHandler.showError(context, 'Please fill all required fields');
          return false;
        }
        return true;
      case 1:
        if (_totalFloors == null || _totalFloors! < 1 || _totalFloors! > 100) {
          AppMessageHandler.showError(context, 'Please enter a valid number of floors (1-100)');
          return false;
        }
        // Initialize floor configs if not already done
        if (_floorConfigs.isEmpty) {
          for (int i = 1; i <= _totalFloors!; i++) {
            _floorConfigs[i] = FloorConfig(
              floorNumber: i,
              totalFlats: 4, // Default
            );
          }
        }
        return true;
      case 2:
        // Validation happens in flat configuration screen
        return true;
      default:
        return true;
    }
  }

  Future<void> _openFlatConfiguration() async {
    if (_totalFloors == null || _totalFloors! < 1) {
      AppMessageHandler.showError(context, 'Please configure floors first');
      return;
    }

        // Navigate to flat configuration screen
        final result = await Navigator.push<List<FloorFlatConfig>>(
          context,
          MaterialPageRoute(
            builder: (context) => FlatLayoutConfigurationScreen(
              totalFloors: _totalFloors!,
              flatsPerFloor: 4, // Default, will be overridden by floorsConfig
              floorsConfig: _floorConfigs.values.map((fc) => FloorFlatConfig(
                floorNumber: fc.floorNumber,
                totalFlats: fc.totalFlats,
                flatTypeCounts: fc.flatTypeCounts,
              )).toList(),
              onConfigurationComplete: (configs) {
                Navigator.pop(context, configs);
              },
            ),
          ),
        );

    if (result != null) {
      setState(() {
        // Update floor configs with flat type configurations
        for (final config in result) {
          if (_floorConfigs.containsKey(config.floorNumber)) {
            _floorConfigs[config.floorNumber] = FloorConfig(
              floorNumber: config.floorNumber,
              totalFlats: _floorConfigs[config.floorNumber]!.totalFlats,
              flatTypeCounts: config.flatTypeCounts,
            );
          }
        }
      });
      // Move to preview step
      _nextStep();
    }
  }

  Future<void> _createApartment() async {
    if (!_validateCurrentStep()) {
      return;
    }

    // Validate all floors have flat type configurations
    bool allFloorsValid = true;
    for (int i = 1; i <= _totalFloors!; i++) {
      final config = _floorConfigs[i];
      if (config == null || !config.isValid) {
        allFloorsValid = false;
        break;
      }
    }

    if (!allFloorsValid) {
      AppMessageHandler.showError(context, 
        'Please configure flat types for all floors. Total flat type counts must match total flats per floor.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final floorConfigsList = _floorConfigs.values
          .where((fc) => fc.flatTypeCounts.isNotEmpty)
          .map((fc) => fc.toJson())
          .toList();

      final buildingData = {
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim().toUpperCase(),
        'totalFloors': _totalFloors,
        'address': {
          'street': _streetController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'pincode': _pincodeController.text.trim(),
          'country': 'India',
        },
        'floorConfigs': floorConfigsList,
      };

      final response = await ApiService.post(ApiConstants.adminBuildings, buildingData);

      if (mounted) {
        final statusCode = response['_statusCode'] as int?;
        AppMessageHandler.handleResponse(
          context,
          response,
          statusCode: statusCode,
          showDialog: statusCode != null && statusCode >= 400 && statusCode < 500, // Show dialog for client errors
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

  List<Map<String, dynamic>> _generatePreview() {
    List<Map<String, dynamic>> preview = [];
    
    for (int floorNum = 1; floorNum <= (_totalFloors ?? 0); floorNum++) {
      final config = _floorConfigs[floorNum];
      if (config == null) continue;

      List<Map<String, dynamic>> flats = [];
      int flatIndex = 1;

      config.flatTypeCounts.forEach((type, count) {
        for (int i = 0; i < count; i++) {
          flats.add({
            'flatNumber': '${floorNum}${flatIndex.toString().padLeft(2, '0')}',
            'flatType': type,
          });
          flatIndex++;
        }
      });

      preview.add({
        'floorNumber': floorNum,
        'totalFlats': config.totalFlats,
        'flats': flats,
      });
    }

    return preview;
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Creating apartment...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Apartment'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Progress Indicator
            _buildProgressIndicator(),
            
            // Form Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1BasicInfo(),
                  _buildStep2FloorConfig(),
                  _buildStep3FlatTypeConfig(),
                  _buildStep4Preview(),
                ],
              ),
            ),
            
            // Navigation Buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
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
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Step 1: Apartment Information';
      case 1:
        return 'Step 2: Floor Configuration';
      case 2:
        return 'Step 3: Flat Type Configuration';
      case 3:
        return 'Step 4: Preview & Confirm';
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
          _buildSectionTitle('Apartment Information', Icons.business),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Apartment Name *',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Apartment Code *',
              prefixIcon: Icon(Icons.tag),
              border: OutlineInputBorder(),
              helperText: 'Unique identifier (e.g., APT001)',
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Address', Icons.location_on),
          const SizedBox(height: 16),
          TextFormField(
            controller: _streetController,
            decoration: const InputDecoration(
              labelText: 'Street Address *',
              prefixIcon: Icon(Icons.streetview),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'City *',
              prefixIcon: Icon(Icons.location_city),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _stateController,
            decoration: const InputDecoration(
              labelText: 'State *',
              prefixIcon: Icon(Icons.map),
              border: OutlineInputBorder(),
            ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildStep2FloorConfig() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Floor Configuration', Icons.layers),
          const SizedBox(height: 24),
          TextFormField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total Floors *',
              prefixIcon: Icon(Icons.layers),
              border: OutlineInputBorder(),
              helperText: 'Number of floors in the apartment',
            ),
            onChanged: (value) {
              final floors = int.tryParse(value);
              if (floors != null && floors >= 1 && floors <= 100) {
                setState(() {
                  _totalFloors = floors;
                  // Initialize floor configs
                  _floorConfigs.clear();
                  for (int i = 1; i <= floors; i++) {
                    _floorConfigs[i] = FloorConfig(
                      floorNumber: i,
                      totalFlats: 4, // Default, will be configured in next step
                    );
                  }
                });
              }
            },
          ),
          if (_totalFloors != null && _totalFloors! > 0) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: 8),
                      const Text(
                        'Configure Flats per Floor',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(_totalFloors!, (index) {
                    final floorNum = index + 1;
                    final config = _floorConfigs[floorNum];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Floor $floorNum'),
                          ),
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              keyboardType: TextInputType.number,
                              initialValue: config?.totalFlats.toString() ?? '4',
                              decoration: const InputDecoration(
                                labelText: 'Total Flats',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (value) {
                                final totalFlats = int.tryParse(value);
                                if (totalFlats != null && totalFlats >= 1 && totalFlats <= 50) {
                                  setState(() {
                                    _floorConfigs[floorNum] = FloorConfig(
                                      floorNumber: floorNum,
                                      totalFlats: totalFlats,
                                      flatTypeCounts: config?.flatTypeCounts ?? {},
                                    );
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep3FlatTypeConfig() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Flat Type Configuration', Icons.home),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.settings, size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                const Text(
                  'Configure Flat Types',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click the button below to configure flat types for each floor. You can specify how many flats of each type (1BHK, 2BHK, 3BHK, etc.) are on each floor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openFlatConfiguration,
              icon: const Icon(Icons.layers),
              label: const Text('Configure Flat Types'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Preview() {
    final preview = _generatePreview();
    final totalFlats = preview.fold<int>(
      0,
      (sum, floor) => sum + (floor['flats'] as List).length,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Preview', Icons.preview),
          const SizedBox(height: 16),
          // Summary Card
          Card(
            color: AppColors.primary.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Apartment Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Name', _nameController.text),
                  _buildSummaryRow('Code', _codeController.text.toUpperCase()),
                  _buildSummaryRow('Address', 
                    '${_streetController.text}, ${_cityController.text}, ${_stateController.text} - ${_pincodeController.text}'),
                  _buildSummaryRow('Total Floors', '$_totalFloors'),
                  _buildSummaryRow('Total Flats', '$totalFlats'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Floors Preview
          const Text(
            'Floor-wise Configuration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...preview.map((floorData) {
            final floorNum = floorData['floorNumber'] as int;
            final flats = floorData['flats'] as List<Map<String, dynamic>>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Floor $floorNum',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: flats.map((flat) {
                        return Chip(
                          label: Text('${flat['flatNumber']} (${flat['flatType']})'),
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
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
                    text: 'Create Apartment',
                    isLoading: _isLoading,
                    onPressed: _createApartment,
                    icon: Icons.check,
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

