import '../../../core/imports/app_imports.dart';
import 'dart:convert';

class BuildingDetailsScreen extends StatefulWidget {
  final String? buildingCode;
  
  const BuildingDetailsScreen({super.key, this.buildingCode});

  @override
  State<BuildingDetailsScreen> createState() => _BuildingDetailsScreenState();
}

class _BuildingDetailsScreenState extends State<BuildingDetailsScreen> {
  Map<String, dynamic>? _buildingData;
  List<Map<String, dynamic>> _allBuildings = [];
  String? _selectedBuildingCode;
  bool _isLoading = true;
  bool _showAllBuildings = true;

  @override
  void initState() {
    super.initState();
    _selectedBuildingCode = widget.buildingCode;
    _loadAllBuildings();
    _setupSocketListeners();
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

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for building details');
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          final buildingCode = widget.buildingCode;
          socketService.connect(userId);

          // Listen for flat status updates (only for current building)
          socketService.on('flat_status_updated', (data) {
            print('📡 [FLUTTER] Flat status updated event received');
            if (mounted && (buildingCode == null || data['flat']?['buildingCode'] == buildingCode)) {
              _loadBuildingDetails();
              AppMessageHandler.showInfo(context, 'Flat status updated');
            }
          });

          // Listen for building updates
          socketService.on('building_updated', (data) {
            print('📡 [FLUTTER] Building updated event received');
            if (mounted && (buildingCode == null || data['building']?['code'] == buildingCode)) {
              _loadBuildingDetails();
            }
          });

          // Listen for user creation (affects flat occupancy)
          socketService.on('user_created', (data) {
            print('📡 [FLUTTER] User created event received');
            if (mounted) {
              _loadBuildingDetails();
            }
          });
        }
      } catch (e) {
        print('❌ [FLUTTER] Error setting up socket: $e');
      }
    }
  }

  Future<void> _loadBuildingDetails() async {
    if (_selectedBuildingCode == null) return;
    
    print('🖱️ [FLUTTER] Loading building details...');
    setState(() => _isLoading = true);
    try {
      String buildingUrl = ApiConstants.adminBuildingDetails;
      buildingUrl = ApiConstants.addBuildingCode(buildingUrl, _selectedBuildingCode);
      final response = await ApiService.get(buildingUrl);
      print('✅ [FLUTTER] Building details response received');
      
      if (response['success'] == true) {
        print('🏢 [FLUTTER] Building data loaded successfully');
        setState(() {
          _buildingData = response['data']?['building'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading building details: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessageHandler.handleError(context, e);
      }
    }
  }

  void _selectBuilding(String buildingCode) {
    setState(() {
      _selectedBuildingCode = buildingCode;
      _showAllBuildings = false;
    });
    _loadBuildingDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Building Details'),
            if (_allBuildings.isNotEmpty)
              Text(
                '${_allBuildings.length} Building${_allBuildings.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: AppColors.primary,
        actions: [
          if (_showAllBuildings && _allBuildings.length > 1)
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'View All Buildings',
              onPressed: () {
                setState(() => _showAllBuildings = true);
              },
            ),
          if (!_showAllBuildings)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadBuildingDetails();
              },
            ),
          if (!_showAllBuildings && _allBuildings.length > 1)
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'View All Buildings',
              onPressed: () {
                setState(() => _showAllBuildings = true);
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showAllBuildings && _allBuildings.isNotEmpty
              ? _buildAllBuildingsList()
              : _buildingData == null
                  ? _buildNoBuildingView()
                  : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _buildingData!['name'] ?? 'N/A',
                                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Code: ${_buildingData!['code'] ?? 'N/A'}',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_buildingData!['buildingCategory'] != null || _buildingData!['buildingType'] != null) ...[
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 12),
                                if (_buildingData!['buildingCategory'] != null)
                                  _InfoRow(
                                    icon: Icons.category,
                                    label: 'Category',
                                    value: _buildingData!['buildingCategory'],
                                  ),
                                if (_buildingData!['buildingType'] != null)
                                  _InfoRow(
                                    icon: Icons.apartment,
                                    label: 'Type',
                                    value: _buildingData!['buildingType'],
                                  ),
                              ],
                              if (_buildingData!['address'] != null) ...[
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 12),
                                _InfoRow(
                                  icon: Icons.location_on,
                                  label: 'Address',
                                  value: _formatAddress(_buildingData!['address']),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Statistics Card
                      if (_buildingData!['statistics'] != null)
                        Card(
                          elevation: 4,
                          color: AppColors.primary.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _StatItem(
                                  label: 'Total Flats',
                                  value: '${_buildingData!['statistics']['totalFlats'] ?? 0}',
                                  color: AppColors.primary,
                                ),
                                _StatItem(
                                  label: 'Occupied',
                                  value: '${_buildingData!['statistics']['occupiedFlats'] ?? 0}',
                                  color: AppColors.success,
                                ),
                                _StatItem(
                                  label: 'Vacant',
                                  value: '${_buildingData!['statistics']['vacantFlats'] ?? 0}',
                                  color: AppColors.warning,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Structural Details
                      if (_buildingData!['structuralDetails'] != null)
                        _buildExpandableCard(
                          title: '🏗️ Structural Details',
                          icon: Icons.construction,
                          children: _buildStructuralDetails(_buildingData!['structuralDetails']),
                        ),
                      const SizedBox(height: 16),
                      // Safety & Compliance
                      if (_buildingData!['safetyCompliance'] != null)
                        _buildExpandableCard(
                          title: '🛡️ Safety & Compliance',
                          icon: Icons.security,
                          children: _buildSafetyCompliance(_buildingData!['safetyCompliance']),
                        ),
                      const SizedBox(height: 16),
                      // Utilities & Infrastructure
                      if (_buildingData!['utilities'] != null)
                        _buildExpandableCard(
                          title: '⚡ Utilities & Infrastructure',
                          icon: Icons.bolt,
                          children: _buildUtilities(_buildingData!['utilities']),
                        ),
                      const SizedBox(height: 16),
                      // Parking
                      if (_buildingData!['parking'] != null)
                        _buildExpandableCard(
                          title: '🚗 Parking',
                          icon: Icons.local_parking,
                          children: _buildParking(_buildingData!['parking']),
                        ),
                      const SizedBox(height: 16),
                      // Common Amenities
                      if (_buildingData!['amenities'] != null && (_buildingData!['amenities'] as List).isNotEmpty)
                        _buildExpandableCard(
                          title: '🏊 Common Amenities',
                          icon: Icons.spa,
                          children: _buildAmenities(_buildingData!['amenities']),
                        ),
                      const SizedBox(height: 16),
                      // Floors and Flats
                      Text(
                        'Floors & Flats',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_buildingData!['floors'] != null)
                        ...(_buildingData!['floors'] as List).map((floor) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  '${floor['floorNumber']}',
                                  style: const TextStyle(
                                    color: AppColors.textOnPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                'Floor ${floor['floorNumber']}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${floor['flats']?.length ?? 0} flats',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (floor['flats'] as List).map((flat) {
                                      final isOccupied = flat['isOccupied'] == true;
                                      return Container(
                                        width: 110,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isOccupied
                                              ? AppColors.error.withOpacity(0.1)
                                              : AppColors.success.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isOccupied
                                                ? AppColors.error.withOpacity(0.3)
                                                : AppColors.success.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              flat['flatNumber'] ?? 'N/A',
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isOccupied
                                                    ? AppColors.error
                                                    : AppColors.success,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              flat['flatType'] ?? 'N/A',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            if (isOccupied && flat['occupiedBy'] != null) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.secondary.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  flat['occupiedBy']['fullName'] ?? '',
                                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                    color: AppColors.textSecondary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAllBuildingsList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          Card(
            elevation: 4,
            color: AppColors.primary.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.business, color: AppColors.textOnPrimary, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Buildings',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${_allBuildings.length}',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'All Buildings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ..._allBuildings.map((building) => _buildBuildingCard(building)),
        ],
      ),
    );
  }

  Widget _buildBuildingCard(Map<String, dynamic> building) {
    final isSelected = building['code'] == _selectedBuildingCode;
    return Card(
      elevation: isSelected ? 6 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: isSelected ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: () => _selectBuilding(building['code']),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                    child: Icon(
                      Icons.apartment,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          building['name'] ?? 'Unknown',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${building['code'] ?? 'N/A'}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: AppColors.textOnPrimary,
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BuildingStatItem(
                      icon: Icons.layers,
                      label: 'Floors',
                      value: '${building['totalFloors'] ?? 0}',
                    ),
                  ),
                  Expanded(
                    child: _BuildingStatItem(
                      icon: Icons.home,
                      label: 'Total Flats',
                      value: '${building['totalFlats'] ?? 0}',
                    ),
                  ),
                  Expanded(
                    child: _BuildingStatItem(
                      icon: Icons.person,
                      label: 'Occupied',
                      value: '${building['occupiedFlats'] ?? 0}',
                      color: AppColors.success,
                    ),
                  ),
                  Expanded(
                    child: _BuildingStatItem(
                      icon: Icons.home_outlined,
                      label: 'Vacant',
                      value: '${building['vacantFlats'] ?? 0}',
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              if (building['occupancyRate'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (building['occupancyRate'] ?? 0) / 100,
                        backgroundColor: AppColors.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          building['occupancyRate']! >= 80
                              ? AppColors.success
                              : building['occupancyRate']! >= 50
                                  ? AppColors.warning
                                  : AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${building['occupancyRate']?.toStringAsFixed(1) ?? '0'}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoBuildingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.apartment_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Building Selected',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a building to view details',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAddress(Map<String, dynamic> address) {
    final parts = <String>[];
    if (address['street'] != null) parts.add(address['street']);
    if (address['city'] != null) parts.add(address['city']);
    if (address['state'] != null) parts.add(address['state']);
    if (address['pincode'] != null) parts.add(address['pincode']);
    return parts.join(', ');
  }
  
  Widget _buildExpandableCard({
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
  
  List<Widget> _buildStructuralDetails(Map<String, dynamic> details) {
    return [
      if (details['constructionType'] != null)
        _InfoRow(
          icon: Icons.build,
          label: 'Construction Type',
          value: details['constructionType'],
        ),
      if (details['totalPlotArea'] != null && details['totalPlotArea']['value'] != null)
        _InfoRow(
          icon: Icons.square_foot,
          label: 'Total Plot Area',
          value: '${details['totalPlotArea']['value']} ${details['totalPlotArea']['unit'] ?? 'sq.yd'}',
        ),
      if (details['totalBuiltUpArea'] != null && details['totalBuiltUpArea']['value'] != null)
        _InfoRow(
          icon: Icons.home_work,
          label: 'Total Built-up Area',
          value: '${details['totalBuiltUpArea']['value']} ${details['totalBuiltUpArea']['unit'] ?? 'sq.ft'}',
        ),
      if (details['numberOfBlocks'] != null)
        _InfoRow(
          icon: Icons.view_module,
          label: 'Number of Blocks',
          value: '${details['numberOfBlocks']}',
        ),
      if (details['numberOfBasements'] != null)
        _InfoRow(
          icon: Icons.home_work,
          label: 'Number of Basements',
          value: '${details['numberOfBasements']}',
        ),
      if (details['buildingAge'] != null)
        _InfoRow(
          icon: Icons.calendar_today,
          label: 'Building Age',
          value: '${details['buildingAge']} years',
        ),
    ];
  }
  
  List<Widget> _buildSafetyCompliance(Map<String, dynamic> compliance) {
    return [
      if (compliance['fireSafetyNOC'] != null) ...[
        _InfoRow(
          icon: Icons.local_fire_department,
          label: 'Fire Safety NOC',
          value: compliance['fireSafetyNOC']['hasNOC'] == true ? 'Yes' : 'No',
        ),
        if (compliance['fireSafetyNOC']['hasNOC'] == true && compliance['fireSafetyNOC']['nocNumber'] != null)
          _InfoRow(
            icon: Icons.tag,
            label: 'NOC Number',
            value: compliance['fireSafetyNOC']['nocNumber'],
          ),
      ],
      if (compliance['liftSafetyCertificate'] != null) ...[
        _InfoRow(
          icon: Icons.elevator,
          label: 'Lift Safety Certificate',
          value: compliance['liftSafetyCertificate']['hasCertificate'] == true ? 'Yes' : 'No',
        ),
        if (compliance['liftSafetyCertificate']['hasCertificate'] == true && compliance['liftSafetyCertificate']['certificateNumber'] != null)
          _InfoRow(
            icon: Icons.tag,
            label: 'Certificate Number',
            value: compliance['liftSafetyCertificate']['certificateNumber'],
          ),
      ],
      if (compliance['structuralStabilityCertificate'] != null) ...[
        _InfoRow(
          icon: Icons.architecture,
          label: 'Structural Stability Certificate',
          value: compliance['structuralStabilityCertificate']['hasCertificate'] == true ? 'Yes' : 'No',
        ),
        if (compliance['structuralStabilityCertificate']['hasCertificate'] == true && compliance['structuralStabilityCertificate']['certificateNumber'] != null)
          _InfoRow(
            icon: Icons.tag,
            label: 'Certificate Number',
            value: compliance['structuralStabilityCertificate']['certificateNumber'],
          ),
      ],
    ];
  }
  
  List<Widget> _buildUtilities(Map<String, dynamic> utilities) {
    return [
      if (utilities['waterSource'] != null && (utilities['waterSource'] as List).isNotEmpty)
        _InfoRow(
          icon: Icons.water_drop,
          label: 'Water Source',
          value: (utilities['waterSource'] as List).join(', '),
        ),
      if (utilities['electricityConnection'] != null)
        _InfoRow(
          icon: Icons.electrical_services,
          label: 'Electricity Connection',
          value: utilities['electricityConnection'],
        ),
      if (utilities['sewageSystem'] != null)
        _InfoRow(
          icon: Icons.water,
          label: 'Sewage System',
          value: utilities['sewageSystem'],
        ),
      if (utilities['powerBackup'] != null)
        _InfoRow(
          icon: Icons.power,
          label: 'Power Backup',
          value: utilities['powerBackup'],
        ),
      if (utilities['rainWaterHarvesting'] != null)
        _InfoRow(
          icon: Icons.water,
          label: 'Rain Water Harvesting',
          value: utilities['rainWaterHarvesting'] == true ? 'Yes' : 'No',
        ),
    ];
  }
  
  List<Widget> _buildParking(Map<String, dynamic> parking) {
    return [
      if (parking['totalParkingSlots'] != null)
        _InfoRow(
          icon: Icons.local_parking,
          label: 'Total Parking Slots',
          value: '${parking['totalParkingSlots']}',
        ),
      if (parking['parkingType'] != null && (parking['parkingType'] as List).isNotEmpty)
        _InfoRow(
          icon: Icons.local_parking,
          label: 'Parking Type',
          value: (parking['parkingType'] as List).join(', '),
        ),
      if (parking['twoWheelerParking'] != null)
        _InfoRow(
          icon: Icons.two_wheeler,
          label: 'Two-Wheeler Parking',
          value: parking['twoWheelerParking'] == true ? 'Yes' : 'No',
        ),
      if (parking['fourWheelerParking'] != null)
        _InfoRow(
          icon: Icons.directions_car,
          label: 'Four-Wheeler Parking',
          value: parking['fourWheelerParking'] == true ? 'Yes' : 'No',
        ),
    ];
  }
  
  List<Widget> _buildAmenities(List<dynamic> amenities) {
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: amenities.map((amenity) {
          return Chip(
            label: Text(amenity.toString()),
            backgroundColor: AppColors.primary.withOpacity(0.1),
            labelStyle: TextStyle(color: AppColors.primary),
          );
        }).toList(),
      ),
    ];
  }
}

class _BuildingStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _BuildingStatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

