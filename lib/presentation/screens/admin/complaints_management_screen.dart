import '../../../core/imports/app_imports.dart';
import '../../../data/models/complaint_data.dart';
import 'dart:convert';
import '../complaints/complaint_detail_screen.dart';
import 'admin_complaint_detail_screen.dart';

class ComplaintsManagementScreen extends StatefulWidget {
  const ComplaintsManagementScreen({super.key});

  @override
  State<ComplaintsManagementScreen> createState() => _ComplaintsManagementScreenState();
}

class _ComplaintsManagementScreenState extends State<ComplaintsManagementScreen> {
  List<Map<String, dynamic>> _complaints = [];
  List<Map<String, dynamic>> _filteredComplaints = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedCategory = 'all';
  String _searchQuery = '';

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
      print('📦 [FLUTTER] Response: ${response.toString()}');

      if (response['success'] == true) {
        final complaintsList = response['data']?['complaints'] as List?;
        if (complaintsList != null) {
          setState(() {
            _complaints = complaintsList.cast<Map<String, dynamic>>();
            _applyFilters();
          });
          print('✅ [FLUTTER] Loaded ${_complaints.length} complaints');
        }
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading complaints: $e');
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
        // Category filter
        if (_selectedCategory != 'all' && complaint['category'] != _selectedCategory) {
          return false;
        }
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return (complaint['title']?.toString().toLowerCase().contains(query) ?? false) ||
              (complaint['ticketNumber']?.toString().toLowerCase().contains(query) ?? false) ||
              (complaint['createdBy']?['fullName']?.toString().toLowerCase().contains(query) ?? false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints Management'),
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
          // Filters
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Categories')),
                          DropdownMenuItem(value: 'Electrical', child: Text('Electrical')),
                          DropdownMenuItem(value: 'Plumbing', child: Text('Plumbing')),
                          DropdownMenuItem(value: 'Carpentry', child: Text('Carpentry')),
                          DropdownMenuItem(value: 'Cleaning', child: Text('Cleaning')),
                          DropdownMenuItem(value: 'Security', child: Text('Security')),
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
              ],
            ),
          ),
          // Complaints List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredComplaints.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No complaints found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
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
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () {
                                  print('🖱️ [FLUTTER] Complaint tapped: ${complaint['ticketNumber']}');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminComplaintDetailScreen(
                                        complaintId: complaint['_id']?.toString() ?? 
                                                     complaint['id']?.toString() ?? '',
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
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.category, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            complaint['category'] ?? 'N/A',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(Icons.person, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              createdBy['fullName'] ?? 'Unknown',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (createdBy['flatNumber'] != null)
                                            Text(
                                              'Flat ${createdBy['flatNumber']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (complaint['priority'] != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.flag,
                                              size: 16,
                                              color: complaint['priority'] == 'Emergency'
                                                  ? Colors.red
                                                  : complaint['priority'] == 'High'
                                                      ? Colors.orange
                                                      : Colors.blue,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Priority: ${complaint['priority']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: complaint['priority'] == 'Emergency'
                                                    ? Colors.red
                                                    : complaint['priority'] == 'High'
                                                        ? Colors.orange
                                                        : Colors.blue,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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
    );
  }

}


