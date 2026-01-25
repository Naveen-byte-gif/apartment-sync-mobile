import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';
import 'new_visitor_entry_screen.dart';
import 'visitors_log_screen.dart';
import 'log_book_screen.dart';

class VisitorDashboardScreen extends StatefulWidget {
  const VisitorDashboardScreen({super.key});

  @override
  State<VisitorDashboardScreen> createState() => _VisitorDashboardScreenState();
}

class _VisitorDashboardScreenState extends State<VisitorDashboardScreen>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _recentActivity = [];
  bool _isLoading = true;
  int _unreadNotifications = 3;
  int _currentIndex = 0; // 0 = Dashboard, 1 = Visitor Log
  String? _selectedBuilding; // Selected building for filtering
  List<String> _availableBuildings = []; // List of available buildings

  // Keep alive to preserve state
  @override
  bool get wantKeepAlive => true;

  // Store visitor log screen instance to preserve state
  final VisitorsLogScreen _visitorsLogScreen = const VisitorsLogScreen();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    await _loadAvailableBuildings();
    _loadDashboardData();
    _setupSocketListeners();
  }

  Future<void> _loadAvailableBuildings() async {
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userRole = userData['role'] ?? 'resident';

        // For residents, use their building
        if (userRole == 'resident') {
          final building = userData['wing'] ?? userData['building'];
          if (building != null) {
            setState(() {
              _availableBuildings = [building.toString().toUpperCase()];
              _selectedBuilding = building.toString().toUpperCase();
            });
          }
        } else {
          // For staff/admin, load all buildings from API
          try {
            if (userRole == 'admin') {
              final response = await ApiService.get(
                ApiConstants.adminBuildings,
              );
              if (response['success'] == true) {
                final buildings = List<Map<String, dynamic>>.from(
                  response['data']?['buildings'] ?? [],
                );
                final buildingCodes = buildings
                    .map(
                      (b) => (b['code'] ?? b['name'] ?? '')
                          .toString()
                          .toUpperCase(),
                    )
                    .where((b) => b.isNotEmpty)
                    .toList()
                    .cast<String>();
                setState(() {
                  _availableBuildings = ['ALL', ...buildingCodes];
                  if (_selectedBuilding == null ||
                      !_availableBuildings.contains(_selectedBuilding)) {
                    _selectedBuilding = 'ALL';
                  }
                });
              }
            } else {
              // For staff, load assigned buildings from API
              final response = await ApiService.get(
                ApiConstants.staffBuildings,
              );
              if (response['success'] == true) {
                final buildings = List<Map<String, dynamic>>.from(
                  response['data']?['buildings'] ?? [],
                );
                final buildingCodes = buildings
                    .map(
                      (b) => (b['code'] ?? b['name'] ?? '')
                          .toString()
                          .toUpperCase(),
                    )
                    .where((b) => b.isNotEmpty)
                    .toList()
                    .cast<String>();
                setState(() {
                  if (buildingCodes.isNotEmpty) {
                    _availableBuildings = buildingCodes;
                    if (_selectedBuilding == null ||
                        !_availableBuildings.contains(_selectedBuilding)) {
                      _selectedBuilding = buildingCodes.first;
                    }
                  } else {
                    _availableBuildings = [];
                    _selectedBuilding = null;
                  }
                });
              } else {
                setState(() {
                  _availableBuildings = [];
                  _selectedBuilding = null;
                });
              }
            }
          } catch (e) {
            print('Error loading buildings from API: $e');
            // Fallback to default
            setState(() {
              _availableBuildings = ['ALL'];
              _selectedBuilding = 'ALL';
            });
          }
        }
      } catch (e) {
        print('Error loading buildings: $e');
      }
    }
  }

  void _loadUserData() {
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        setState(() {
          _user = jsonDecode(userJson);
        });
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }
  }

  void _setupSocketListeners() {
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          socketService.connect(userId);

          socketService.on('visitor_created', (data) {
            if (mounted) {
              _loadDashboardData();
            }
          });

          socketService.on('visitor_checked_in', (data) {
            if (mounted) {
              _loadDashboardData();
            }
          });

          socketService.on('visitor_checked_out', (data) {
            if (mounted) {
              _loadDashboardData();
            }
          });
        }
      } catch (e) {
        print('Error setting up socket: $e');
      }
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final userRole = _user?['role'] ?? 'resident';
      final isResident = userRole == 'resident';

      // Build query params with building filter
      String statsUrl = ApiConstants.visitorsDashboardStats;
      String visitorsUrl = '${ApiConstants.visitors}?limit=5';

      // For residents, API automatically filters by their flat, so no need to add building filter
      // For staff/admin, add building filter if selected
      if (!isResident &&
          _selectedBuilding != null &&
          _selectedBuilding != 'ALL') {
        statsUrl += '?building=${Uri.encodeComponent(_selectedBuilding!)}';
        visitorsUrl += '&building=${Uri.encodeComponent(_selectedBuilding!)}';
      }

      // Load visitor stats
      final statsResponse = await ApiService.get(statsUrl);
      if (statsResponse['success'] == true) {
        setState(() {
          _stats = statsResponse['data']?['stats'];
        });
      }

      // Load recent visitors
      final visitorsResponse = await ApiService.get(visitorsUrl);
      if (visitorsResponse['success'] == true) {
        setState(() {
          _recentActivity = List<Map<String, dynamic>>.from(
            visitorsResponse['data']?['visitors'] ?? [],
          );
        });
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getApartmentName() {
    return _user?['apartmentCode'] ?? 'Greenview Apartments';
  }

  String _getStatusBadge(String status) {
    switch (status?.toLowerCase()) {
      case 'approved':
      case 'checked in':
        return 'approved';
      case 'pending':
        return 'pending';
      case 'completed':
      case 'checked out':
        return 'completed';
      default:
        return 'pending';
    }
  }

  Color _getStatusColor(String status) {
    switch (status?.toLowerCase()) {
      case 'approved':
      case 'checked in':
      case 'completed':
      case 'checked out':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      default:
        return AppColors.textLight;
    }
  }

  IconData _getVisitorTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'guest':
        return Icons.person;
      case 'delivery':
        return Icons.local_shipping;
      case 'vendor':
        return Icons.build;
      case 'cab / ride':
        return Icons.local_taxi;
      case 'domestic help':
        return Icons.home;
      case 'realtor / sales':
        return Icons.business;
      case 'emergency services':
        return Icons.emergency;
      default:
        return Icons.person;
    }
  }

  Color _getVisitorTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'guest':
        return AppColors.primary;
      case 'delivery':
        return AppColors.secondaryDark;
      case 'vendor':
        return AppColors.warning;
      case 'cab / ride':
        return AppColors.error;
      case 'domestic help':
        return AppColors.secondary;
      case 'realtor / sales':
        return AppColors.info;
      case 'emergency services':
        return AppColors.error;
      default:
        return AppColors.textLight;
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: AppColors.textOnPrimary),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visitor Dashboard',
            style: TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _getApartmentName(),
            style: TextStyle(
              color: AppColors.textOnPrimary.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.textOnPrimary),
          onPressed: () {
            _loadDashboardData();
          },
          tooltip: 'Refresh',
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: AppColors.textOnPrimary,
              ),
              onPressed: () {},
            ),
            if (_unreadNotifications > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_unreadNotifications',
                    style: const TextStyle(
                      color: AppColors.textOnPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    final userRole = _user?['role'] ?? 'resident';
    final isResident = userRole == 'resident';

    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        : RefreshIndicator(
            onRefresh: _loadDashboardData,
            color: AppColors.primary,
            backgroundColor: AppColors.background,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Building Filter Selection (only for staff/admin, not residents)
                  if (!isResident && _availableBuildings.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.apartment,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedBuilding == 'ALL'
                                    ? 'All Buildings'
                                    : 'Building $_selectedBuilding',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                _showBuildingSelector();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Change',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Stats Cards - Simple Box Design (Small Size)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        // First Row - Main Stats
                        Row(
                          children: [
                            Expanded(
                              child: _SimpleStatCard(
                                title: 'Visitors Today',
                                value: '${_stats?['visitorsToday'] ?? 0}',
                                icon: Icons.people_outline,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SimpleStatCard(
                                title: 'Currently Inside',
                                value: '${_stats?['currentlyInside'] ?? 0}',
                                icon: Icons.check_circle_outline,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Second Row - Alert Stats
                        Row(
                          children: [
                            Expanded(
                              child: _SimpleStatCard(
                                title: 'Overstay Alert',
                                value: '${_stats?['overstayAlert'] ?? 0}',
                                icon: Icons.warning_amber_rounded,
                                color: AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SimpleStatCard(
                                title: 'Pending Approval',
                                value: '${_stats?['pending'] ?? 0}',
                                icon: Icons.access_time_filled,
                                color: AppColors.info,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Recent Activity Section - Enhanced Professional Design
                  Container(
                    margin: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with gradient
                        Container(
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
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(
                                        0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.history,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Recent Activity',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _currentIndex = 1;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'View All',
                                        style: TextStyle(
                                          color: AppColors.textOnPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: AppColors.textOnPrimary,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              if (_recentActivity.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 40.0,
                                  ),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.event_note_outlined,
                                            size: 48,
                                            color: AppColors.textLight,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No recent activity',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Visitor activities will appear here',
                                          style: TextStyle(
                                            color: AppColors.textLight,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ..._recentActivity
                                    .take(5)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                      final index = entry.key;
                                      final activity = entry.value;
                                      return _EnhancedActivityItem(
                                        activity: activity,
                                        index: index,
                                        getVisitorTypeIcon: _getVisitorTypeIcon,
                                        getVisitorTypeColor:
                                            _getVisitorTypeColor,
                                        getStatusBadge: _getStatusBadge,
                                        getStatusColor: _getStatusColor,
                                      );
                                    })
                                    .toList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final userRole = _user?['role'] ?? 'resident';
    final isResident = userRole == 'resident';

    // For residents, show only visitor log (no dashboard, no bottom nav)
    if (isResident) {
      return _visitorsLogScreen;
    }

    // For staff/admin, show the full dashboard with navigation
    return IndexedStack(
      index: _currentIndex,
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(),
          body: _buildBody(),
          bottomNavigationBar: _buildBottomNavigationBar(),
        ),
        _visitorsLogScreen,
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    final userRole = _user?['role'] ?? 'resident';
    final isResident = userRole == 'resident';

    // Don't show bottom nav for residents
    if (isResident) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        backgroundColor: AppColors.surface,
        elevation: 0,
        selectedFontSize: 13,
        unselectedFontSize: 12,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Visitor Log',
          ),
        ],
      ),
    );
  }

  void _showBuildingSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Building',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _availableBuildings.length,
                itemBuilder: (context, index) {
                  final building = _availableBuildings[index];
                  final isSelected = building == _selectedBuilding;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.apartment,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    title: Text(
                      building == 'ALL'
                          ? 'All Buildings'
                          : 'Building $building',
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedBuilding = building;
                      });
                      Navigator.pop(context);
                      _loadDashboardData();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SimpleStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SimpleStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 18),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2), width: 1),
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
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? borderColor;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 2)
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EnhancedActivityItem extends StatelessWidget {
  final Map<String, dynamic> activity;
  final int index;
  final Function(String?) getVisitorTypeIcon;
  final Function(String?) getVisitorTypeColor;
  final Function(String) getStatusBadge;
  final Function(String) getStatusColor;

  const _EnhancedActivityItem({
    required this.activity,
    required this.index,
    required this.getVisitorTypeIcon,
    required this.getVisitorTypeColor,
    required this.getStatusBadge,
    required this.getStatusColor,
  });

  String _formatTime(String? dateTime) {
    if (dateTime == null) return '';
    try {
      final dt = DateTime.parse(dateTime);
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        final day = dt.day.toString().padLeft(2, '0');
        final month = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ][dt.month - 1];
        return '$day $month';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitorType = activity['visitorType'] ?? 'Guest';
    final status = activity['status'] ?? 'Pending';
    final building = activity['building'] ?? '';
    final flatNumber = activity['flatNumber'] ?? '';
    final entryDate = activity['entryDate'] ?? activity['checkInTime'];
    final visitorName = activity['visitorName'] ?? 'Unknown';

    return Container(
      margin: EdgeInsets.only(bottom: index < 4 ? 12 : 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container with gradient
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  getVisitorTypeColor(visitorType).withOpacity(0.2),
                  getVisitorTypeColor(visitorType).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: getVisitorTypeColor(visitorType).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              getVisitorTypeIcon(visitorType),
              color: getVisitorTypeColor(visitorType),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        visitorName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: getStatusColor(status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: getStatusColor(status).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        getStatusBadge(status).toUpperCase(),
                        style: TextStyle(
                          color: getStatusColor(status),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.apartment_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$building - $flatNumber',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time_outlined,
                      size: 12,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(entryDate),
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> activity;
  final Function(String?) getVisitorTypeIcon;
  final Function(String?) getVisitorTypeColor;
  final Function(String) getStatusBadge;
  final Function(String) getStatusColor;

  const _ActivityItem({
    required this.activity,
    required this.getVisitorTypeIcon,
    required this.getVisitorTypeColor,
    required this.getStatusBadge,
    required this.getStatusColor,
  });

  String _formatTime(String? dateTime) {
    if (dateTime == null) return '';
    try {
      final dt = DateTime.parse(dateTime);
      final day = dt.day.toString().padLeft(2, '0');
      final month = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][dt.month - 1];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day $month, $hour:$minute $period';
    } catch (e) {
      return '';
    }
  }

  String _formatTimeShort(String? dateTime) {
    if (dateTime == null) return '';
    try {
      final dt = DateTime.parse(dateTime);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitorType = activity['visitorType'] ?? 'Guest';
    final status = activity['status'] ?? 'Pending';
    final building = activity['building'] ?? '';
    final flatNumber = activity['flatNumber'] ?? '';
    final purpose = activity['purpose'] ?? '';
    final entryDate = activity['entryDate'];
    final checkInTime = activity['checkInTime'];
    final checkOutTime = activity['checkOutTime'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: getVisitorTypeColor(visitorType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: getVisitorTypeColor(visitorType).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              getVisitorTypeIcon(visitorType),
              color: getVisitorTypeColor(visitorType),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['visitorName'] ?? 'Unknown',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.apartment,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$building - $flatNumber',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        getStatusBadge(status).toUpperCase(),
                        style: TextStyle(
                          color: getStatusColor(status),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Show entry time or check-in time
                if (entryDate != null || checkInTime != null)
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entryDate != null
                            ? 'Entry: ${_formatTimeShort(entryDate)}'
                            : checkInTime != null
                            ? 'In: ${_formatTimeShort(checkInTime)}'
                            : '',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
