import '../../../core/imports/app_imports.dart';
import '../auth/role_selection_screen.dart';
import 'create_building_screen.dart';
import 'create_building_comprehensive_screen.dart';
import 'create_apartment_flow_screen.dart';
import 'create_user_screen.dart';
import 'create_staff_screen.dart';
import 'building_details_screen.dart';
import 'building_view_3d_screen.dart';
import 'bulk_resident_management_screen.dart';
import 'users_management_screen.dart';
import 'complaints_management_screen.dart'
    show ComplaintsManagementScreen, ComplaintsManagementScreenState;
import 'settings_screen.dart';
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
  final GlobalKey<State<ComplaintsManagementScreen>> _complaintsKey =
      GlobalKey();

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Building Info Card
          Card(
            color: AppColors.primary.withOpacity(0.1),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.apartment,
                      color: AppColors.textOnPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _buildingData!['name'] ?? 'Building',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${_buildingData!['code'] ?? 'N/A'}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        if (_buildingData!['statistics'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_buildingData!['statistics']['occupiedFlats'] ?? 0}/${_buildingData!['statistics']['totalFlats'] ?? 0} Flats Occupied',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BuildingDetailsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Building Statistics
          if (_dashboardData?['building'] != null) ...[
            Text(
              'Building Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Flats',
                    value: '${_dashboardData!['building']['totalFlats'] ?? 0}',
                    icon: Icons.home,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Occupied',
                    value:
                        '${_dashboardData!['building']['occupiedFlats'] ?? 0}',
                    icon: Icons.person,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Vacant',
                    value: '${_dashboardData!['building']['vacantFlats'] ?? 0}',
                    icon: Icons.home_outlined,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Occupancy Rate',
                    value:
                        '${_dashboardData!['building']['occupancyRate']?.toStringAsFixed(1) ?? '0'}%',
                    icon: Icons.trending_up,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Residents',
                    value: '${_dashboardData!['residents']['total'] ?? 0}',
                    icon: Icons.people,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Total Staff',
                    value: '${_dashboardData!['staff']['total'] ?? 0}',
                    icon: Icons.work,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          // Complaint Statistics
          Text(
            'Complaint Statistics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Pending Approvals',
                  value: '${_dashboardData!['pendingApprovals'] ?? 0}',
                  icon: Icons.pending_actions,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Active Complaints',
                  value: '${_dashboardData!['activeComplaints'] ?? 0}',
                  icon: Icons.report_problem,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Total Complaints',
                  value: '${_dashboardData!['totalComplaints'] ?? 0}',
                  icon: Icons.description,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Resolved',
                  value: '${_dashboardData!['resolvedComplaints'] ?? 0}',
                  icon: Icons.check_circle,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _ActionCard(
                title: 'Create Building',
                icon: Icons.apartment,
                color: AppColors.primary,
                onTap: () async {
                  print('🖱️ [FLUTTER] Create Building button clicked');
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateApartmentFlowScreen(),
                    ),
                  );
                  // Refresh dashboard data after creation while preserving current tab
                  if (mounted) {
                    await _loadDashboardData();
                  }
                },
              ),
              _ActionCard(
                title: 'Building Details',
                icon: Icons.info,
                color: AppColors.info,
                onTap: () {
                  print('🖱️ [FLUTTER] Building Details button clicked');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BuildingDetailsScreen(),
                    ),
                  );
                },
              ),
              _ActionCard(
                title: 'Resident Management',
                icon: Icons.people,
                color: AppColors.primary,
                onTap: () {
                  print('🖱️ [FLUTTER] Resident Management button clicked');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BulkResidentManagementScreen(),
                    ),
                  );
                },
              ),
              _ActionCard(
                title: '3D Building View',
                icon: Icons.view_in_ar,
                color: AppColors.info,
                onTap: () {
                  print('🖱️ [FLUTTER] 3D Building View button clicked');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BuildingView3DScreen(
                        buildingCode: _selectedBuildingCode,
                      ),
                    ),
                  );
                },
              ),
              _ActionCard(
                title: 'Create User',
                icon: Icons.person_add,
                color: AppColors.success,
                onTap: () {
                  print('🖱️ [FLUTTER] Create User button clicked');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateUserScreen()),
                  );
                },
              ),
              _ActionCard(
                title: 'Create Staff',
                icon: Icons.badge,
                color: AppColors.warning,
                onTap: () async {
                  print('🖱️ [FLUTTER] Create Staff button clicked');
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateStaffScreen(),
                    ),
                  );
                  // Refresh dashboard data after creation while preserving current tab
                  if (mounted) {
                    await _loadDashboardData();
                  }
                },
              ),
              _ActionCard(
                title: 'View All Users',
                icon: Icons.people,
                color: AppColors.secondary,
                onTap: () {
                  print('🖱️ [FLUTTER] View All Users button clicked');
                  setState(() => _currentIndex = 1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
