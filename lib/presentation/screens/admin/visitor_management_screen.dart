import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';

class VisitorManagementScreen extends StatefulWidget {
  const VisitorManagementScreen({super.key});

  @override
  State<VisitorManagementScreen> createState() => _VisitorManagementScreenState();
}

class _VisitorManagementScreenState extends State<VisitorManagementScreen> {
  List<Map<String, dynamic>> _visitors = [];
  List<Map<String, dynamic>> _filteredVisitors = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, checked-in, checked-out, overdue
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
          } else if (visitor['status']?.toLowerCase() != _selectedFilter.replaceAll('-', '')) {
            return false;
          }
        }
        
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return (visitor['visitorName']?.toString().toLowerCase().contains(query) ?? false) ||
              (visitor['phoneNumber']?.toString().contains(query) ?? false) ||
              (visitor['visitorType']?.toString().toLowerCase().contains(query) ?? false);
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
        AppMessageHandler.showSuccess(context, 'Visitor checked in successfully');
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
        AppMessageHandler.showSuccess(context, 'Visitor checked out successfully');
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVisitors,
          ),
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
                    children: [
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
                    ? const Center(
                        child: Text('No visitors found'),
                      )
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
    final isOverdue = _selectedFilter == 'overdue' || 
        (isCheckedIn && visitor['expectedCheckOutTime'] != null &&
         DateTime.now().isAfter(DateTime.parse(visitor['expectedCheckOutTime'])));

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
            Text('Type: ${visitor['visitorType'] ?? 'Guest'}'),
            Text('Phone: ${visitor['phoneNumber'] ?? 'N/A'}'),
            if (visitor['hostResident'] != null)
              Text(
                'Host: ${visitor['hostResident']['fullName'] ?? 'N/A'} - ${visitor['wing']}-${visitor['flatNumber']}',
              ),
            if (isCheckedIn && visitor['checkInTime'] != null)
              Text(
                'Checked in: ${_formatDateTime(visitor['checkInTime'])}',
                style: const TextStyle(fontSize: 12),
              ),
            if (isOverdue)
              const Text(
                '⚠️ OVERDUE',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: isCheckedIn
            ? ElevatedButton(
                onPressed: () => _checkOutVisitor(visitor['_id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Check Out'),
              )
            : status == 'Pending' || status == 'Pre-Approved'
                ? ElevatedButton(
                    onPressed: () => _checkInVisitor(visitor['_id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Check In'),
                  )
                : Chip(
                    label: Text(status),
                    backgroundColor: statusColor.withOpacity(0.2),
                  ),
        onTap: () {
          // Navigate to visitor details
          // Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorDetailScreen(visitorId: visitor['_id'])));
        },
      ),
    );
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }
}

