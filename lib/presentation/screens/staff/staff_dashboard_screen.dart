import '../../../core/imports/app_imports.dart';
import '../auth/role_selection_screen.dart';
import '../home/tabs/news_tab_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_home_screen.dart';
import '../../widgets/app_sidebar.dart';
import '../admin/complaints_management_screen.dart';
import '../visitors/visitor_dashboard_screen.dart';
import 'create_user_screen.dart';
import 'users_management_screen.dart';
import 'dart:convert';
import '../../../core/constants/api_constants.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _staffData;
  Map<String, dynamic>? _buildingData;
  List<Map<String, dynamic>> _allBuildings = [];
  List<Map<String, dynamic>> _assignedComplaints = [];
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
      final response = await ApiService.get(ApiConstants.staffBuildings);
      if (response['success'] == true) {
        setState(() {
          _allBuildings = List<Map<String, dynamic>>.from(
            response['data']?['buildings'] ?? [],
          );
          
          // Validate stored building code
          if (_allBuildings.isNotEmpty) {
            final isValidCode = _selectedBuildingCode != null && 
                _allBuildings.any((b) => b['code'] == _selectedBuildingCode);
            
            if (!isValidCode) {
              // Use primary building or first building
              final primaryBuilding = _allBuildings.firstWhere(
                (b) => b['isPrimary'] == true,
                orElse: () => _allBuildings.first,
              );
              _selectedBuildingCode = primaryBuilding['code'];
              _saveSelectedBuilding(_selectedBuildingCode);
            }
          } else if (_selectedBuildingCode != null) {
            _saveSelectedBuilding(null);
          }
        });
        _loadDashboardData();
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading buildings: $e');
      _loadDashboardData();
    }
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for staff dashboard');
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          socketService.connect(userId);

          socketService.on('user_created', (data) {
            if (mounted) {
              _loadDashboardData();
            }
          });

          socketService.on('complaint_created', (data) {
            if (mounted) {
              _loadDashboardData();
            }
          });

          socketService.on('visitor_checked_in', (data) {
            if (mounted) {
              _loadDashboardData();
            }
          });
        }
      } catch (e) {
        print('❌ [FLUTTER] Error setting up socket: $e');
      }
    }
  }

  Future<void> _loadDashboardData() async {
    print('🖱️ [FLUTTER] Loading staff dashboard data...');
    setState(() => _isLoading = true);
    try {
      // Load dashboard data
      String dashboardUrl = ApiConstants.staffDashboard;
      if (_selectedBuildingCode != null) {
        dashboardUrl = '${ApiConstants.staffDashboard}?buildingCode=$_selectedBuildingCode';
      }
      final dashboardResponse = await ApiService.get(dashboardUrl);
      
      if (dashboardResponse['success'] == true) {
        setState(() {
          _dashboardData = dashboardResponse['data']?['dashboard'];
          _staffData = dashboardResponse['data']?['staff'];
          
          // Update buildings list if provided
          if (dashboardResponse['data']?['buildings'] != null) {
            _allBuildings = List<Map<String, dynamic>>.from(
              dashboardResponse['data']?['buildings'] ?? [],
            );
            
            // Validate selected building still exists
            if (_selectedBuildingCode != null && _allBuildings.isNotEmpty) {
              final isValidCode = _allBuildings.any(
                (b) => b['code'] == _selectedBuildingCode
              );
              if (!isValidCode) {
                // Use primary building or first building
                final primaryBuilding = _allBuildings.firstWhere(
                  (b) => b['isPrimary'] == true,
                  orElse: () => _allBuildings.first,
                );
                _selectedBuildingCode = primaryBuilding['code'];
                _saveSelectedBuilding(_selectedBuildingCode);
              }
            }
          }
          
          // Update assigned complaints
          _assignedComplaints = List<Map<String, dynamic>>.from(
            dashboardResponse['data']?['assignedComplaints'] ?? [],
          );
        });
      } else {
        // Handle error response
        if (mounted) {
          AppMessageHandler.handleResponse(context, dashboardResponse);
        }
      }

      // Load building details
      if (_selectedBuildingCode != null) {
        try {
          String buildingUrl = '${ApiConstants.staffBuildingDetails}?buildingCode=$_selectedBuildingCode';
          final buildingResponse = await ApiService.get(buildingUrl);
          if (buildingResponse['success'] == true) {
            setState(() {
              _buildingData = buildingResponse['data']?['building'];
            });
          }
        } catch (e) {
          print('❌ [FLUTTER] Building details error: $e');
        }
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading dashboard: $e');
      if (mounted) {
        // Only show error if it's not a "no buildings" case
        if (_allBuildings.isEmpty) {
          // This is expected - staff has no buildings assigned
          setState(() => _isLoading = false);
        } else {
          AppMessageHandler.handleError(context, e);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _getBodyForIndex(int index) {
    return IndexedStack(
      index: index,
      children: [
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildDashboard(),
        const NewsTabScreen(),
        const ChatHomeScreen(),
        const ProfileScreen(),
      ],
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'News';
      case 2:
        return 'Chat';
      case 3:
        return 'Profile';
      default:
        return 'Dashboard';
    }
  }

  // Get permissions from staff data
  Map<String, dynamic>? get _permissions {
    return _staffData?['permissions'];
  }

  bool get _canManageVisitors => _permissions?['canManageVisitors'] == true;
  bool get _canManageComplaints => _permissions?['canManageComplaints'] == true;
  bool get _canManageAccess => _permissions?['canManageAccess'] == true;
  bool get _canManageMaintenance => _permissions?['canManageMaintenance'] == true;

  @override
  Widget build(BuildContext context) {
    final buildingName = _selectedBuildingCode != null && _allBuildings.isNotEmpty
        ? _allBuildings.firstWhere(
            (b) => b['code'] == _selectedBuildingCode,
            orElse: () => {'name': ''},
          )['name'] ?? ''
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
      drawer: AppSidebarBuilder.buildStaffSidebar(
        context: context,
        buildingName: buildingName,
        buildings: _allBuildings,
        selectedBuildingCode: _selectedBuildingCode,
        onBuildingSelected: (code) {
          _saveSelectedBuilding(code);
          _loadDashboardData();
          setState(() {});
        },
        permissions: _permissions,
      ),
      body: SafeArea(child: _getBodyForIndex(_currentIndex)),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (mounted) {
          setState(() {
            _currentIndex = index;
          });
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: 'News',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    if (_allBuildings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No buildings assigned',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please contact admin to assign buildings',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Extract data with safe defaults
    final dashboardStats = _dashboardData ?? {};
    final buildingStats = dashboardStats['building'] ?? {};
    final performanceStats = dashboardStats['performance'] ?? {};
    
    final currentBuilding = _selectedBuildingCode != null && _allBuildings.isNotEmpty
        ? _allBuildings.firstWhere(
            (b) => b['code'] == _selectedBuildingCode,
            orElse: () => <String, dynamic>{},
          )
        : _buildingData;
    
    final buildingName = currentBuilding?['name'] ?? _buildingData?['name'] ?? 'No Building Selected';
    final buildingCode = currentBuilding?['code'] ?? _buildingData?['code'] ?? 'N/A';
    
    final totalBuildings = _allBuildings.length;
    final pendingApprovals = dashboardStats['pendingApprovals'] ?? 0;
    final totalResidents = dashboardStats['totalResidents'] ?? 0;
    final totalComplaints = dashboardStats['totalComplaints'] ?? 0;
    final resolvedComplaints = dashboardStats['resolvedComplaints'] ?? 0;
    final openComplaints = dashboardStats['openComplaints'] ?? 0;
    final todayVisitors = dashboardStats['todayVisitors'] ?? 0;
    final totalProperties = buildingStats['totalFlats'] ?? 0;
    final occupiedFlats = buildingStats['occupiedFlats'] ?? 0;
    final vacantFlats = buildingStats['vacantFlats'] ?? 0;
    final activeAssignments = performanceStats['activeAssignments'] ?? 0;
    final totalCompleted = performanceStats['totalCompleted'] ?? 0;
    
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
                    title: 'Total Residents',
                    value: '$totalResidents',
                    icon: Icons.people,
                    iconColor: AppColors.success,
                    backgroundColor: AppColors.success.withOpacity(0.08),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_canManageAccess)
              _ModernStatCard(
                title: 'Pending Approvals',
                value: '$pendingApprovals',
                icon: Icons.pending_actions,
                iconColor: AppColors.warning,
                backgroundColor: AppColors.warning.withOpacity(0.08),
                isFullWidth: true,
              ),
            const SizedBox(height: 24),
            
            // Complaint Statistics Section
            if (_canManageComplaints) ...[
              _SectionHeader(
                title: 'Complaint Management',
                icon: Icons.description_outlined,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModernStatCard(
                      title: 'Total Complaints',
                      value: '$totalComplaints',
                      icon: Icons.description,
                      iconColor: AppColors.error,
                      backgroundColor: AppColors.error.withOpacity(0.08),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModernStatCard(
                      title: 'Open Complaints',
                      value: '$openComplaints',
                      icon: Icons.warning,
                      iconColor: AppColors.warning,
                      backgroundColor: AppColors.warning.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModernStatCard(
                      title: 'Resolved',
                      value: '$resolvedComplaints',
                      icon: Icons.check_circle,
                      iconColor: AppColors.success,
                      backgroundColor: AppColors.success.withOpacity(0.08),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModernStatCard(
                      title: 'My Assignments',
                      value: '$activeAssignments',
                      icon: Icons.assignment,
                      iconColor: AppColors.info,
                      backgroundColor: AppColors.info.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            
            // Visitor Statistics Section
            if (_canManageVisitors) ...[
              _SectionHeader(
                title: 'Visitor Management',
                icon: Icons.people_outline,
              ),
              const SizedBox(height: 12),
              _ModernStatCard(
                title: "Today's Visitors",
                value: '$todayVisitors',
                icon: Icons.person_add,
                iconColor: AppColors.info,
                backgroundColor: AppColors.info.withOpacity(0.08),
                isFullWidth: true,
              ),
              const SizedBox(height: 24),
            ],
            
            // Performance Statistics
            _SectionHeader(
              title: 'My Performance',
              icon: Icons.analytics_outlined,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ModernStatCard(
                    title: 'Completed Tasks',
                    value: '$totalCompleted',
                    icon: Icons.check_circle_outline,
                    iconColor: AppColors.success,
                    backgroundColor: AppColors.success.withOpacity(0.08),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModernStatCard(
                    title: 'Active Tasks',
                    value: '$activeAssignments',
                    icon: Icons.assignment,
                    iconColor: AppColors.primary,
                    backgroundColor: AppColors.primary.withOpacity(0.08),
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
            if (_canManageAccess)
              _QuickActionButton(
                title: 'Create Resident',
                icon: Icons.person_add,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StaffCreateUserScreen(),
                    ),
                  );
                  if (mounted) await _loadDashboardData();
                },
              ),
            if (_canManageAccess) const SizedBox(height: 12),
            if (_canManageAccess)
              _QuickActionButton(
                title: 'Users Management',
                icon: Icons.people,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StaffUsersManagementScreen(),
                    ),
                  );
                },
              ),
            if (_canManageAccess) const SizedBox(height: 12),
            if (_canManageComplaints)
              _QuickActionButton(
                title: 'Manage Complaints',
                icon: Icons.description,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ComplaintsManagementScreen(),
                    ),
                  );
                },
              ),
            if (_canManageComplaints) const SizedBox(height: 12),
            if (_canManageVisitors)
              _QuickActionButton(
                title: 'Visitor Logs',
                icon: Icons.people,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VisitorDashboardScreen(),
                    ),
                  );
                },
              ),
            if (_canManageVisitors) const SizedBox(height: 12),
            if (_assignedComplaints.isNotEmpty) ...[
              _SectionHeader(
                title: 'My Assigned Complaints',
                icon: Icons.assignment,
              ),
              const SizedBox(height: 12),
              ..._assignedComplaints.take(5).map((complaint) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Icon(
                        Icons.description,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      complaint['title'] ?? 'No Title',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${complaint['createdBy']?['wing'] ?? ''}-${complaint['createdBy']?['flatNumber'] ?? ''} • ${complaint['priority'] ?? 'Medium'}',
                    ),
                    trailing: Chip(
                      label: Text(
                        complaint['status'] ?? 'N/A',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: _getStatusColor(complaint['status']).withOpacity(0.2),
                    ),
                    onTap: () {
                      // Navigate to complaint details
                    },
                  ),
                );
              }).toList(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'open':
        return AppColors.warning;
      case 'assigned':
      case 'in progress':
        return AppColors.info;
      case 'resolved':
      case 'closed':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }
}

// Current Building Card
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
        Icon(icon, size: 20, color: color),
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
          child: Icon(icon, size: 20, color: AppColors.primary),
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
            child: Icon(icon, color: iconColor, size: 24),
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
              child: Icon(icon, color: AppColors.primary, size: 24),
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
