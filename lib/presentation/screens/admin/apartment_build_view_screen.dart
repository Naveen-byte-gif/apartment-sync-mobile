import '../../../core/imports/app_imports.dart';
import 'flat_details_screen.dart';
import 'create_resident_from_flat_screen.dart';

class ApartmentBuildViewScreen extends StatefulWidget {
  final String? buildingCode;
  
  const ApartmentBuildViewScreen({super.key, this.buildingCode});

  @override
  State<ApartmentBuildViewScreen> createState() => _ApartmentBuildViewScreenState();
}

class _ApartmentBuildViewScreenState extends State<ApartmentBuildViewScreen> {
  Map<String, dynamic>? _buildingData;
  List<Map<String, dynamic>> _allBuildings = [];
  String? _selectedBuildingCode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedBuildingCode = widget.buildingCode;
    _loadAllBuildings();
  }

  Future<void> _loadAllBuildings() async {
    try {
      final response = await ApiService.get(ApiConstants.adminBuildings);
      if (response['success'] == true) {
        setState(() {
          _allBuildings = List<Map<String, dynamic>>.from(response['data']?['buildings'] ?? []);
          if (_selectedBuildingCode == null && _allBuildings.isNotEmpty) {
            _selectedBuildingCode = _allBuildings.first['code'];
          }
        });
        if (_selectedBuildingCode != null) {
          _loadBuildingDetails();
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading buildings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBuildingDetails() async {
    if (_selectedBuildingCode == null) return;
    
    setState(() => _isLoading = true);
    try {
      String buildingUrl = ApiConstants.adminBuildingDetails;
      buildingUrl = ApiConstants.addBuildingCode(buildingUrl, _selectedBuildingCode);
      final response = await ApiService.get(buildingUrl);
      
      if (response['success'] == true) {
        setState(() {
          _buildingData = response['data']?['building'];
        });
      } else {
        AppMessageHandler.showError(context, response['message'] ?? 'Failed to load building details');
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Occupied':
        return AppColors.success;
      case 'Vacant':
        return Colors.grey;
      case 'Maintenance':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Occupied':
        return Icons.check_circle;
      case 'Vacant':
        return Icons.circle_outlined;
      case 'Maintenance':
        return Icons.build;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _getFlatTypeColor(String flatType) {
    switch (flatType) {
      case '1BHK':
        return Colors.blue;
      case '2BHK':
        return Colors.green;
      case '3BHK':
        return Colors.orange;
      case '4BHK':
        return Colors.purple;
      case 'Duplex':
        return Colors.red;
      case 'Penthouse':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apartment Build View'),
        actions: [
          if (_allBuildings.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.apartment),
              onSelected: (String code) {
                setState(() {
                  _selectedBuildingCode = code;
                });
                _loadBuildingDetails();
              },
              itemBuilder: (BuildContext context) {
                return _allBuildings.map((building) {
                  return PopupMenuItem<String>(
                    value: building['code'],
                    child: Text(building['name'] ?? building['code']),
                  );
                }).toList();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildingData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.apartment, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No building selected',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBuildingDetails,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Building Header
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _buildingData!['name'] ?? 'Building',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Code: ${_buildingData!['code'] ?? 'N/A'}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (_buildingData!['statistics'] != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _StatChip(
                                        label: 'Total',
                                        value: '${_buildingData!['statistics']['totalFlats'] ?? 0}',
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      _StatChip(
                                        label: 'Occupied',
                                        value: '${_buildingData!['statistics']['occupiedFlats'] ?? 0}',
                                        color: AppColors.success,
                                      ),
                                      const SizedBox(width: 8),
                                      _StatChip(
                                        label: 'Vacant',
                                        value: '${_buildingData!['statistics']['vacantFlats'] ?? 0}',
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Floors
                        if (_buildingData!['floors'] != null)
                          ...(_buildingData!['floors'] as List).map((floor) {
                            return _FloorSection(
                              floor: floor,
                              buildingCode: _selectedBuildingCode!,
                              onFlatTap: (flat) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FlatDetailsScreen(
                                      buildingCode: _selectedBuildingCode!,
                                      floorNumber: floor['floorNumber'],
                                      flatNumber: flat['flatNumber'],
                                    ),
                                  ),
                                ).then((_) => _loadBuildingDetails());
                              },
                              onCreateResident: (flat) {
                                if (flat['status'] == 'Vacant') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CreateResidentFromFlatScreen(
                                        buildingCode: _selectedBuildingCode!,
                                        floorNumber: floor['floorNumber'],
                                        flatNumber: flat['flatNumber'],
                                        flatType: flat['flatType'],
                                      ),
                                    ),
                                  ).then((_) => _loadBuildingDetails());
                                } else {
                                  AppMessageHandler.showError(
                                    context,
                                    'This flat is already occupied. Please select a vacant flat.',
                                  );
                                }
                              },
                              getStatusColor: _getStatusColor,
                              getStatusIcon: _getStatusIcon,
                              getFlatTypeColor: _getFlatTypeColor,
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloorSection extends StatelessWidget {
  final Map<String, dynamic> floor;
  final String buildingCode;
  final Function(Map<String, dynamic>) onFlatTap;
  final Function(Map<String, dynamic>) onCreateResident;
  final Color Function(String) getStatusColor;
  final IconData Function(String) getStatusIcon;
  final Color Function(String) getFlatTypeColor;

  const _FloorSection({
    required this.floor,
    required this.buildingCode,
    required this.onFlatTap,
    required this.onCreateResident,
    required this.getStatusColor,
    required this.getStatusIcon,
    required this.getFlatTypeColor,
  });

  @override
  Widget build(BuildContext context) {
    final flats = List<Map<String, dynamic>>.from(floor['flats'] ?? []);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${floor['floorNumber']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        title: Text(
          'Floor ${floor['floorNumber']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${flats.length} flats'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: flats.length,
              itemBuilder: (context, index) {
                final flat = flats[index];
                final status = flat['status'] ?? 'Vacant';
                final statusColor = getStatusColor(status);
                final statusIcon = getStatusIcon(status);
                final flatTypeColor = getFlatTypeColor(flat['flatType'] ?? '');
                
                return InkWell(
                  onTap: () => onFlatTap(flat),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: flatTypeColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                flat['flatType'] ?? '',
                                style: TextStyle(
                                  color: flatTypeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            Icon(
                              statusIcon,
                              color: statusColor,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          flat['flatNumber'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (status == 'Vacant') ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => onCreateResident(flat),
                            icon: const Icon(Icons.person_add, size: 16),
                            label: const Text('Add Resident'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

