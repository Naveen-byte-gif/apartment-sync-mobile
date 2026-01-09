import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';
import 'new_visitor_entry_screen.dart';
import 'visitor_detail_screen.dart';

class VisitorsLogScreen extends StatefulWidget {
  const VisitorsLogScreen({super.key});

  @override
  State<VisitorsLogScreen> createState() => _VisitorsLogScreenState();
}

class _VisitorsLogScreenState extends State<VisitorsLogScreen> {
  List<Map<String, dynamic>> _visitors = [];
  List<Map<String, dynamic>> _filteredVisitors = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadVisitors();
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
            if (mounted) _loadVisitors();
          });

          socketService.on('visitor_checked_in', (data) {
            if (mounted) _loadVisitors();
          });

          socketService.on('visitor_checked_out', (data) {
            if (mounted) _loadVisitors();
          });
        }
      } catch (e) {
        print('Error setting up socket: $e');
      }
    }
  }

  Future<void> _loadVisitors() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get(ApiConstants.visitors);
      if (response['success'] == true) {
        setState(() {
          _visitors = List<Map<String, dynamic>>.from(
            response['data']?['visitors'] ?? [],
          );
          _applyFilters();
        });
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  void _applyFilters() {
    setState(() {
      _filteredVisitors = _visitors.where((visitor) {
        // Search filter only (removed status filters)
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return (visitor['visitorName']?.toString().toLowerCase().contains(query) ?? false) ||
              (visitor['phoneNumber']?.toString().contains(query) ?? false) ||
              (visitor['visitorType']?.toString().toLowerCase().contains(query) ?? false) ||
              (visitor['building']?.toString().toLowerCase().contains(query) ?? false) ||
              (visitor['flatNumber']?.toString().toLowerCase().contains(query) ?? false);
        }

        return true;
      }).toList();
    });
  }

  Future<void> _markExit(String visitorId) async {
    try {
      final response = await ApiService.post(
        ApiConstants.visitorCheckOut(visitorId),
        {},
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(context, 'Visitor checked out successfully');
        _loadVisitors();
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  Future<void> _updateVisitorStatus(String visitorId, String newStatus) async {
    try {
      if (newStatus == 'Rejected') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reject Visitor'),
            content: const Text('Are you sure you want to reject this visitor entry?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reject', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      final response = await ApiService.put(
        ApiConstants.visitorStatus(visitorId),
        {'status': newStatus},
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(
          context,
          'Visitor status updated to $newStatus',
        );
        _loadVisitors();
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  Future<void> _checkInVisitor(String visitorId) async {
    try {
      final response = await ApiService.post(
        ApiConstants.visitorCheckIn(visitorId),
        {'checkInMethod': 'Manual'},
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(context, 'Visitor checked in successfully');
        _loadVisitors();
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  Future<void> _setExactTime(String visitorId) async {
    try {
      final response = await ApiService.put(
        ApiConstants.visitorExactTime(visitorId),
        {},
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(context, 'Exact time set successfully');
        _loadVisitors();
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  String _formatTime(String? dateTime) {
    if (dateTime == null) return '';
    try {
      final dt = DateTime.parse(dateTime);
      final day = dt.day.toString().padLeft(2, '0');
      final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dt.month - 1];
      final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day $month, $hour:$minute $period';
    } catch (e) {
      return '';
    }
  }

  String _getDurationInside(String? checkInTime) {
    if (checkInTime == null) return '';
    try {
      final dt = DateTime.parse(checkInTime);
      final now = DateTime.now();
      final diff = now.difference(dt);
      final minutes = diff.inMinutes;
      if (minutes < 60) {
        return '$minutes minutes inside';
      } else {
        final hours = minutes ~/ 60;
        final mins = minutes % 60;
        return '$hours hours $mins minutes inside';
      }
    } catch (e) {
      return '';
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
      default:
        return Icons.person;
    }
  }

  Color _getVisitorTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'guest':
        return Colors.purple;
      case 'delivery':
        return Colors.brown;
      case 'vendor':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = _user?['role'] ?? 'resident';
    final isResident = userRole == 'resident';

    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
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
              'Visitors Log',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Today's entries",
              style: TextStyle(
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
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
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
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search visitors...',
                hintStyle: TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1A2332),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Visitors List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _filteredVisitors.isEmpty
                    ? Center(
                        child: Text(
                          'No visitors found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadVisitors,
                        color: Colors.white,
                        backgroundColor: const Color(0xFF0F1419),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredVisitors.length,
                          itemBuilder: (context, index) {
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VisitorDetailScreen(
                                      visitorId: _filteredVisitors[index]['_id'],
                                    ),
                                  ),
                                ).then((_) => _loadVisitors());
                              },
                              child: _VisitorCard(
                                visitor: _filteredVisitors[index],
                                isResident: isResident,
                                onMarkExit: _markExit,
                                onUpdateStatus: _updateVisitorStatus,
                                onCheckIn: _checkInVisitor,
                                onSetExactTime: _setExactTime,
                                formatTime: _formatTime,
                                getDurationInside: _getDurationInside,
                                getVisitorTypeIcon: _getVisitorTypeIcon,
                                getVisitorTypeColor: _getVisitorTypeColor,
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: isResident
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NewVisitorEntryScreen(),
                  ),
                ).then((_) => _loadVisitors());
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      // Removed bottom navigation bar as per requirements
    );
  }

}

class _VisitorCard extends StatelessWidget {
  final Map<String, dynamic> visitor;
  final bool isResident;
  final Function(String) onMarkExit;
  final Function(String, String) onUpdateStatus;
  final Function(String) onCheckIn;
  final Function(String) onSetExactTime;
  final Function(String?) formatTime;
  final Function(String?) getDurationInside;
  final Function(String?) getVisitorTypeIcon;
  final Function(String?) getVisitorTypeColor;

  const _VisitorCard({
    required this.visitor,
    required this.isResident,
    required this.onMarkExit,
    required this.onUpdateStatus,
    required this.onCheckIn,
    required this.onSetExactTime,
    required this.formatTime,
    required this.getDurationInside,
    required this.getVisitorTypeIcon,
    required this.getVisitorTypeColor,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'pre-approved':
        return Colors.blue;
      case 'checked in':
        return Colors.green;
      case 'checked out':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'pre-approved':
        return Icons.check_circle_outline;
      case 'checked in':
        return Icons.login;
      case 'checked out':
        return Icons.logout;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Future<void> _showExactTimeDialog(BuildContext context, String visitorId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Exact Time'),
        content: const Text('Do you want to set the exact entry time to now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onSetExactTime(visitorId);
    }
  }

  Widget _buildStatusActionButtons(Map<String, dynamic> visitor, bool isInside, Function(String) onMarkExit) {
    final status = visitor['status'] ?? 'Pending';
    
    if (isInside) {
      // Show Check Out button
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => onMarkExit(visitor['_id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            'Mark Exit',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (status == 'Pending') {
      // Show Check In button for Pending (removed Approve/Reject)
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => onCheckIn(visitor['_id']),
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Check In'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    } else if (status == 'Pre-Approved') {
      // Show Check In button
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => onCheckIn(visitor['_id']),
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Check In'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    } else {
      // Show status chip for other statuses
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: _getStatusColor(status).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _getStatusColor(status)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 16),
            const SizedBox(width: 8),
            Text(
              'Status: $status',
              style: TextStyle(
                color: _getStatusColor(status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final building = visitor['building'] ?? '';
    final flatNumber = visitor['flatNumber'] ?? '';
    final checkInTime = visitor['checkInTime'] ?? visitor['entryDate'];
    final hasExited = visitor['checkOutTime'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Visitor Name and Location
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor['visitorName'] ?? 'Unknown Visitor',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$building - $flatNumber',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Login Time Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.login, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Login Time',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        checkInTime != null ? formatTime(checkInTime) : 'Not set',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Exit Time Display (only show if visitor has exited)
          if (hasExited) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.logout, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Exit Time',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatTime(visitor['checkOutTime']),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Exit Button (only show if visitor hasn't exited and user is staff/admin)
          if (!hasExited && !isResident) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showExitConfirmationDialog(context, visitor['_id']),
                icon: const Icon(Icons.exit_to_app, size: 20),
                label: const Text(
                  'Exit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showExitConfirmationDialog(BuildContext context, String visitorId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text(
          'Exit Visitor',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to mark this visitor as exited? This will record the exit time.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onMarkExit(visitorId);
    }
  }

  Widget _buildTimeInfo({
    required IconData icon,
    required String label,
    required String? time,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            time != null ? formatTime(time) : 'Not set',
            style: TextStyle(
              color: time != null ? color : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


