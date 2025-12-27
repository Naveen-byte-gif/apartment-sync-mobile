import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import '../../screens/complaints/resident_complaints_screen.dart';
import '../../screens/notices/notices_screen.dart';
import '../../screens/auth/role_selection_screen.dart';
import 'dart:convert';

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  UserData? _user;
  Map<String, dynamic>? _buildingData;
  Map<String, dynamic>? _flatData;
  Map<String, dynamic>? _dashboardData;
  List<Map<String, dynamic>> _activeComplaints = [];
  int _unreadNotifications = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for resident home');
    final socketService = SocketService();
    final userId = _user?.id ?? '';
    if (userId.isNotEmpty) {
      socketService.connect(userId);

      // Listen for real-time updates
      socketService.on('complaint_created', (data) {
        print('📡 [FLUTTER] Complaint created event received');
        _loadData(); // Refresh data
      });

      socketService.on('complaint_updated', (data) {
        print('📡 [FLUTTER] Complaint updated event received');
        _loadData(); // Refresh data
      });

      socketService.on('new_notice', (data) {
        print('📡 [FLUTTER] New notice event received');
        setState(() => _unreadNotifications++);
        _loadData(); // Refresh data
      });

      // Listen for flat status updates
      socketService.on('flat_status_updated', (data) {
        print('📡 [FLUTTER] Flat status updated event received');
        if (mounted) {
          _loadData(); // Refresh data
          AppMessageHandler.showInfo(context, 'Flat status updated');
        }
      });

      // Listen for building updates
      socketService.on('building_updated', (data) {
        print('📡 [FLUTTER] Building updated event received');
        if (mounted) {
          _loadData(); // Refresh data
        }
      });
    }
  }

  Future<void> _loadData() async {
    print('🖱️ [FLUTTER] Loading resident home data...');
    setState(() => _isLoading = true);

    try {
      // Load user data from snapshot first
      final userJson = StorageService.getString(AppConstants.userKey);
      if (userJson != null) {
        try {
          setState(() {
            _user = UserData.fromJson(jsonDecode(userJson));
          });
          print('👤 [FLUTTER] User loaded: ${_user?.fullName}');
        } catch (e) {
          print('❌ [FLUTTER] Error parsing user data: $e');
        }
      }

      // Check if user is authenticated
      final token = StorageService.getString(AppConstants.tokenKey);
      if (token == null || token.isEmpty) {
        print('⚠️ [FLUTTER] No authentication token found');
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
            (route) => false,
          );
        }
        return;
      }

      // Load dashboard data
      print('📊 [FLUTTER] Loading dashboard data...');
      final dashboardResponse = await ApiService.get('/users/dashboard');
      if (dashboardResponse['success'] == true) {
        setState(() {
          _dashboardData = dashboardResponse['data']?['dashboard'];
          _activeComplaints = List<Map<String, dynamic>>.from(
            dashboardResponse['data']?['activeComplaints'] ?? [],
          );
        });
        print('✅ [FLUTTER] Dashboard data loaded');
      } else if (dashboardResponse['message']?.toString().toLowerCase().contains('not authorized') == true ||
                 dashboardResponse['message']?.toString().toLowerCase().contains('unauthorized') == true) {
        print('⚠️ [FLUTTER] Authentication failed, redirecting to login');
        if (mounted) {
          await StorageService.remove(AppConstants.tokenKey);
          await StorageService.remove(AppConstants.userKey);
          ApiService.setToken(null);
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
        return;
      }

      // Load building and flat details
      print('🏠 [FLUTTER] Loading building and flat details...');
      final buildingResponse = await ApiService.get(
        ApiConstants.buildingDetails,
      );
      if (buildingResponse['success'] == true) {
        setState(() {
          _buildingData = buildingResponse['data']?['building'];
          _flatData = buildingResponse['data']?['flat'];
        });
        print('✅ [FLUTTER] Building details loaded');
      }

      // Load unread notifications count
      print('🔔 [FLUTTER] Loading notifications count...');
      final noticesResponse = await ApiService.get(ApiConstants.announcements);
      if (noticesResponse['success'] == true) {
        final notices = noticesResponse['data']?['notices'] ?? [];
        setState(() {
          _unreadNotifications = notices
              .where((n) => n['isRead'] == false)
              .length;
        });
        print('✅ [FLUTTER] Notifications count: $_unreadNotifications');
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading data: $e');
      // Check if it's an authentication error
      if (e.toString().toLowerCase().contains('unauthorized') || 
          e.toString().toLowerCase().contains('401')) {
        print('⚠️ [FLUTTER] Authentication error, redirecting to login');
        if (mounted) {
          await StorageService.remove(AppConstants.tokenKey);
          await StorageService.remove(AppConstants.userKey);
          ApiService.setToken(null);
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
        return;
      }
      
      if (mounted && _user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.primaryDark],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Header
                        _buildHeader(),
                        // Content
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              // Summary Cards
                              _buildSummaryCards(),
                              const SizedBox(height: 20),
                              // Active Complaints
                              if (_activeComplaints.isNotEmpty)
                                _buildActiveComplaints(),
                              const SizedBox(height: 20),
                              // Quick Actions
                              _buildQuickActions(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                _user?.fullName[0].toUpperCase() ?? 'R',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textOnPrimary.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _user?.fullName ?? 'Resident',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_buildingData != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.apartment,
                        size: 14,
                        color: AppColors.textOnPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _buildingData!['name'] ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textOnPrimary.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_flatData != null && _flatData!['flatCode'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.home,
                        size: 14,
                        color: AppColors.textOnPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_flatData!['flatCode']}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textOnPrimary.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              print('🖱️ [FLUTTER] Notifications icon tapped');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NoticesScreen()),
              );
            },
            child: Stack(
              children: [
                const Icon(
                  Icons.notifications,
                  color: AppColors.textOnPrimary,
                  size: 28,
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          _unreadNotifications > 9
                              ? '9+'
                              : '$_unreadNotifications',
                          style: const TextStyle(
                            color: AppColors.textOnPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Comprehensive Flat Details Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                        child: const Icon(Icons.home, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Flat Details',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _flatData?['flatCode'] ?? _user?.flatCode ?? 'N/A',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
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
                        child: _FlatInfoItem(
                          icon: Icons.layers,
                          label: 'Floor',
                          value: '${_flatData?['floorNumber'] ?? _user?.floorNumber ?? 'N/A'}',
                        ),
                      ),
                      Expanded(
                        child: _FlatInfoItem(
                          icon: Icons.tag,
                          label: 'Flat Number',
                          value: _flatData?['flatNumber'] ?? _user?.flatNumber ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FlatInfoItem(
                          icon: Icons.category,
                          label: 'Flat Type',
                          value: _flatData?['flatType'] ?? _user?.flatType ?? 'N/A',
                        ),
                      ),
                      if (_flatData?['squareFeet'] != null)
                        Expanded(
                          child: _FlatInfoItem(
                            icon: Icons.square_foot,
                            label: 'Area',
                            value: '${_flatData!['squareFeet']} sq.ft',
                          ),
                        ),
                    ],
                  ),
                  if (_user?.registeredAt != null || _user?.lastUpdatedAt != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    if (_user?.registeredAt != null)
                      _FlatInfoItem(
                        icon: Icons.calendar_today,
                        label: 'Registered At',
                        value: _formatDate(_user!.registeredAt!),
                      ),
                    if (_user?.lastUpdatedAt != null) ...[
                      const SizedBox(height: 8),
                      _FlatInfoItem(
                        icon: Icons.update,
                        label: 'Last Updated',
                        value: _formatDate(_user!.lastUpdatedAt!),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Active Complaints',
                  value:
                      '${_dashboardData?['activeComplaints'] ?? _activeComplaints.length}',
                  subtitle: '${_dashboardData?['totalComplaints'] ?? 0} total',
                  icon: Icons.description,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: 'Notices',
                  value: '$_unreadNotifications',
                  subtitle: 'Unread',
                  icon: Icons.notifications,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveComplaints() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [ 
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Complaints',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  print('🖱️ [FLUTTER] View all complaints tapped');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResidentComplaintsScreen(),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._activeComplaints.take(3).map((complaint) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.description,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          complaint['title'] ?? 'No Title',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ticket: ${complaint['ticketNumber'] ?? 'N/A'}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        if (complaint['createdAt'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: AppColors.textLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateRelative(complaint['createdAt']),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: AppColors.textLight),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(complaint['status'] ?? 'Open'),
                    backgroundColor: _getStatusColor(
                      complaint['status'],
                    ).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _getStatusColor(complaint['status']),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.add_circle,
                  title: 'New Complaint',
                  color: AppColors.primary,
                  onTap: () {
                    print('🖱️ [FLUTTER] New complaint quick action');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ResidentComplaintsScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.notifications,
                  title: 'Notices',
                  color: AppColors.info,
                  onTap: () {
                    print('🖱️ [FLUTTER] Notices quick action');
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NoticesScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'open':
        return AppColors.error;
      case 'assigned':
        return AppColors.warning;
      case 'in progress':
        return AppColors.info;
      case 'resolved':
        return AppColors.success;
      default:
        return AppColors.textLight;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatDateRelative(dynamic date) {
    if (date == null) return '';
    try {
      final dateTime = date is String ? DateTime.parse(date) : date as DateTime;
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }
}

class _FlatInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _FlatInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
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
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
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
