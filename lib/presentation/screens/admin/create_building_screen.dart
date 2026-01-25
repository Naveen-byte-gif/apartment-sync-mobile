import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import 'admin_dashboard_screen.dart';

class CreateBuildingScreen extends StatefulWidget {
  const CreateBuildingScreen({super.key});

  @override
  State<CreateBuildingScreen> createState() => _CreateBuildingScreenState();
}

class _CreateBuildingScreenState extends State<CreateBuildingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _totalFloorsController = TextEditingController(text: '5');
  final _flatsPerFloorController = TextEditingController(text: '4');
  final _totalFlatsController = TextEditingController();
  bool _useVariableFlatsPerFloor =
      false; // Toggle for variable vs uniform flats per floor
  final Map<int, int> _flatsPerFloorMap = {}; // Floor number -> flats count
  bool _isLoading = false;

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
    _totalFlatsController.dispose();
    super.dispose();
  }

  Future<void> _createBuilding() async {
    print('🖱️ [FLUTTER] Create Building button clicked');
    if (!_formKey.currentState!.validate()) {
      print('❌ [FLUTTER] Form validation failed');
      return;
    }

    int totalFloors;
    Map<String, dynamic> buildingConfig = {};

    if (_useVariableFlatsPerFloor) {
      // Variable flats per floor mode
      totalFloors = int.tryParse(_totalFloorsController.text) ?? 0;
      if (totalFloors < 1 || totalFloors > 100) {
        AppMessageHandler.showError(
          context,
          'Total floors must be between 1 and 100',
        );
        return;
      }

      final totalFlats = int.tryParse(_totalFlatsController.text);
      if (totalFlats == null || totalFlats < 1) {
        AppMessageHandler.showError(context, 'Please enter valid total flats');
        return;
      }

      // Build flats per floor list
      List<int> flatsPerFloorList = [];
      int calculatedTotal = 0;
      for (int floorNum = 1; floorNum <= totalFloors; floorNum++) {
        final flatsCount = _flatsPerFloorMap[floorNum] ?? 0;
        if (flatsCount < 1 || flatsCount > 50) {
          AppMessageHandler.showError(
            context,
            'Floor $floorNum: Flats must be between 1 and 50',
          );
          return;
        }
        flatsPerFloorList.add(flatsCount);
        calculatedTotal += flatsCount;
      }

      // Validate total matches
      if (calculatedTotal != totalFlats) {
        AppMessageHandler.showError(
          context,
          'Sum of flats per floor ($calculatedTotal) must equal total flats ($totalFlats)',
        );
        return;
      }

      buildingConfig = {
        'totalFlats': totalFlats,
        'flatsPerFloorList': flatsPerFloorList,
      };

      print('📋 [FLUTTER] Building Data (Variable Mode):');
      print('  - Total Flats: $totalFlats');
      print('  - Total Floors: $totalFloors');
      print('  - Flats per Floor List: $flatsPerFloorList');
    } else {
      // Uniform flats per floor mode (existing)
      totalFloors = int.tryParse(_totalFloorsController.text) ?? 5;
      final flatsPerFloor = int.tryParse(_flatsPerFloorController.text) ?? 4;

      if (totalFloors < 1 || totalFloors > 100) {
        AppMessageHandler.showError(
          context,
          'Total floors must be between 1 and 100',
        );
        return;
      }

      if (flatsPerFloor < 1 || flatsPerFloor > 50) {
        AppMessageHandler.showError(
          context,
          'Flats per floor must be between 1 and 50',
        );
        return;
      }

      buildingConfig = {
        'totalFloors': totalFloors,
        'flatsPerFloor': flatsPerFloor,
      };

      print('📋 [FLUTTER] Building Data (Uniform Mode):');
      print('  - Total Floors: $totalFloors');
      print('  - Flats per Floor: $flatsPerFloor');
    }

    print('  - Name: ${_nameController.text}');
    print('  - Code: ${_codeController.text}');

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post(ApiConstants.adminBuildings, {
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim().toUpperCase(),
        ...buildingConfig,
        'address': {
          'street': _streetController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'pincode': _pincodeController.text.trim(),
          'country': 'India',
        },
        'contact': {
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'managerName': _managerNameController.text.trim(),
        },
      });

      print('✅ [FLUTTER] Building creation response received');
      print('📦 [FLUTTER] Response: ${response.toString()}');

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Creating building...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Create Building',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textOnPrimary,
            ),
          ),
          backgroundColor: AppColors.primary,
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.background],
              stops: [0.0, 0.15],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Building Structure Configuration Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.apartment,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Building Structure',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Toggle for variable flats per floor
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Variable Flats per Floor',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _useVariableFlatsPerFloor,
                                  onChanged: (value) {
                                    setState(() {
                                      _useVariableFlatsPerFloor = value;
                                      if (value) {
                                        // Initialize floors map when switching to variable mode
                                        final totalFloors =
                                            int.tryParse(
                                              _totalFloorsController.text,
                                            ) ??
                                            5;
                                        for (int i = 1; i <= totalFloors; i++) {
                                          _flatsPerFloorMap[i] =
                                              _flatsPerFloorMap[i] ?? 2;
                                        }
                                      }
                                    });
                                  },
                                  activeColor: AppColors.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_useVariableFlatsPerFloor) ...[
                              // Variable mode: Total flats + per-floor configuration
                              TextFormField(
                                controller: _totalFlatsController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Total Flats *',
                                  hintText: 'e.g., 6',
                                  prefixIcon: const Icon(Icons.home_work),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  helperText:
                                      'Total number of flats across all floors',
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (value) {
                                  if (_useVariableFlatsPerFloor) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    final num = int.tryParse(value);
                                    if (num == null || num < 1) {
                                      return 'Must be > 0';
                                    }
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Per-floor flats configuration
                              Builder(
                                builder: (context) {
                                  final totalFloors =
                                      int.tryParse(
                                        _totalFloorsController.text,
                                      ) ??
                                      5;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Configure Flats per Floor:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ...List.generate(totalFloors, (index) {
                                        final floorNum = index + 1;
                                        final currentCount =
                                            _flatsPerFloorMap[floorNum] ?? 2;

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 80,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'Floor $floorNum',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons
                                                            .remove_circle_outline,
                                                      ),
                                                      onPressed: () {
                                                        if (currentCount > 1) {
                                                          setState(() {
                                                            _flatsPerFloorMap[floorNum] =
                                                                currentCount -
                                                                1;
                                                          });
                                                        }
                                                      },
                                                      color: AppColors.primary,
                                                    ),
                                                    Container(
                                                      width: 60,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              AppColors.border,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '$currentCount',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons
                                                            .add_circle_outline,
                                                      ),
                                                      onPressed: () {
                                                        if (currentCount < 50) {
                                                          setState(() {
                                                            _flatsPerFloorMap[floorNum] =
                                                                currentCount +
                                                                1;
                                                          });
                                                        }
                                                      },
                                                      color: AppColors.primary,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 12),
                                      Builder(
                                        builder: (context) {
                                          final calculatedTotal =
                                              _flatsPerFloorMap.values.fold(
                                                0,
                                                (sum, count) => sum + count,
                                              );
                                          final totalFlats =
                                              int.tryParse(
                                                _totalFlatsController.text,
                                              ) ??
                                              0;
                                          return Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color:
                                                  calculatedTotal ==
                                                          totalFlats &&
                                                      totalFlats > 0
                                                  ? AppColors.success
                                                        .withOpacity(0.1)
                                                  : AppColors.warning
                                                        .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color:
                                                    calculatedTotal ==
                                                            totalFlats &&
                                                        totalFlats > 0
                                                    ? AppColors.success
                                                          .withOpacity(0.3)
                                                    : AppColors.warning
                                                          .withOpacity(0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  calculatedTotal ==
                                                              totalFlats &&
                                                          totalFlats > 0
                                                      ? Icons.check_circle
                                                      : Icons.info_outline,
                                                  color:
                                                      calculatedTotal ==
                                                              totalFlats &&
                                                          totalFlats > 0
                                                      ? AppColors.success
                                                      : AppColors.warning,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Sum: $calculatedTotal / Total: $totalFlats',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          calculatedTotal ==
                                                                  totalFlats &&
                                                              totalFlats > 0
                                                          ? AppColors.success
                                                          : AppColors.warning,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ] else ...[
                              // Uniform mode: Total floors + flats per floor
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _totalFloorsController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Total Floors *',
                                        hintText: 'e.g., 5',
                                        prefixIcon: const Icon(Icons.layers),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                      validator: (value) {
                                        if (!_useVariableFlatsPerFloor) {
                                          if (value == null || value.isEmpty) {
                                            return 'Required';
                                          }
                                          final num = int.tryParse(value);
                                          if (num == null ||
                                              num < 1 ||
                                              num > 100) {
                                            return '1-100';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _flatsPerFloorController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Flats per Floor *',
                                        hintText: 'e.g., 4',
                                        prefixIcon: const Icon(Icons.home),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: AppColors.surface,
                                      ),
                                      validator: (value) {
                                        if (!_useVariableFlatsPerFloor) {
                                          if (value == null || value.isEmpty) {
                                            return 'Required';
                                          }
                                          final num = int.tryParse(value);
                                          if (num == null ||
                                              num < 1 ||
                                              num > 50) {
                                            return '1-50';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Builder(
                                builder: (context) {
                                  final totalFloors =
                                      int.tryParse(
                                        _totalFloorsController.text,
                                      ) ??
                                      5;
                                  final flatsPerFloor =
                                      int.tryParse(
                                        _flatsPerFloorController.text,
                                      ) ??
                                      4;
                                  final totalFlats =
                                      totalFloors * flatsPerFloor;
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.info.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calculate,
                                          color: AppColors.info,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Total Flats: $totalFlats',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.info,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                            if (!_useVariableFlatsPerFloor) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.info.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: AppColors.info,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Flat codes will be auto-generated based on building name and flat numbers.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
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
                    ),
                    const SizedBox(height: 16),
                    // Building Info Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Building Information',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Building Name *',
                                prefixIcon: const Icon(Icons.business),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter building name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _codeController,
                              decoration: InputDecoration(
                                labelText: 'Building Code *',
                                hintText: 'e.g., APT001',
                                prefixIcon: const Icon(Icons.qr_code),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter building code';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Address Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Address',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _streetController,
                              decoration: InputDecoration(
                                labelText: 'Street *',
                                prefixIcon: const Icon(Icons.location_on),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter street';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cityController,
                                    decoration: InputDecoration(
                                      labelText: 'City *',
                                      prefixIcon: const Icon(
                                        Icons.location_city,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: AppColors.surface,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _stateController,
                                    decoration: InputDecoration(
                                      labelText: 'State *',
                                      prefixIcon: const Icon(Icons.map),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: AppColors.surface,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _pincodeController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Pincode *',
                                prefixIcon: const Icon(Icons.pin),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter pincode';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Contact Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contact Information',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Phone',
                                prefixIcon: const Icon(Icons.phone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _managerNameController,
                              decoration: InputDecoration(
                                labelText: 'Manager Name',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Create Button
                    LoadingButton(
                      text: 'Create Building',
                      isLoading: _isLoading,
                      onPressed: _createBuilding,
                      icon: Icons.add_business,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
