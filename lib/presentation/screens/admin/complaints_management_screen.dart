import '../../../core/imports/app_imports.dart';
import '../../../data/models/complaint_data.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../complaints/complaint_detail_screen.dart';
import 'admin_complaint_detail_screen.dart';

class ComplaintsManagementScreen extends StatefulWidget {
  const ComplaintsManagementScreen({super.key});

  @override
  State<ComplaintsManagementScreen> createState() =>
      ComplaintsManagementScreenState();
}

class ComplaintsManagementScreenState
    extends State<ComplaintsManagementScreen> {
  List<Map<String, dynamic>> _complaints = [];
  List<Map<String, dynamic>> _filteredComplaints = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedCategory = 'all';
  String _selectedPriority = 'all';
  String _selectedWing = 'all';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;

  void toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void refreshComplaints() {
    _loadComplaints();
  }

  // Statistics
  Map<String, int> _statistics = {
    'total': 0,
    'open': 0,
    'inProgress': 0,
    'resolved': 0,
    'rejected': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadComplaints();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for admin complaints');
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          socketService.connect(userId);

          socketService.on('complaint_created', (data) {
            print('📡 [FLUTTER] Complaint created event received');
            if (mounted) {
              _loadComplaints();
            }
          });

          socketService.on('complaint_updated', (data) {
            print('📡 [FLUTTER] Complaint updated event received');
            if (mounted) {
              _loadComplaints();
            }
          });

          socketService.on('status_updated', (data) {
            print('📡 [FLUTTER] Status updated event received');
            if (mounted) {
              _loadComplaints();
            }
          });

          socketService.on('ticket_status_updated', (data) {
            print('📡 [FLUTTER] Ticket status updated event received');
            if (mounted) {
              _loadComplaints();
            }
          });
        }
      } catch (e) {
        print('❌ [FLUTTER] Error setting up socket: $e');
      }
    }
  }

  Future<void> _loadComplaints() async {
    print('🖱️ [FLUTTER] Loading complaints...');
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get(ApiConstants.adminComplaints);
      print('✅ [FLUTTER] Complaints response received');

      if (response['success'] == true) {
        final complaintsList = response['data']?['complaints'] as List?;
        final statistics =
            response['data']?['statistics'] as Map<String, dynamic>?;

        if (complaintsList != null) {
          setState(() {
            _complaints = complaintsList.cast<Map<String, dynamic>>();
            if (statistics != null) {
              _statistics = {
                'total': statistics['total'] ?? 0,
                'open': statistics['open'] ?? 0,
                'inProgress': statistics['inProgress'] ?? 0,
                'resolved': statistics['resolved'] ?? 0,
                'rejected': statistics['rejected'] ?? 0,
              };
            }
            _applyFilters();
          });
          print('✅ [FLUTTER] Loaded ${_complaints.length} complaints');
        }
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading complaints: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading complaints: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredComplaints = _complaints.where((complaint) {
        // Status filter
        if (_selectedStatus != 'all' &&
            complaint['status'] != _selectedStatus) {
          return false;
        }
        // Category filter
        if (_selectedCategory != 'all' &&
            complaint['category'] != _selectedCategory) {
          return false;
        }
        // Priority filter
        if (_selectedPriority != 'all' &&
            complaint['priority'] != _selectedPriority) {
          return false;
        }
        // Wing filter
        if (_selectedWing != 'all') {
          final createdBy = complaint['createdBy'] ?? {};
          if (createdBy['wing'] != _selectedWing) {
            return false;
          }
        }
        // Date range filter
        if (_startDate != null || _endDate != null) {
          final createdAt = complaint['createdAt'] != null
              ? DateTime.parse(complaint['createdAt'])
              : null;
          if (createdAt != null) {
            if (_startDate != null && createdAt.isBefore(_startDate!)) {
              return false;
            }
            if (_endDate != null &&
                createdAt.isAfter(_endDate!.add(const Duration(days: 1)))) {
              return false;
            }
          }
        }
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return (complaint['title']?.toString().toLowerCase().contains(
                    query,
                  ) ??
                  false) ||
              (complaint['ticketNumber']?.toString().toLowerCase().contains(
                    query,
                  ) ??
                  false) ||
              (complaint['createdBy']?['fullName']
                      ?.toString()
                      .toLowerCase()
                      .contains(query) ??
                  false);
        }
        return true;
      }).toList();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.red;
      case 'assigned':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      case 'cancelled':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  String _formatSLA(DateTime? createdAt) {
    if (createdAt == null) return 'N/A';
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else {
      return '${difference.inMinutes}m';
    }
  }

  List<String> _getUniqueWings() {
    final wings = <String>{};
    for (var complaint in _complaints) {
      final createdBy = complaint['createdBy'] ?? {};
      if (createdBy['wing'] != null) {
        wings.add(createdBy['wing']);
      }
    }
    return wings.toList()..sort();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _applyFilters();
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'all';
      _selectedCategory = 'all';
      _selectedPriority = 'all';
      _selectedWing = 'all';
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Key Statistics Section - Modern Premium Design
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.05),
                AppColors.secondary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.analytics_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Key Statistics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Statistics Grid
              Row(
                children: [
                  Expanded(
                    child: _ModernStatCard(
                      title: 'Total',
                      value: _statistics['total'] ?? 0,
                      icon: Icons.description_outlined,
                      color: AppColors.info,
                      gradient: [
                        AppColors.info.withOpacity(0.1),
                        AppColors.info.withOpacity(0.05),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModernStatCard(
                      title: 'Open',
                      value: _statistics['open'] ?? 0,
                      icon: Icons.pending_actions,
                      color: AppColors.error,
                      gradient: [
                        AppColors.error.withOpacity(0.1),
                        AppColors.error.withOpacity(0.05),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModernStatCard(
                      title: 'In Progress',
                      value: _statistics['inProgress'] ?? 0,
                      icon: Icons.sync,
                      color: AppColors.warning,
                      gradient: [
                        AppColors.warning.withOpacity(0.1),
                        AppColors.warning.withOpacity(0.05),
                      ],
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
                      value: _statistics['resolved'] ?? 0,
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                      gradient: [
                        AppColors.success.withOpacity(0.1),
                        AppColors.success.withOpacity(0.05),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModernStatCard(
                      title: 'Rejected',
                      value: _statistics['rejected'] ?? 0,
                      icon: Icons.cancel_outlined,
                      color: Colors.grey,
                      gradient: [
                        Colors.grey.withOpacity(0.1),
                        Colors.grey.withOpacity(0.05),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Empty space for alignment
                  Expanded(child: Container()),
                ],
              ),
            ],
          ),
        ),

        // Filters Section
        if (_showFilters)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText:
                        'Search by title, ticket number, or resident name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All Status'),
                          ),
                          DropdownMenuItem(value: 'Open', child: Text('Open')),
                          DropdownMenuItem(
                            value: 'Assigned',
                            child: Text('Assigned'),
                          ),
                          DropdownMenuItem(
                            value: 'In Progress',
                            child: Text('In Progress'),
                          ),
                          DropdownMenuItem(
                            value: 'Resolved',
                            child: Text('Resolved'),
                          ),
                          DropdownMenuItem(
                            value: 'Closed',
                            child: Text('Closed'),
                          ),
                          DropdownMenuItem(
                            value: 'Cancelled',
                            child: Text('Cancelled'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value ?? 'all';
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All Categories'),
                          ),
                          DropdownMenuItem(
                            value: 'Electrical',
                            child: Text('Electrical'),
                          ),
                          DropdownMenuItem(
                            value: 'Plumbing',
                            child: Text('Plumbing'),
                          ),
                          DropdownMenuItem(
                            value: 'Carpentry',
                            child: Text('Carpentry'),
                          ),
                          DropdownMenuItem(
                            value: 'Cleaning',
                            child: Text('Cleaning'),
                          ),
                          DropdownMenuItem(
                            value: 'Security',
                            child: Text('Security'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value ?? 'all';
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPriority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All Priorities'),
                          ),
                          DropdownMenuItem(
                            value: 'Emergency',
                            child: Text('Emergency'),
                          ),
                          DropdownMenuItem(value: 'High', child: Text('High')),
                          DropdownMenuItem(
                            value: 'Medium',
                            child: Text('Medium'),
                          ),
                          DropdownMenuItem(value: 'Low', child: Text('Low')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedPriority = value ?? 'all';
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedWing,
                        decoration: const InputDecoration(
                          labelText: 'Block/Wing',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Wings'),
                          ),
                          ..._getUniqueWings().map(
                            (wing) => DropdownMenuItem(
                              value: wing,
                              child: Text(wing),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedWing = value ?? 'all';
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _startDate != null && _endDate != null
                                ? '${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}'
                                : 'Select Date Range',
                            style: TextStyle(
                              color: _startDate != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Complaints List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredComplaints.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No complaints found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (_selectedStatus != 'all' ||
                          _selectedCategory != 'all' ||
                          _selectedPriority != 'all' ||
                          _selectedWing != 'all' ||
                          _startDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: TextButton(
                            onPressed: _clearFilters,
                            child: const Text('Clear filters'),
                          ),
                        ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadComplaints,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredComplaints.length,
                    itemBuilder: (context, index) {
                      final complaint = _filteredComplaints[index];
                      final status = complaint['status'] ?? 'Unknown';
                      final statusColor = _getStatusColor(status);
                      final createdBy = complaint['createdBy'] ?? {};
                      final assignedTo = complaint['assignedTo'] ?? {};
                      final assignedStaff = assignedTo['staff']?['user'] ?? {};
                      final createdAt = complaint['createdAt'] != null
                          ? DateTime.parse(complaint['createdAt'])
                          : null;
                      final updatedAt = complaint['updatedAt'] != null
                          ? DateTime.parse(complaint['updatedAt'])
                          : null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: InkWell(
                          onTap: () {
                            print(
                              '🖱️ [FLUTTER] Complaint tapped: ${complaint['ticketNumber']}',
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminComplaintDetailScreen(
                                  complaintId:
                                      complaint['_id']?.toString() ??
                                      complaint['id']?.toString() ??
                                      '',
                                ),
                              ),
                            ).then((_) => _loadComplaints());
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            complaint['title'] ?? 'No Title',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Ticket: ${complaint['ticketNumber'] ?? 'N/A'}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: statusColor,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.category,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          complaint['category'] ?? 'N/A',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (complaint['priority'] != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.flag,
                                            size: 16,
                                            color:
                                                complaint['priority'] ==
                                                    'Emergency'
                                                ? Colors.red
                                                : complaint['priority'] ==
                                                      'High'
                                                ? Colors.orange
                                                : Colors.blue,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            complaint['priority'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  complaint['priority'] ==
                                                      'Emergency'
                                                  ? Colors.red
                                                  : complaint['priority'] ==
                                                        'High'
                                                  ? Colors.orange
                                                  : Colors.blue,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (createdBy['wing'] != null ||
                                        createdBy['flatNumber'] != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.home,
                                            size: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${createdBy['wing'] ?? ''}${createdBy['wing'] != null && createdBy['flatNumber'] != null ? '-' : ''}${createdBy['flatNumber'] ?? ''}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Divider(height: 1, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.person,
                                                size: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  createdBy['fullName'] ??
                                                      'Unknown',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (assignedStaff['fullName'] !=
                                              null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.engineering,
                                                  size: 14,
                                                  color: Colors.blue.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    'Assigned: ${assignedStaff['fullName']}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.blue.shade700,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (createdAt != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'SLA: ${_formatSLA(createdAt)}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (updatedAt != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.update,
                                                size: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormat(
                                                  'MMM d, h:mm a',
                                                ).format(updatedAt),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ModernStatCard extends StatefulWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  @override
  State<_ModernStatCard> createState() => _ModernStatCardState();
}

class _ModernStatCardState extends State<_ModernStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.gradient,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.color.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.value.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
