import '../../../core/imports/app_imports.dart';

class VisitorEntryScreen extends StatefulWidget {
  final String buildingCode;
  final String buildingName;

  const VisitorEntryScreen({
    super.key,
    required this.buildingCode,
    required this.buildingName,
  });

  @override
  State<VisitorEntryScreen> createState() => _VisitorEntryScreenState();
}

class _VisitorEntryScreenState extends State<VisitorEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _visitorNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();

  int? _selectedFloor;
  String? _selectedFlatNumber;
  String? _selectedPurpose;
  bool _isLoading = false;

  List<Map<String, dynamic>> _floors = [];
  List<Map<String, dynamic>> _flats = [];
  bool _isLoadingFloors = true;

  final List<String> _purposes = ['Guest', 'Delivery', 'Maintenance', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadBuildingStructure();
  }

  @override
  void dispose() {
    _visitorNameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadBuildingStructure() async {
    setState(() => _isLoadingFloors = true);
    try {
      final endpoint = ApiConstants.addBuildingCode(
        ApiConstants.adminBuildingDetails,
        widget.buildingCode,
      );
      final response = await ApiService.get(endpoint);

      if (response['success'] == true) {
        final floors = response['data']?['building']?['floors'] as List? ?? [];
        setState(() {
          _floors = List<Map<String, dynamic>>.from(floors);
        });
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoadingFloors = false);
      }
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
        _flats = List<Map<String, dynamic>>.from(floor['flats'] ?? []);
      }
    });
  }

  Future<void> _submitVisitorEntry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFloor == null ||
        _selectedFlatNumber == null ||
        _selectedPurpose == null) {
      AppMessageHandler.showError(context, 'Please fill all required fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Find resident for the selected flat - need to get from building details
      // For now, we'll use the flat's occupiedBy info from the building structure
      final flat = _flats.firstWhere(
        (f) => f['flatNumber'] == _selectedFlatNumber,
        orElse: () => {},
      );

      // Check if flat is occupied
      if (flat['isOccupied'] != true || flat['occupiedBy'] == null) {
        AppMessageHandler.showError(
          context,
          'This flat is not occupied. Please select an occupied flat.',
        );
        return;
      }

      // Get resident ID from occupiedBy
      final residentId = flat['occupiedBy'] is Map
          ? flat['occupiedBy']['userId']
          : flat['occupiedBy'];

      if (residentId == null) {
        AppMessageHandler.showError(
          context,
          'Resident information not found for this flat.',
        );
        return;
      }

      final response = await ApiService.post(ApiConstants.visitors, {
        'visitorName': _visitorNameController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'visitorType': _selectedPurpose == 'Delivery'
            ? 'Delivery Partner'
            : 'Guest',
        'purpose': _selectedPurpose!,
        'hostResidentId': residentId,
        'flatNumber': _selectedFlatNumber,
        'floorNumber': _selectedFloor,
        'apartmentCode': widget.buildingCode,
      });

      if (mounted) {
        final statusCode = response['_statusCode'] as int?;
        AppMessageHandler.handleResponse(
          context,
          response,
          statusCode: statusCode,
          showDialog: true,
          onSuccess: () {
            // Reset form
            _visitorNameController.clear();
            _phoneNumberController.clear();
            _emailController.clear();
            setState(() {
              _selectedFloor = null;
              _selectedFlatNumber = null;
              _selectedPurpose = null;
              _flats = [];
            });
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
      appBar: AppBar(title: const Text('Visitor Entry')),
      body: _isLoadingFloors
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Building Info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.apartment,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.buildingName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    widget.buildingCode,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Floor Selection
                    Text(
                      'Floor *',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedFloor,
                      decoration: const InputDecoration(
                        labelText: 'Select Floor',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.layers),
                      ),
                      items: _floors.map((floor) {
                        return DropdownMenuItem<int>(
                          value: floor['floorNumber'] as int,
                          child: Text('Floor ${floor['floorNumber']}'),
                        );
                      }).toList(),
                      onChanged: _onFloorSelected,
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a floor';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Flat Selection
                    Text(
                      'Flat *',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedFlatNumber,
                      decoration: const InputDecoration(
                        labelText: 'Select Flat',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                      items: _flats.map((flat) {
                        final isOccupied = flat['isOccupied'] == true;
                        return DropdownMenuItem<String>(
                          value: flat['flatNumber'] as String?,
                          child: Row(
                            children: [
                              Text('Flat ${flat['flatNumber']}'),
                              if (!isOccupied)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    '(Vacant)',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedFlatNumber = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a flat';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Visitor Details
                    Text(
                      'Visitor Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _visitorNameController,
                      decoration: const InputDecoration(
                        labelText: 'Visitor Name *',
                        hintText: 'Enter visitor name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter visitor name';
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
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
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
                        labelText: 'Email (Optional)',
                        hintText: 'Enter email address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    // Purpose
                    Text(
                      'Purpose *',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedPurpose,
                      decoration: const InputDecoration(
                        labelText: 'Select Purpose',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                      ),
                      items: _purposes.map((purpose) {
                        return DropdownMenuItem(
                          value: purpose,
                          child: Text(purpose),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedPurpose = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a purpose';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitVisitorEntry,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Submit Entry',
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
