import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/imports/app_imports.dart';
import 'flat_details_screen.dart';

class BuildingView3DScreen extends StatefulWidget {
  final String? buildingCode;
  
  const BuildingView3DScreen({super.key, this.buildingCode});

  @override
  State<BuildingView3DScreen> createState() => _BuildingView3DScreenState();
}

class _BuildingView3DScreenState extends State<BuildingView3DScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _buildingData;
  bool _isLoading = true;
  bool _is3DView = true;
  String? _selectedBlock;
  int? _selectedFloor;
  String? _searchQuery;
  String? _filterStatus; // 'all', 'occupied', 'vacant', 'has_complaints', 'pending_dues'
  
  // Animation controllers
  late AnimationController _zoomController;
  late AnimationController _expandController;
  late Animation<double> _zoomAnimation;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _zoomAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeInOut),
    );
    _expandAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _expandController, curve: Curves.easeInOut),
    );
    _loadBuildingView();
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  Future<void> _loadBuildingView() async {
    setState(() => _isLoading = true);
    try {
      String endpoint = ApiConstants.adminBuildingView;
      if (widget.buildingCode != null) {
        endpoint += '?buildingCode=${widget.buildingCode}';
      }
      final response = await ApiService.get(endpoint);
      
      if (response['success'] == true) {
        setState(() {
          _buildingData = response['data'];
        });
      } else {
        AppMessageHandler.showError(context, response['message'] ?? 'Failed to load building');
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getFlatStatusColor(String status) {
    switch (status) {
      case 'occupied':
        return AppColors.success;
      case 'vacant':
        return Colors.grey.shade400;
      case 'has_complaints':
        return AppColors.warning;
      case 'pending_dues':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _getFilteredFloors() {
    if (_buildingData == null || _buildingData!['building'] == null) return [];
    
    List<Map<String, dynamic>> floors = List<Map<String, dynamic>>.from(
      _buildingData!['building']['floors'] ?? []
    );

    // Apply search filter
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      floors = floors.map((floor) {
        final filteredFlats = (floor['flats'] as List).where((flat) {
          final flatNum = flat['flatNumber']?.toString().toLowerCase() ?? '';
          final ownerName = flat['occupiedBy']?['fullName']?.toString().toLowerCase() ?? '';
          return flatNum.contains(_searchQuery!.toLowerCase()) ||
                 ownerName.contains(_searchQuery!.toLowerCase());
        }).toList();
        return {...floor, 'flats': filteredFlats};
      }).toList();
    }

    // Apply status filter
    if (_filterStatus != null && _filterStatus != 'all') {
      floors = floors.map((floor) {
        final filteredFlats = (floor['flats'] as List).where((flat) {
          return flat['status'] == _filterStatus;
        }).toList();
        return {...floor, 'flats': filteredFlats};
      }).toList();
    }

    return floors;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _buildingData?['building']?['name'] ?? 'Building View',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_buildingData?['building'] != null)
              Text(
                '${_buildingData!['building']['totalFloors']} Floors • ${_buildingData!['building']['totalFlats']} Flats',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(_is3DView ? Icons.list : Icons.view_in_ar),
              onPressed: () {
                setState(() {
                  _is3DView = !_is3DView;
                });
              },
              tooltip: _is3DView ? 'Switch to List View' : 'Switch to 3D View',
              color: Colors.white,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadBuildingView,
              tooltip: 'Refresh',
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildingData == null
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Search and Filter Bar
                    _buildSearchAndFilterBar(),
                    // Statistics Cards
                    _buildStatisticsCards(),
                    // Main Content
                    Expanded(
                      child: _is3DView
                          ? _build3DView()
                          : _buildListView(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search flats or residents...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery != null && _searchQuery!.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() => _searchQuery = null);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.background,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.isEmpty ? null : value);
            },
          ),
          const SizedBox(height: 12),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _filterStatus == null || _filterStatus == 'all',
                  onTap: () => setState(() => _filterStatus = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Occupied',
                  isSelected: _filterStatus == 'occupied',
                  color: AppColors.success,
                  onTap: () => setState(() => _filterStatus = 'occupied'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Vacant',
                  isSelected: _filterStatus == 'vacant',
                  color: Colors.grey,
                  onTap: () => setState(() => _filterStatus = 'vacant'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Complaints',
                  isSelected: _filterStatus == 'has_complaints',
                  color: AppColors.warning,
                  onTap: () => setState(() => _filterStatus = 'has_complaints'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Pending Dues',
                  isSelected: _filterStatus == 'pending_dues',
                  color: AppColors.error,
                  onTap: () => setState(() => _filterStatus = 'pending_dues'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    if (_buildingData?['statistics'] == null) return const SizedBox.shrink();
    
    final stats = _buildingData!['statistics'];
    final occupancyRate = stats['occupancyRate'] ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Flats',
                  value: '${stats['totalFlats'] ?? 0}',
                  color: AppColors.primary,
                  icon: Icons.home,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Occupied',
                  value: '${stats['occupiedFlats'] ?? 0}',
                  color: AppColors.success,
                  icon: Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Vacant',
                  value: '${stats['vacantFlats'] ?? 0}',
                  color: Colors.grey,
                  icon: Icons.home_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Occupancy Rate
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Occupancy Rate',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: occupancyRate / 100,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.success,
                                  AppColors.primary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${occupancyRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _build3DView() {
    final floors = _getFilteredFloors();
    if (floors.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Building Header with Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.apartment,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _buildingData?['building']?['name'] ?? 'Building',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_buildingData?['building']?['address']?['city'] ?? ''}, ${_buildingData?['building']?['address']?['state'] ?? ''}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Building Visualization
          Container(
            height: 450,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background,
                  AppColors.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Background pattern
                  CustomPaint(
                    painter: IsometricBuildingPainter(
                      floors: floors,
                      selectedFloor: _selectedFloor,
                      onFloorTap: (floorNum) {
                        setState(() {
                          if (_selectedFloor == floorNum) {
                            _selectedFloor = null;
                            _expandController.reverse();
                          } else {
                            _selectedFloor = floorNum;
                            _expandController.forward();
                          }
                        });
                      },
                      getFlatStatusColor: _getFlatStatusColor,
                    ),
                    size: Size.infinite,
                  ),
                  // Legend
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _LegendItem(
                            color: AppColors.success,
                            label: 'Occupied',
                          ),
                          const SizedBox(height: 4),
                          _LegendItem(
                            color: Colors.grey.shade400,
                            label: 'Vacant',
                          ),
                          const SizedBox(height: 4),
                          _LegendItem(
                            color: AppColors.warning,
                            label: 'Complaints',
                          ),
                          const SizedBox(height: 4),
                          _LegendItem(
                            color: AppColors.error,
                            label: 'Pending Dues',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Floor Details
          if (_selectedFloor != null)
            _buildFloorDetails(_selectedFloor!),
        ],
      ),
    );
  }

  Widget _buildFloorDetails(int floorNumber) {
    final floors = _getFilteredFloors();
    final floor = floors.firstWhere(
      (f) => f['floorNumber'] == floorNumber,
      orElse: () => <String, dynamic>{},
    );

    if (floor.isEmpty) return const SizedBox.shrink();

    final flats = List<Map<String, dynamic>>.from(floor['flats'] ?? []);

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_expandAnimation.value * 0.2),
          child: Opacity(
            opacity: _expandAnimation.value,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Floor $floorNumber',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _selectedFloor = null;
                              _expandController.reverse();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: flats.length,
                      itemBuilder: (context, index) {
                        return _buildFlatCard(flats[index], floorNumber);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlatCard(Map<String, dynamic> flat, int floorNumber) {
    final status = flat['status'] ?? 'vacant';
    final statusColor = _getFlatStatusColor(status);
    final hasComplaints = flat['complaintsCount'] > 0;
    final hasPendingDues = flat['hasPendingDues'] == true;
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FlatDetailsScreen(
              buildingCode: widget.buildingCode ?? _buildingData?['building']?['code'],
              floorNumber: floorNumber,
              flatNumber: flat['flatNumber'],
            ),
          ),
        ).then((_) => _loadBuildingView());
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusColor.withOpacity(0.15),
              statusColor.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    flat['flatType'] ?? '',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasComplaints)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    if (hasPendingDues)
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.payment,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              flat['flatNumber'] ?? '',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase().replaceAll('_', ' '),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (flat['occupiedBy'] != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      flat['occupiedBy']['fullName'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    final floors = _getFilteredFloors();
    if (floors.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadBuildingView,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: floors.length,
        itemBuilder: (context, index) {
          final floor = floors[index];
          return _FloorSection(
            floor: floor,
            buildingCode: widget.buildingCode ?? _buildingData?['building']?['code'],
            onFlatTap: (flat) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FlatDetailsScreen(
                    buildingCode: widget.buildingCode ?? _buildingData?['building']?['code'],
                    floorNumber: floor['floorNumber'],
                    flatNumber: flat['flatNumber'],
                  ),
                ),
              ).then((_) => _loadBuildingView());
            },
            getFlatStatusColor: _getFlatStatusColor,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
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
              'No Building Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load building information',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadBuildingView,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// Isometric Building Painter
class IsometricBuildingPainter extends CustomPainter {
  final List<Map<String, dynamic>> floors;
  final int? selectedFloor;
  final Function(int) onFloorTap;
  final Color Function(String) getFlatStatusColor;

  IsometricBuildingPainter({
    required this.floors,
    required this.selectedFloor,
    required this.onFloorTap,
    required this.getFlatStatusColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (floors.isEmpty) return;

    // Calculate dimensions
    final totalFloors = floors.length;
    final floorHeight = (size.height - 60) / (totalFloors + 1);
    final floorWidth = size.width * 0.75;
    final startX = (size.width - floorWidth) / 2;
    final isometricOffset = 25.0;
    final baseY = size.height - 30;

    // Draw ground/base
    final groundPath = Path();
    groundPath.moveTo(startX - 20, baseY + 10);
    groundPath.lineTo(startX + floorWidth + 20, baseY + 10);
    groundPath.lineTo(startX + floorWidth + 20 + isometricOffset, baseY + 10 - 15);
    groundPath.lineTo(startX - 20 + isometricOffset, baseY + 10 - 15);
    groundPath.close();

    final groundPaint = Paint()
      ..color = Colors.grey.shade300.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(groundPath, groundPaint);

    // Draw floors from bottom to top (isometric 3D effect)
    for (int i = totalFloors - 1; i >= 0; i--) {
      final floor = floors[i];
      final floorNum = floor['floorNumber'] as int;
      final y = baseY - (totalFloors - i) * floorHeight;
      final isSelected = selectedFloor == floorNum;
      final offsetX = (totalFloors - 1 - i) * isometricOffset;

      // Draw floor front face (isometric rectangle)
      final frontPath = Path();
      frontPath.moveTo(startX + offsetX, y);
      frontPath.lineTo(startX + offsetX + floorWidth, y);
      frontPath.lineTo(startX + offsetX + floorWidth + isometricOffset, y - floorHeight);
      frontPath.lineTo(startX + offsetX + isometricOffset, y - floorHeight);
      frontPath.close();

      // Draw floor top face (for 3D effect)
      final topPath = Path();
      topPath.moveTo(startX + offsetX + isometricOffset, y - floorHeight);
      topPath.lineTo(startX + offsetX + floorWidth + isometricOffset, y - floorHeight);
      topPath.lineTo(startX + offsetX + floorWidth + isometricOffset * 2, y - floorHeight - isometricOffset);
      topPath.lineTo(startX + offsetX + isometricOffset * 2, y - floorHeight - isometricOffset);
      topPath.close();

      // Draw floor side face
      final sidePath = Path();
      sidePath.moveTo(startX + offsetX + floorWidth, y);
      sidePath.lineTo(startX + offsetX + floorWidth + isometricOffset, y - floorHeight);
      sidePath.lineTo(startX + offsetX + floorWidth + isometricOffset * 2, y - floorHeight - isometricOffset);
      sidePath.lineTo(startX + offsetX + floorWidth + isometricOffset, y - isometricOffset);
      sidePath.close();

      // Fill colors with gradient effect
      final frontPaint = Paint()
        ..color = isSelected
            ? AppColors.primary.withOpacity(0.4)
            : AppColors.primary.withOpacity(0.15)
        ..style = PaintingStyle.fill;

      final topPaint = Paint()
        ..color = isSelected
            ? AppColors.primary.withOpacity(0.25)
            : AppColors.primary.withOpacity(0.1)
        ..style = PaintingStyle.fill;

      final sidePaint = Paint()
        ..color = isSelected
            ? AppColors.primary.withOpacity(0.3)
            : AppColors.primary.withOpacity(0.12)
        ..style = PaintingStyle.fill;

      // Draw faces
      canvas.drawPath(sidePath, sidePaint);
      canvas.drawPath(topPath, topPaint);
      canvas.drawPath(frontPath, frontPaint);

      // Draw floor border
      final borderPaint = Paint()
        ..color = isSelected
            ? AppColors.primary
            : AppColors.primary.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.0 : 2.0;

      canvas.drawPath(frontPath, borderPaint);
      canvas.drawPath(topPath, borderPaint);
      canvas.drawPath(sidePath, borderPaint);

      // Draw floor number badge
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          startX + offsetX + 12,
          y - floorHeight / 2 - 12,
          40,
          24,
        ),
        const Radius.circular(12),
      );

      final badgePaint = Paint()
        ..color = isSelected
            ? AppColors.primary
            : AppColors.primary.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(badgeRect, badgePaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: 'F$floorNum',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          startX + offsetX + 32 - textPainter.width / 2,
          y - floorHeight / 2 - textPainter.height / 2,
        ),
      );

      // Draw flats on floor
      final flats = List<Map<String, dynamic>>.from(floor['flats'] ?? []);
      if (flats.isNotEmpty) {
        final flatSpacing = floorWidth / (flats.length + 1);
        for (int j = 0; j < flats.length; j++) {
          final flat = flats[j];
          final flatX = startX + offsetX + (j + 1) * flatSpacing;
          final flatStatus = flat['status'] ?? 'vacant';
          final flatColor = getFlatStatusColor(flatStatus);
          final hasComplaints = flat['complaintsCount'] > 0;

          // Draw flat indicator (isometric square)
          final flatSize = 12.0;
          final flatPath = Path();
          flatPath.moveTo(flatX - flatSize / 2, y - floorHeight / 2);
          flatPath.lineTo(flatX - flatSize / 2 + flatSize, y - floorHeight / 2);
          flatPath.lineTo(flatX - flatSize / 2 + flatSize + 4, y - floorHeight / 2 - 4);
          flatPath.lineTo(flatX - flatSize / 2 + 4, y - floorHeight / 2 - 4);
          flatPath.close();

          final flatPaint = Paint()
            ..color = flatColor
            ..style = PaintingStyle.fill;

          canvas.drawPath(flatPath, flatPaint);

          // Draw border for flat
          final flatBorderPaint = Paint()
            ..color = flatColor.withOpacity(0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;

          canvas.drawPath(flatPath, flatBorderPaint);

          // Draw complaint indicator
          if (hasComplaints) {
            final complaintPaint = Paint()
              ..color = AppColors.warning
              ..style = PaintingStyle.fill;
            canvas.drawCircle(
              Offset(flatX + flatSize / 2, y - floorHeight / 2 - flatSize / 2),
              4,
              complaintPaint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Legend Item Widget
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: color.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? AppColors.primary).withOpacity(0.2)
              : AppColors.surface,
          border: Border.all(
            color: isSelected
                ? (color ?? AppColors.primary)
                : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (color ?? AppColors.primary)
                : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// Floor Section Widget (for List View)
class _FloorSection extends StatelessWidget {
  final Map<String, dynamic> floor;
  final String? buildingCode;
  final Function(Map<String, dynamic>) onFlatTap;
  final Color Function(String) getFlatStatusColor;

  const _FloorSection({
    required this.floor,
    required this.buildingCode,
    required this.onFlatTap,
    required this.getFlatStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    final flats = List<Map<String, dynamic>>.from(floor['flats'] ?? []);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
                final status = flat['status'] ?? 'vacant';
                final statusColor = getFlatStatusColor(status);
                
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
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                flat['flatType'] ?? '',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            if (flat['complaintsCount'] > 0)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.warning,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${flat['complaintsCount']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                          status.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

