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

class _VisitorDashboardScreenState extends State<VisitorDashboardScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _recentActivity = [];
  bool _isLoading = true;
  int _unreadNotifications = 3;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDashboardData();
    _setupSocketListeners();
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
      // Load visitor stats
      final statsResponse = await ApiService.get(ApiConstants.visitorsDashboardStats);
      if (statsResponse['success'] == true) {
        setState(() {
          _stats = statsResponse['data']?['stats'];
        });
      }

      // Load recent visitors
      final visitorsResponse = await ApiService.get('${ApiConstants.visitors}?limit=5');
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
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
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
        return Colors.blue;
      case 'delivery':
        return Colors.brown;
      case 'vendor':
        return Colors.orange;
      case 'cab / ride':
        return Colors.red;
      case 'domestic help':
        return Colors.brown;
      case 'realtor / sales':
        return Colors.lightBlue;
      case 'emergency services':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = _user?['role'] ?? 'resident';
    final isResident = userRole == 'resident';

    return Scaffold(
      backgroundColor: const Color(0xFF0F1419), // Dark background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _getApartmentName(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () {},
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: Colors.white,
              backgroundColor: const Color(0xFF0F1419),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Cards
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'VISITORS TODAY',
                                  value: '${_stats?['visitorsToday'] ?? 0}',
                                  icon: Icons.people,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  title: 'CURRENTLY INSIDE',
                                  value: '${_stats?['currentlyInside'] ?? 0}',
                                  icon: Icons.check_circle,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'OVERSTAY ALERT',
                                  value: '${_stats?['overstayAlert'] ?? 0}',
                                  icon: Icons.warning,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  title: 'PENDING',
                                  value: '${_stats?['pending'] ?? 0}',
                                  icon: Icons.access_time,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Recent Activity
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Activity',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const VisitorsLogScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'View All >',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_recentActivity.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'No recent activity',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._recentActivity.take(4).map((activity) {
                        return _ActivityItem(
                          activity: activity,
                          getVisitorTypeIcon: _getVisitorTypeIcon,
                          getVisitorTypeColor: _getVisitorTypeColor,
                          getStatusBadge: _getStatusBadge,
                          getStatusColor: _getStatusColor,
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
      // Removed bottom navigation bar as per requirements
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
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white70,
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
      final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dt.month - 1];
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: getVisitorTypeColor(visitorType).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
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
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$visitorType → $building-$flatNumber',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getStatusColor(status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  getStatusBadge(status),
                  style: TextStyle(
                    color: getStatusColor(status),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Show entry time or check-in time
              if (entryDate != null)
                Text(
                  'Entry: ${_formatTimeShort(entryDate)}',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                ),
              if (checkInTime != null && entryDate != null)
                Text(
                  'In: ${_formatTimeShort(checkInTime)}',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                  ),
                ),
              if (checkInTime != null && entryDate == null)
                Text(
                  _formatTimeShort(checkInTime),
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}


