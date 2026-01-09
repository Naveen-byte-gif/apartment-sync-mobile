import 'package:apartment_aync_mobile/presentation/screens/visitors/visitor_detail_screen.dart';
import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';

class VisitorManagementScreen extends StatefulWidget {
  const VisitorManagementScreen({super.key});

  @override
  State<VisitorManagementScreen> createState() =>
      _VisitorManagementScreenState();
}

class _VisitorManagementScreenState extends State<VisitorManagementScreen> {
  List<Map<String, dynamic>> _visitors = [];
  List<Map<String, dynamic>> _filteredVisitors = [];
  bool _isLoading = true;
  String _selectedFilter =
      'all'; // all, pending, checked-in, checked-out, overdue
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadVisitors();
    _setupSocketListeners();
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

          socketService.on('visitor_checked_in', (data) {
            if (mounted) {
              _loadVisitors();
              AppMessageHandler.showSuccess(context, 'Visitor checked in');
            }
          });

          socketService.on('visitor_checked_out', (data) {
            if (mounted) {
              _loadVisitors();
              AppMessageHandler.showSuccess(context, 'Visitor checked out');
            }
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
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredVisitors = _visitors.where((visitor) {
        // Status filter
        if (_selectedFilter != 'all') {
          if (_selectedFilter == 'overdue') {
            if (visitor['status'] != 'Checked In') return false;
            final expectedCheckOut = visitor['expectedCheckOutTime'];
            if (expectedCheckOut != null) {
              final checkOutTime = DateTime.parse(expectedCheckOut);
              if (DateTime.now().isBefore(checkOutTime)) return false;
            } else {
              return false;
            }
          } else if (visitor['status']?.toLowerCase() !=
              _selectedFilter.replaceAll('-', '')) {
            return false;
          }
        }

        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return (visitor['visitorName']?.toString().toLowerCase().contains(
                    query,
                  ) ??
                  false) ||
              (visitor['phoneNumber']?.toString().contains(query) ?? false) ||
              (visitor['visitorType']?.toString().toLowerCase().contains(
                    query,
                  ) ??
                  false);
        }

        return true;
      }).toList();
    });
  }

  Future<void> _checkInVisitor(String visitorId) async {
    try {
      final response = await ApiService.post(
        ApiConstants.visitorCheckIn(visitorId),
        {'checkInMethod': 'Manual'},
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(
          context,
          'Visitor checked in successfully',
        );
        _loadVisitors();
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  Future<void> _checkOutVisitor(String visitorId) async {
    try {
      final response = await ApiService.post(
        ApiConstants.visitorCheckOut(visitorId),
        {},
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(
          context,
          'Visitor checked out successfully',
        );
        _loadVisitors();
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Management'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadVisitors),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search visitors...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        [
                          'all',
                          'pending',
                          'checked-in',
                          'checked-out',
                          'overdue',
                        ].map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(filter.toUpperCase()),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedFilter = filter;
                                  _applyFilters();
                                });
                              },
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Visitors List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVisitors.isEmpty
                ? const Center(child: Text('No visitors found'))
                : RefreshIndicator(
                    onRefresh: _loadVisitors,
                    child: ListView.builder(
                      itemCount: _filteredVisitors.length,
                      itemBuilder: (context, index) {
                        final visitor = _filteredVisitors[index];
                        return _buildVisitorCard(visitor);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to create visitor screen
          // Navigator.push(context, MaterialPageRoute(builder: (_) => CreateVisitorScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildVisitorCard(Map<String, dynamic> visitor) {
    final status = visitor['status'] ?? 'Pending';
    final isCheckedIn = status == 'Checked In';
    final isOverdue =
        _selectedFilter == 'overdue' ||
        (isCheckedIn &&
            visitor['expectedCheckOutTime'] != null &&
            DateTime.now().isAfter(
              DateTime.parse(visitor['expectedCheckOutTime']),
            ));

    Color statusColor;
    switch (status) {
      case 'Checked In':
        statusColor = isOverdue ? Colors.red : Colors.green;
        break;
      case 'Checked Out':
        statusColor = Colors.grey;
        break;
      case 'Pre-Approved':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Text(
            visitor['visitorName']?[0]?.toUpperCase() ?? 'V',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          visitor['visitorName'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show Status
            Row(
              children: [
                Icon(_getStatusIcon(status), size: 16, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  'Status: $status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Show Login Time (Check-in Time)
            if (visitor['checkInTime'] != null)
              Row(
                children: [
                  const Icon(Icons.login, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    'Login: ${_formatDateTime(visitor['checkInTime'])}',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            // Show Exact Time if set
            if (visitor['exactTime'] != null)
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Exact: ${_formatDateTime(visitor['exactTime'])}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Text(
                    'Exact: Not set',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusActions(visitor, status, isCheckedIn, statusColor),
            const SizedBox(height: 4),
            // Exact Time Button
            if (visitor['exactTime'] == null)
              ElevatedButton(
                onPressed: () => _showExactTimeDialog(visitor['_id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(60, 30),
                ),
                child: const Text('Exact', style: TextStyle(fontSize: 10)),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisitorDetailScreen(visitorId: visitor['_id']),
            ),
          ).then((_) => _loadVisitors());
        },
      ),
    );
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime);
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day/$month/$year $hour:$minute $period';
    } catch (e) {
      return dateTime;
    }
  }

  Widget _buildStatusActions(
    Map<String, dynamic> visitor,
    String status,
    bool isCheckedIn,
    Color statusColor,
  ) {
    if (isCheckedIn) {
      return ElevatedButton(
        onPressed: () => _checkOutVisitor(visitor['_id']),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: const Text('Check Out'),
      );
    } else if (status == 'Pending') {
      // Show Check In button for Pending (removed Approve/Reject)
      return ElevatedButton(
        onPressed: () => _checkInVisitor(visitor['_id']),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: const Text('Check In'),
      );
    } else if (status == 'Pre-Approved') {
      return ElevatedButton(
        onPressed: () => _checkInVisitor(visitor['_id']),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: const Text('Check In'),
      );
    } else {
      return Chip(
        label: Text(status),
        backgroundColor: statusColor.withOpacity(0.2),
      );
    }
  }

  Future<void> _updateVisitorStatus(String visitorId, String newStatus) async {
    try {
      // Show confirmation dialog for rejection
      if (newStatus == 'Rejected') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reject Visitor'),
            content: const Text(
              'Are you sure you want to reject this visitor entry?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Reject',
                  style: TextStyle(color: Colors.red),
                ),
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.pending;
      case 'Pre-Approved':
        return Icons.check_circle_outline;
      case 'Checked In':
        return Icons.login;
      case 'Checked Out':
        return Icons.logout;
      case 'Rejected':
        return Icons.cancel;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Future<void> _showExactTimeDialog(String visitorId) async {
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
      await _setExactTime(visitorId);
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
}
