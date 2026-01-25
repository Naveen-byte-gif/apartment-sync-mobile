import '../../../core/imports/app_imports.dart';
import 'create_apartment_flow_screen.dart';
import 'create_user_screen.dart';
import 'create_staff_screen.dart';
import 'users_management_screen.dart';
import 'complaints_management_screen.dart'
    show ComplaintsManagementScreen;
import 'invoice_management_screen.dart';
import 'no_building_screen.dart';
import '../home/tabs/news_tab_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_home_screen.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_sidebar.dart';
import 'dart:convert';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _buildingData;
  List<Map<String, dynamic>> _allBuildings = [];
  String? _selectedBuildingCode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSelectedBuilding();
    _loadAllBuildings();
    _setupSocketListeners();
  }

  void _loadSelectedBuilding() {
    final savedCode = StorageService.getString(
      AppConstants.selectedBuildingKey,
    );
    setState(() {
      _selectedBuildingCode = savedCode;
    });
  }

  void _saveSelectedBuilding(String? code) {
    if (code != null) {
      StorageService.setString(AppConstants.selectedBuildingKey, code);
    } else {
      StorageService.remove(AppConstants.selectedBuildingKey);
    }
    setState(() {
      _selectedBuildingCode = code;
    });
  }

  Future<void> _loadAllBuildings() async {
    try {
      final response = await ApiService.get(ApiConstants.adminBuildings);
      if (response['success'] == true) {
        setState(() {
          _allBuildings = List<Map<String, dynamic>>.from(
            response['data']?['buildings'] ?? [],
          );
          
          // Validate stored building code against fetched buildings
          if (_allBuildings.isNotEmpty) {
            // Check if current selected building code exists in fetched buildings
            final isValidCode = _selectedBuildingCode != null && 
                _allBuildings.any((b) => b['code'] == _selectedBuildingCode);
            
            if (!isValidCode) {
              // Stored code is invalid or doesn't exist, use first building
              _selectedBuildingCode = _allBuildings.first['code'];
              _saveSelectedBuilding(_selectedBuildingCode);
            }
          } else if (_selectedBuildingCode != null) {
            // No buildings but we have a stored code - clear it
            _saveSelectedBuilding(null);
          }
        });
        // Load dashboard data after buildings are loaded
        _loadDashboardData();
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading buildings: $e');
      // Still try to load dashboard
      _loadDashboardData();
    }
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for admin dashboard');
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          socketService.connect(userId);

          // Listen for building updates
          socketService.on('building_created', (data) {
            print('📡 [FLUTTER] Building created event received');
            if (mounted) {
              _loadDashboardData();
            }
          });

          socketService.on('building_updated', (data) {
            print('📡 [FLUTTER] Building updated event received');
            if (mounted) {
              _loadDashboardData();
            }
          });

          // Listen for user/flat updates
          socketService.on('user_created', (data) {
            print('📡 [FLUTTER] User created event received');
            if (mounted) {
              _loadDashboardData();
            }
          });

          socketService.on('flat_status_updated', (data) {
            print('📡 [FLUTTER] Flat status updated event received');
            if (mounted) {
              _loadDashboardData();
              AppMessageHandler.showInfo(context, 'Flat status updated');
            }
          });
        }
      } catch (e) {
        print('❌ [FLUTTER] Error setting up socket: $e');
      }
    }
  }

  Future<void> _loadDashboardData() async {
    print('🖱️ [FLUTTER] Loading admin dashboard data...');
    try {
      // Load dashboard data
      try {
        print('📊 [FLUTTER] Loading dashboard stats...');
        String dashboardUrl = ApiConstants.adminDashboard;
        if (_selectedBuildingCode != null) {
          dashboardUrl = ApiConstants.addBuildingCode(
            dashboardUrl,
            _selectedBuildingCode,
          );
        }
        final dashboardResponse = await ApiService.get(dashboardUrl);
        print('✅ [FLUTTER] Dashboard response received');
        print(
          '📦 [FLUTTER] Dashboard Response: ${dashboardResponse.toString()}',
        );

        if (dashboardResponse['success'] == true) {
          print('📊 [FLUTTER] Dashboard data loaded successfully');
          setState(() {
            _dashboardData = dashboardResponse['data']?['dashboard'];
            // Update buildings list if provided
            if (dashboardResponse['data']?['buildings'] != null) {
              _allBuildings = List<Map<String, dynamic>>.from(
                dashboardResponse['data']?['buildings'] ?? [],
              );
            }
          });
        }
      } catch (e) {
        print('❌ [FLUTTER] Dashboard error: $e');
      }

      // Load building details
      try {
        print('🏢 [FLUTTER] Loading building details...');
        String buildingUrl = ApiConstants.adminBuildingDetails;
        if (_selectedBuildingCode != null) {
          buildingUrl = ApiConstants.addBuildingCode(
            buildingUrl,
            _selectedBuildingCode,
          );
        }
        final buildingResponse = await ApiService.get(buildingUrl);
        print('✅ [FLUTTER] Building details response received');
        print('📦 [FLUTTER] Building Response: ${buildingResponse.toString()}');

        if (buildingResponse['success'] == true) {
          print('🏢 [FLUTTER] Building data loaded successfully');
          setState(() {
            _buildingData = buildingResponse['data']?['building'];
          });
        }
      } catch (e) {
        print('❌ [FLUTTER] Building details error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _getBodyForIndex(int index) {
    // Use IndexedStack to preserve state of each tab page
    return IndexedStack(
      index: index,
      children: [
        // Dashboard (index 0)
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildDashboard(),
        // Users (index 1)
        const UsersManagementScreen(),
        // News (index 2)
        const NewsTabScreen(),
        // Chat (index 3)
        const ChatHomeScreen(),
        // Profile (index 4)
        const ProfileScreen(),
      ],
    );
  }

 

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Users';
      case 2:
        return 'News';
      case 3:
        return 'Chat';
      case 4:
        return 'Profile';
      default:
        return 'Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get building name for sidebar
    final buildingName =
        _selectedBuildingCode != null && _allBuildings.isNotEmpty
        ? _allBuildings.firstWhere(
                (b) => b['code'] == _selectedBuildingCode,
                orElse: () => {'name': ''},
              )['name'] ??
              ''
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDashboardData,
            ),
        ],
      ),
      drawer: AppSidebarBuilder.buildAdminSidebar(
        context: context,
        buildingName: buildingName,
        buildings: _allBuildings,
        selectedBuildingCode: _selectedBuildingCode,
        onBuildingSelected: (code) {
          _saveSelectedBuilding(code);
          _loadDashboardData();
          // Force rebuild of all tabs to refresh data
          setState(() {});
        },
      ),
      body: SafeArea(child: _getBodyForIndex(_currentIndex)),
      bottomNavigationBar: AdminBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (mounted) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
      ),
    );
  }

  Widget _buildDashboard() {
    // Check if building is created
    if (_buildingData == null) {
      return const NoBuildingScreen();
    }

    // Extract data with safe defaults
    final dashboardStats = _dashboardData ?? {};
    final buildingStats = dashboardStats['building'] ?? {};
    final residentsData = dashboardStats['residents'] ?? {};
    final staffData = dashboardStats['staff'] ?? {};
    
    // Get current building info
    final currentBuilding = _selectedBuildingCode != null && _allBuildings.isNotEmpty
        ? _allBuildings.firstWhere(
            (b) => b['code'] == _selectedBuildingCode,
            orElse: () => <String, dynamic>{},
          )
        : _buildingData;
    
    final buildingName = currentBuilding?['name'] ?? _buildingData?['name'] ?? 'No Building Selected';
    final buildingCode = currentBuilding?['code'] ?? _buildingData?['code'] ?? 'N/A';
    
    // Calculate statistics
    final totalBuildings = _allBuildings.length;
    final activeBuildings = _allBuildings.where((b) => b['status'] == 'active' || b['isActive'] == true).length;
    final pendingApprovals = dashboardStats['pendingApprovals'] ?? 0;
    final totalResidents = residentsData['total'] ?? 0;
    final totalStaff = staffData['total'] ?? 0;
    final totalUsers = totalResidents + totalStaff;
    final totalProperties = buildingStats['totalFlats'] ?? 0;
    final totalComplaints = dashboardStats['totalComplaints'] ?? 0;
    final resolvedComplaints = dashboardStats['resolvedComplaints'] ?? 0;
    final occupiedFlats = buildingStats['occupiedFlats'] ?? 0;
    final vacantFlats = buildingStats['vacantFlats'] ?? 0;
    
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            
            // Current Building Info Card
            _CurrentBuildingCard(
              buildingName: buildingName,
              buildingCode: buildingCode,
              totalFlats: totalProperties,
              occupiedFlats: occupiedFlats,
              vacantFlats: vacantFlats,
              allBuildings: _allBuildings,
              selectedBuildingCode: _selectedBuildingCode,
              onBuildingChanged: (code) {
                _saveSelectedBuilding(code);
                _loadDashboardData();
              },
            ),
            const SizedBox(height: 24),
            
            // Building Statistics Section
            _SectionHeader(
              title: 'Building Statistics',
              icon: Icons.apartment,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ModernStatCard(
                    title: 'Total Buildings',
                    value: '$totalBuildings',
                    icon: Icons.business,
                    iconColor: AppColors.primary,
                    backgroundColor: AppColors.primary.withOpacity(0.08),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModernStatCard(
                    title: 'Active Buildings',
                    value: '$activeBuildings',
                    icon: Icons.check_circle_outline,
                    iconColor: AppColors.success,
                    backgroundColor: AppColors.success.withOpacity(0.08),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ModernStatCard(
              title: 'Pending Approvals',
              value: '$pendingApprovals',
              icon: Icons.pending_actions,
              iconColor: AppColors.warning,
              backgroundColor: AppColors.warning.withOpacity(0.08),
              isFullWidth: true,
            ),
            const SizedBox(height: 24),
            
            // User & Staff Statistics Section
            _SectionHeader(
              title: 'User & Staff Statistics',
              icon: Icons.people_outline,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ModernStatCard(
                    title: 'Residents',
                    value: '$totalResidents',
                    icon: Icons.home,
                    iconColor: AppColors.primary,
                    backgroundColor: AppColors.primary.withOpacity(0.08),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModernStatCard(
                    title: 'Staff',
                    value: '$totalStaff',
                    icon: Icons.work_outline,
                    iconColor: AppColors.secondary,
                    backgroundColor: AppColors.secondary.withOpacity(0.08),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ModernStatCard(
              title: 'Total Users',
              value: '$totalUsers',
              icon: Icons.people,
              iconColor: AppColors.info,
              backgroundColor: AppColors.info.withOpacity(0.08),
              isFullWidth: true,
            ),
            const SizedBox(height: 24),
            
            // Platform Statistics Section
            _SectionHeader(
              title: 'Platform Statistics',
              icon: Icons.analytics_outlined,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ModernStatCard(
                    title: 'Total Properties',
                    value: '$totalProperties',
                    icon: Icons.home_outlined,
                    iconColor: AppColors.primary,
                    backgroundColor: AppColors.primary.withOpacity(0.08),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModernStatCard(
                    title: 'Total Reports',
                    value: '$totalComplaints',
                    icon: Icons.description_outlined,
                    iconColor: AppColors.error,
                    backgroundColor: AppColors.error.withOpacity(0.08),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ModernStatCard(
                    title: 'Resolved Reports',
                    value: '$resolvedComplaints',
                    icon: Icons.check_circle,
                    iconColor: AppColors.success,
                    backgroundColor: AppColors.success.withOpacity(0.08),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModernStatCard(
                    title: 'Occupied Flats',
                    value: '$occupiedFlats',
                    icon: Icons.home,
                    iconColor: AppColors.success,
                    backgroundColor: AppColors.success.withOpacity(0.08),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Quick Actions Section
            _SectionHeader(
              title: 'Quick Actions',
              icon: Icons.flash_on,
            ),
            const SizedBox(height: 16),
            _QuickActionButton(
              title: 'Add Building',
              icon: Icons.add_business,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateApartmentFlowScreen(),
                  ),
                );
                if (mounted) await _loadDashboardData();
              },
            ),
            const SizedBox(height: 12),
            _QuickActionButton(
              title: 'Create Resident',
              icon: Icons.person_add,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateUserScreen(),
                  ),
                );
                if (mounted) await _loadDashboardData();
              },
            ),
            const SizedBox(height: 12),
            _QuickActionButton(
              title: 'Create Staff',
              icon: Icons.badge,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateStaffScreen(),
                  ),
                );
                if (mounted) await _loadDashboardData();
              },
            ),
            const SizedBox(height: 12),
            _QuickActionButton(
              title: 'Manage Users',
              icon: Icons.people,
              onTap: () {
                setState(() => _currentIndex = 1);
              },
            ),
            const SizedBox(height: 12),
            _QuickActionButton(
              title: 'Approve Requests',
              icon: Icons.verified,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ComplaintsManagementScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _QuickActionButton(
              title: 'View Reports',
              icon: Icons.assessment,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ComplaintsManagementScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _QuickActionButton(
              title: 'Invoice Management',
              icon: Icons.receipt_long,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InvoiceManagementScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// Current Building Card - Shows which building is currently selected
class _CurrentBuildingCard extends StatelessWidget {
  final String buildingName;
  final String buildingCode;
  final int totalFlats;
  final int occupiedFlats;
  final int vacantFlats;
  final List<Map<String, dynamic>> allBuildings;
  final String? selectedBuildingCode;
  final Function(String?) onBuildingChanged;

  const _CurrentBuildingCard({
    required this.buildingName,
    required this.buildingCode,
    required this.totalFlats,
    required this.occupiedFlats,
    required this.vacantFlats,
    required this.allBuildings,
    required this.selectedBuildingCode,
    required this.onBuildingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.apartment,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Building',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      buildingName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.qr_code,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Code: $buildingCode',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Building Selector Dropdown (if multiple buildings)
              if (allBuildings.length > 1)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  onSelected: onBuildingChanged,
                  itemBuilder: (context) => allBuildings.map((building) {
                    final code = building['code'] ?? '';
                    final name = building['name'] ?? code;
                    final isSelected = code == selectedBuildingCode;
                    return PopupMenuItem<String>(
                      value: code,
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            size: 20,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BuildingStatItem(
                  label: 'Total Flats',
                  value: '$totalFlats',
                  icon: Icons.home_outlined,
                  color: AppColors.primary,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.border,
                ),
                _BuildingStatItem(
                  label: 'Occupied',
                  value: '$occupiedFlats',
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.border,
                ),
                _BuildingStatItem(
                  label: 'Vacant',
                  value: '$vacantFlats',
                  icon: Icons.home_outlined,
                  color: AppColors.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Building Stat Item for Current Building Card
class _BuildingStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BuildingStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: color,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Modern Section Header
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

// Modern Stat Card - Clean, minimal design
class _ModernStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final bool isFullWidth;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Modern Quick Action Button - Rounded, prominent design
class _QuickActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
