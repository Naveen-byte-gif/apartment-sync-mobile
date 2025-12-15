import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import 'admin_dashboard_screen.dart';

class CreateBuildingComprehensiveScreen extends StatefulWidget {
  const CreateBuildingComprehensiveScreen({super.key});

  @override
  State<CreateBuildingComprehensiveScreen> createState() => _CreateBuildingComprehensiveScreenState();
}

class _CreateBuildingComprehensiveScreenState extends State<CreateBuildingComprehensiveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  
  // Basic Information
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  String? _buildingCategory;
  String? _buildingType;
  
  // Address
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  
  // Contact
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _managerNameController = TextEditingController();
  
  // Structural Details
  String? _constructionType;
  final _plotAreaController = TextEditingController();
  String? _plotAreaUnit;
  final _builtUpAreaController = TextEditingController();
  String? _builtUpAreaUnit;
  final _blocksController = TextEditingController(text: '1');
  final _basementsController = TextEditingController(text: '0');
  DateTime? _constructionStartDate;
  DateTime? _constructionCompletionDate;
  
  // Safety & Compliance
  bool _hasFireNOC = false;
  final _fireNOCNumberController = TextEditingController();
  DateTime? _fireNOCExpiry;
  bool _hasLiftCertificate = false;
  final _liftCertNumberController = TextEditingController();
  DateTime? _liftCertExpiry;
  bool _hasStructuralCertificate = false;
  final _structuralCertNumberController = TextEditingController();
  
  // Utilities
  List<String> _waterSources = [];
  String? _electricityConnection;
  String? _sewageSystem;
  String? _powerBackup;
  bool _rainWaterHarvesting = false;
  
  // Parking
  final _parkingSlotsController = TextEditingController();
  List<String> _parkingTypes = [];
  bool _twoWheelerParking = true;
  bool _fourWheelerParking = true;
  
  // Amenities
  List<String> _selectedAmenities = [];
  
  // Building Configuration
  final _totalFloorsController = TextEditingController(text: '5');
  final _flatsPerFloorController = TextEditingController(text: '4');
  
  bool _isLoading = false;
  
  final List<String> _buildingCategories = ['Residential', 'Commercial', 'Mixed Use'];
  final List<String> _buildingTypes = ['Apartment', 'Independent Building', 'Villa Block', 'Gated Community'];
  final List<String> _constructionTypes = ['RCC', 'Load Bearing', 'Steel', 'Precast'];
  final List<String> _waterSourceOptions = ['Municipal', 'Borewell', 'Tanker'];
  final List<String> _electricityOptions = ['Individual Meters', 'Common Meter'];
  final List<String> _sewageOptions = ['Underground Drainage', 'Septic Tank', 'STP'];
  final List<String> _powerBackupOptions = ['Generator', 'UPS', 'None'];
  final List<String> _parkingTypeOptions = ['Covered', 'Open', 'Mechanical'];
  final List<String> _amenityOptions = [
    'Lift', 'CCTV', 'Security Room', 'Intercom', 'Garbage Area',
    'Visitor Parking', 'Fire Safety Equipment', 'Gym', 'Swimming Pool',
    'Clubhouse', 'Playground', 'Garden', 'Park'
  ];
  
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
    _plotAreaController.dispose();
    _builtUpAreaController.dispose();
    _blocksController.dispose();
    _basementsController.dispose();
    _fireNOCNumberController.dispose();
    _liftCertNumberController.dispose();
    _structuralCertNumberController.dispose();
    _parkingSlotsController.dispose();
    _totalFloorsController.dispose();
    _flatsPerFloorController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate(BuildContext context, Function(DateTime) onDateSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }
  
  Future<void> _createBuilding() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_buildingCategory == null || _buildingType == null) {
      AppMessageHandler.showError(context, 'Please select building category and type');
      return;
    }
    
    final totalFloors = int.tryParse(_totalFloorsController.text) ?? 5;
    final flatsPerFloor = int.tryParse(_flatsPerFloorController.text) ?? 4;
    
    if (totalFloors < 1 || totalFloors > 100) {
      AppMessageHandler.showError(context, 'Total floors must be between 1 and 100');
      return;
    }
    
    if (flatsPerFloor < 1 || flatsPerFloor > 50) {
      AppMessageHandler.showError(context, 'Flats per floor must be between 1 and 50');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
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
          'country': 'India'
        },
        'contact': {
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'managerName': _managerNameController.text.trim()
        },
        'structuralDetails': {
          'constructionType': _constructionType ?? 'RCC',
          'totalPlotArea': _plotAreaController.text.isNotEmpty ? {
            'value': double.tryParse(_plotAreaController.text),
            'unit': _plotAreaUnit ?? 'sq.yd'
          } : null,
          'totalBuiltUpArea': _builtUpAreaController.text.isNotEmpty ? {
            'value': double.tryParse(_builtUpAreaController.text),
            'unit': _builtUpAreaUnit ?? 'sq.ft'
          } : null,
          'numberOfBlocks': int.tryParse(_blocksController.text) ?? 1,
          'numberOfBasements': int.tryParse(_basementsController.text) ?? 0,
          'constructionStartDate': _constructionStartDate?.toIso8601String(),
          'constructionCompletionDate': _constructionCompletionDate?.toIso8601String()
        },
        'safetyCompliance': {
          'fireSafetyNOC': {
            'hasNOC': _hasFireNOC,
            'nocNumber': _hasFireNOC ? _fireNOCNumberController.text.trim() : null,
            'expiryDate': _hasFireNOC && _fireNOCExpiry != null ? _fireNOCExpiry!.toIso8601String() : null
          },
          'liftSafetyCertificate': {
            'hasCertificate': _hasLiftCertificate,
            'certificateNumber': _hasLiftCertificate ? _liftCertNumberController.text.trim() : null,
            'expiryDate': _hasLiftCertificate && _liftCertExpiry != null ? _liftCertExpiry!.toIso8601String() : null
          },
          'structuralStabilityCertificate': {
            'hasCertificate': _hasStructuralCertificate,
            'certificateNumber': _hasStructuralCertificate ? _structuralCertNumberController.text.trim() : null
          }
        },
        'utilities': {
          'waterSource': _waterSources.isNotEmpty ? _waterSources : ['Municipal'],
          'electricityConnection': _electricityConnection ?? 'Individual Meters',
          'sewageSystem': _sewageSystem ?? 'Underground Drainage',
          'powerBackup': _powerBackup ?? 'None',
          'rainWaterHarvesting': _rainWaterHarvesting
        },
        'parking': {
          'totalParkingSlots': int.tryParse(_parkingSlotsController.text) ?? 0,
          'parkingType': _parkingTypes.isNotEmpty ? _parkingTypes : ['Open'],
          'twoWheelerParking': _twoWheelerParking,
          'fourWheelerParking': _fourWheelerParking
        },
        'amenities': _selectedAmenities
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
          foregroundColor: AppColors.textOnPrimary,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Basic Building Information
              _buildSectionCard(
                title: '1️⃣ Basic Building Information',
                icon: Icons.business,
                children: [
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
                      labelText: 'Building Code / ID *',
                      prefixIcon: Icon(Icons.tag),
                      border: OutlineInputBorder(),
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
                    items: _buildingCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
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
                    items: _buildingTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (value) => setState(() => _buildingType = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Address
              _buildSectionCard(
                title: '📍 Address',
                icon: Icons.location_on,
                children: [
                  TextFormField(
                    controller: _streetController,
                    decoration: const InputDecoration(
                      labelText: 'Street *',
                      prefixIcon: const Icon(Icons.streetview),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'City *',
                            prefixIcon: Icon(Icons.location_city),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _stateController,
                          decoration: const InputDecoration(
                            labelText: 'State *',
                            prefixIcon: Icon(Icons.map),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                    ],
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
              
              const SizedBox(height: 16),
              
              // Contact
              _buildSectionCard(
                title: '📞 Contact Information',
                icon: Icons.contact_phone,
                children: [
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
              
              const SizedBox(height: 16),
              
              // Structural Details - Expandable
              _buildExpandableSection(
                title: '🏗️ Structural Details',
                icon: Icons.construction,
                children: [
                  DropdownButtonFormField<String>(
                    value: _constructionType,
                    decoration: const InputDecoration(
                      labelText: 'Construction Type',
                      prefixIcon: Icon(Icons.build),
                      border: OutlineInputBorder(),
                    ),
                    items: _constructionTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (value) => setState(() => _constructionType = value),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _plotAreaController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Total Plot Area',
                            prefixIcon: Icon(Icons.square_foot),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: DropdownButtonFormField<String>(
                          value: _plotAreaUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                          items: ['sq.yd', 'sq.m'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (value) => setState(() => _plotAreaUnit = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _builtUpAreaController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Total Built-up Area',
                            prefixIcon: Icon(Icons.home_work),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: DropdownButtonFormField<String>(
                          value: _builtUpAreaUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                          items: ['sq.ft', 'sq.m'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (value) => setState(() => _builtUpAreaUnit = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _blocksController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Number of Blocks',
                            prefixIcon: Icon(Icons.view_module),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _basementsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Number of Basements',
                            prefixIcon: const Icon(Icons.home_work),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: Text(_constructionStartDate == null ? 'Construction Start Date' : 'Start: ${_formatDate(_constructionStartDate!)}'),
                          leading: const Icon(Icons.calendar_today),
                          onTap: () => _selectDate(context, (date) => setState(() => _constructionStartDate = date)),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: Text(_constructionCompletionDate == null ? 'Completion Date' : 'End: ${_formatDate(_constructionCompletionDate!)}'),
                          leading: const Icon(Icons.event),
                          onTap: () => _selectDate(context, (date) => setState(() => _constructionCompletionDate = date)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Safety & Compliance - Expandable
              _buildExpandableSection(
                title: '🛡️ Safety & Compliance',
                icon: Icons.security,
                children: [
                  SwitchListTile(
                    title: const Text('Fire Safety NOC'),
                    value: _hasFireNOC,
                    onChanged: (value) => setState(() => _hasFireNOC = value),
                  ),
                  if (_hasFireNOC) ...[
                    TextFormField(
                      controller: _fireNOCNumberController,
                      decoration: const InputDecoration(
                        labelText: 'NOC Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(_fireNOCExpiry == null ? 'NOC Expiry Date' : 'Expiry: ${_formatDate(_fireNOCExpiry!)}'),
                      leading: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context, (date) => setState(() => _fireNOCExpiry = date)),
                    ),
                  ],
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Lift Safety Certificate'),
                    value: _hasLiftCertificate,
                    onChanged: (value) => setState(() => _hasLiftCertificate = value),
                  ),
                  if (_hasLiftCertificate) ...[
                    TextFormField(
                      controller: _liftCertNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Certificate Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(_liftCertExpiry == null ? 'Certificate Expiry Date' : 'Expiry: ${_formatDate(_liftCertExpiry!)}'),
                      leading: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context, (date) => setState(() => _liftCertExpiry = date)),
                    ),
                  ],
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Structural Stability Certificate'),
                    value: _hasStructuralCertificate,
                    onChanged: (value) => setState(() => _hasStructuralCertificate = value),
                  ),
                  if (_hasStructuralCertificate)
                    TextFormField(
                      controller: _structuralCertNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Certificate Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Utilities & Infrastructure - Expandable
              _buildExpandableSection(
                title: '⚡ Utilities & Infrastructure',
                icon: Icons.bolt,
                children: [
                  const Text('Water Source (Multi-select)', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: _waterSourceOptions.map((source) {
                      final isSelected = _waterSources.contains(source);
                      return FilterChip(
                        label: Text(source),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _waterSources.add(source);
                            } else {
                              _waterSources.remove(source);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _electricityConnection,
                    decoration: const InputDecoration(
                      labelText: 'Electricity Connection',
                      prefixIcon: Icon(Icons.electrical_services),
                      border: OutlineInputBorder(),
                    ),
                    items: _electricityOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                    onChanged: (value) => setState(() => _electricityConnection = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _sewageSystem,
                    decoration: const InputDecoration(
                      labelText: 'Sewage System',
                      prefixIcon: Icon(Icons.water_drop),
                      border: OutlineInputBorder(),
                    ),
                    items: _sewageOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                    onChanged: (value) => setState(() => _sewageSystem = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _powerBackup,
                    decoration: const InputDecoration(
                      labelText: 'Power Backup',
                      prefixIcon: Icon(Icons.power),
                      border: OutlineInputBorder(),
                    ),
                    items: _powerBackupOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                    onChanged: (value) => setState(() => _powerBackup = value),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Rain Water Harvesting'),
                    value: _rainWaterHarvesting,
                    onChanged: (value) => setState(() => _rainWaterHarvesting = value),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Parking - Expandable
              _buildExpandableSection(
                title: '🚗 Parking',
                icon: Icons.local_parking,
                children: [
                  TextFormField(
                    controller: _parkingSlotsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Parking Slots',
                      prefixIcon: const Icon(Icons.local_parking),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Parking Type (Multi-select)', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: _parkingTypeOptions.map((type) {
                      final isSelected = _parkingTypes.contains(type);
                      return FilterChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _parkingTypes.add(type);
                            } else {
                              _parkingTypes.remove(type);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Two-Wheeler Parking'),
                    value: _twoWheelerParking,
                    onChanged: (value) => setState(() => _twoWheelerParking = value),
                  ),
                  SwitchListTile(
                    title: const Text('Four-Wheeler Parking'),
                    value: _fourWheelerParking,
                    onChanged: (value) => setState(() => _fourWheelerParking = value),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Common Amenities - Expandable
              _buildExpandableSection(
                title: '🏊 Common Amenities',
                icon: Icons.spa,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _amenityOptions.map((amenity) {
                      final isSelected = _selectedAmenities.contains(amenity);
                      return FilterChip(
                        label: Text(amenity),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedAmenities.add(amenity);
                            } else {
                              _selectedAmenities.remove(amenity);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Building Configuration
              _buildSectionCard(
                title: '🏢 Building Configuration',
                icon: Icons.layers,
                children: [
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
                          ),
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
                          ),
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
                ],
              ),
              
              const SizedBox(height: 24),
              
              LoadingButton(
                text: 'Create Building',
                isLoading: _isLoading,
                onPressed: _createBuilding,
                icon: Icons.add_business,
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
  
  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

