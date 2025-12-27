import '../../../core/imports/app_imports.dart';
import '../../../data/models/complaint_data.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'create_complaint_screen.dart';
import 'complaint_detail_screen.dart';

class ResidentComplaintsScreen extends StatefulWidget {
  const ResidentComplaintsScreen({super.key});

  @override
  State<ResidentComplaintsScreen> createState() => _ResidentComplaintsScreenState();
}

class _ResidentComplaintsScreenState extends State<ResidentComplaintsScreen> {
  List<Map<String, dynamic>> _complaints = [];
  List<Map<String, dynamic>> _filteredComplaints = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadComplaints();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for resident complaints');
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      final user = UserData.fromJson(jsonDecode(userJson));
      socketService.connect(user.id);
      
      socketService.on('complaint_created', (data) {
        print('📡 [FLUTTER] Complaint created event received');
        _loadComplaints(); // Refresh complaints list
      });
      
      socketService.on('complaint_updated', (data) {
        print('📡 [FLUTTER] Complaint updated event received');
        _loadComplaints(); // Refresh complaints list
      });
      
      socketService.on('work_update_added', (data) {
        print('📡 [FLUTTER] Work update added event received');
        _loadComplaints(); // Refresh to show new work update
      });
      
      // Listen for ticket status updated (from backend)
      socketService.on('ticket_status_updated', (data) {
        print('📡 [FLUTTER] Ticket status updated event received');
        print('📡 [FLUTTER] Event data: ${jsonEncode(data)}');
        print('📡 [FLUTTER] Old Status: ${data['oldStatus']}');
        print('📡 [FLUTTER] New Status: ${data['newStatus']}');
        print('📡 [FLUTTER] Updated By: ${data['updatedBy']}');
        print('📡 [FLUTTER] Updated At: ${data['updatedAt']}');
        print('📡 [FLUTTER] Ticket Number: ${data['ticketNumber']}');
        
        if (mounted) {
          print('✅ [FLUTTER] Refreshing complaints list after status update');
          _loadComplaints(); // Refresh to show status update
          
          // Show notification with admin name and time
          if (data['updatedBy'] != null && data['updatedAt'] != null) {
            final updatedBy = data['updatedBy'] as String;
            final updatedAt = data['updatedAt'] as String;
            final newStatus = data['newStatus'] as String? ?? '';
            final oldStatus = data['oldStatus'] as String? ?? '';
            final ticketNumber = data['ticketNumber'] as String? ?? '';
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticket $ticketNumber: $oldStatus → $newStatus',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          'Updated by: $updatedBy',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('h:mm a').format(DateTime.parse(updatedAt)),
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
                backgroundColor: Colors.blue.shade700,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'View',
                  textColor: Colors.white,
                  onPressed: () {
                    // Could navigate to complaint detail if needed
                  },
                ),
              ),
            );
          }
        }
      });
      
      // Also listen for complaint_status_updated (alternative event name)
      socketService.on('complaint_status_updated', (data) {
        print('📡 [FLUTTER] Complaint status updated event received: $data');
        if (mounted) {
          _loadComplaints();
        }
      });
      
      socketService.on('status_updated', (data) {
        print('📡 [FLUTTER] Status updated event received (legacy)');
        if (mounted) {
          _loadComplaints(); // Refresh to show status update
        }
      });
      
      socketService.on('complaint_resolved', (data) {
        print('📡 [FLUTTER] Complaint resolved event received');
        if (mounted) {
          _loadComplaints(); // Refresh to show resolved status
        }
      });
      
      socketService.on('ticket_resolved', (data) {
        print('📡 [FLUTTER] Ticket resolved event received');
        if (mounted) {
          _loadComplaints(); // Refresh to show resolved status
        }
      });
    }
  }

  Future<void> _loadComplaints() async {
    final loadStartTime = DateTime.now();
    print('🖱️ [FLUTTER] Loading resident complaints...');
    print('🖱️ [FLUTTER] Load start time: ${loadStartTime.toIso8601String()}');
    
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('${ApiConstants.complaints}/my-complaints');
      final loadEndTime = DateTime.now();
      final loadDuration = loadEndTime.difference(loadStartTime).inMilliseconds;
      
      print('✅ [FLUTTER] Complaints response received');
      print('✅ [FLUTTER] Load end time: ${loadEndTime.toIso8601String()}');
      print('✅ [FLUTTER] Load duration: ${loadDuration}ms');

      if (response['success'] == true) {
        final complaintsList = response['data']?['complaints'] as List?;
        if (complaintsList != null) {
          final complaints = complaintsList.cast<Map<String, dynamic>>();
          print('✅ [FLUTTER] Loaded ${complaints.length} complaints');
          
          // Log status distribution
          final statusCounts = <String, int>{};
          for (var complaint in complaints) {
            final status = complaint['status'] as String? ?? 'Unknown';
            statusCounts[status] = (statusCounts[status] ?? 0) + 1;
          }
          print('📊 [FLUTTER] Status distribution: $statusCounts');
          
          setState(() {
            _complaints = complaints;
            _applyFilters();
          });
          print('✅ [FLUTTER] Complaints loaded and filtered successfully');
        }
      } else {
        print('❌ [FLUTTER] Failed to load complaints: ${response['message']}');
      }
    } catch (e) {
      final loadEndTime = DateTime.now();
      final loadDuration = loadEndTime.difference(loadStartTime).inMilliseconds;
      print('❌ [FLUTTER] Error loading complaints: $e');
      print('❌ [FLUTTER] Error time: ${loadEndTime.toIso8601String()}');
      print('❌ [FLUTTER] Error duration: ${loadDuration}ms');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading complaints: $e')),
        );
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
        if (_selectedStatus != 'all' && complaint['status'] != _selectedStatus) {
          return false;
        }
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return (complaint['title']?.toString().toLowerCase().contains(query) ?? false) ||
              (complaint['ticketNumber']?.toString().toLowerCase().contains(query) ?? false);
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
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'electrical':
        return Icons.flash_on;
      case 'plumbing':
        return Icons.water_drop;
      case 'carpentry':
        return Icons.build;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'security':
        return Icons.security;
      default:
        return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Complaints'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              print('🖱️ [FLUTTER] Refresh complaints button clicked');
              _loadComplaints();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search complaints...',
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Status')),
                          DropdownMenuItem(value: 'Open', child: Text('Open')),
                          DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                          DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                          DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                          DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value ?? 'all';
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
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
                            Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No complaints yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                print('🖱️ [FLUTTER] Create complaint button clicked');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreateComplaintScreen(),
                                  ),
                                ).then((_) => _loadComplaints());
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Raise New Complaint'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
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
                            final category = complaint['category'] ?? 'Other';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () {
                                  print('🖱️ [FLUTTER] Complaint tapped: ${complaint['ticketNumber']}');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ComplaintDetailScreen(
                                        complaintId: complaint['_id']?.toString() ?? 
                                                     complaint['id']?.toString() ?? '',
                                      ),
                                    ),
                                  ).then((_) => _loadComplaints());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(category),
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                            const SizedBox(height: 4),
                                            Text(
                                              category,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: statusColor),
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
                                          const SizedBox(height: 8),
                                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          print('🖱️ [FLUTTER] FAB - Create complaint clicked');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateComplaintScreen(),
            ),
          ).then((_) => _loadComplaints());
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Complaint'),
      ),
    );
  }

}

