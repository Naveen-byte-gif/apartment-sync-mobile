import '../../../core/imports/app_imports.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class AdminComplaintDetailScreen extends StatefulWidget {
  final String complaintId;

  const AdminComplaintDetailScreen({super.key, required this.complaintId});

  @override
  State<AdminComplaintDetailScreen> createState() => _AdminComplaintDetailScreenState();
}

class _AdminComplaintDetailScreenState extends State<AdminComplaintDetailScreen> {
  Map<String, dynamic>? _complaint;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadComplaintDetails();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for admin complaint detail');
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          socketService.connect(userId);
          
          socketService.on('complaint_updated', (data) {
            print('📡 [FLUTTER] Complaint updated event received');
            if (mounted && (data['complaintId'] == widget.complaintId || 
                           data['ticketId'] == widget.complaintId)) {
              _loadComplaintDetails();
            }
          });
          
          socketService.on('ticket_status_updated', (data) {
            print('📡 [FLUTTER] Ticket status updated event received');
            if (mounted && (data['complaintId'] == widget.complaintId || 
                           data['ticketId'] == widget.complaintId)) {
              _loadComplaintDetails();
              // Show notification with admin name and time
              if (data['updatedBy'] != null && data['updatedAt'] != null) {
                final updatedBy = data['updatedBy'] as String;
                final updatedAt = data['updatedAt'] as String;
                final newStatus = data['newStatus'] as String? ?? '';
                final oldStatus = data['oldStatus'] as String? ?? '';
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Changed: $oldStatus → $newStatus',
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
                              'Changed by: $updatedBy',
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
                    backgroundColor: Colors.green.shade700,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          });
          
          socketService.on('status_updated', (data) {
            print('📡 [FLUTTER] Status updated event received');
            if (mounted && data['complaintId'] == widget.complaintId) {
              _loadComplaintDetails();
              // Show notification with admin name and time
              if (data['updatedBy'] != null && data['updatedAt'] != null) {
                final updatedBy = data['updatedBy'] as String;
                final updatedAt = data['updatedAt'] as String;
                final newStatus = data['newStatus'] as String? ?? '';
                final oldStatus = data['oldStatus'] as String? ?? '';
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Changed: $oldStatus → $newStatus',
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
                              'Changed by: $updatedBy',
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
                    backgroundColor: Colors.green.shade700,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          });
          
          socketService.on('status_change_confirmation', (data) {
            print('📡 [FLUTTER] Status change confirmation received');
            if (mounted && data['complaintId'] == widget.complaintId) {
              _loadComplaintDetails();
            }
          });
        }
      } catch (e) {
        print('❌ [FLUTTER] Error setting up socket: $e');
      }
    }
  }

  Future<void> _loadComplaintDetails() async {
    print('🖱️ [FLUTTER] Loading complaint details: ${widget.complaintId}');
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('${ApiConstants.complaints}/${widget.complaintId}');
      print('✅ [FLUTTER] Complaint details response received');
      
      if (response['success'] == true) {
        setState(() {
          _complaint = response['data']?['complaint'];
        });
        print('✅ [FLUTTER] Complaint details loaded');
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading complaint details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading complaint: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String newStatus, {String? description}) async {
    if (_isUpdatingStatus) {
      print('⚠️ [FLUTTER] Status update already in progress');
      return;
    }
    
    print('🔄 [FLUTTER] Updating status to: $newStatus');
    setState(() => _isUpdatingStatus = true);
    
    try {
      final requestBody = <String, dynamic>{
        'status': newStatus,
      };
      
      if (description != null && description.isNotEmpty) {
        requestBody['description'] = description;
      }
      
      print('📡 [FLUTTER] Sending PUT request to: ${ApiConstants.complaints}/${widget.complaintId}/status');
      print('📦 [FLUTTER] Request body: $requestBody');
      
      final response = await ApiService.put(
        '${ApiConstants.complaints}/${widget.complaintId}/status',
        requestBody,
      );
      
      print('📡 [FLUTTER] Response received: ${response.toString()}');
      
      if (response['success'] == true) {
        print('✅ [FLUTTER] Status updated successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated to $newStatus successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          // Reload complaint details to get updated status
          await _loadComplaintDetails();
        }
      } else {
        print('❌ [FLUTTER] Status update failed: ${response['message']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? response['error'] ?? 'Failed to update status'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ [FLUTTER] Error updating status: $e');
      print('❌ [FLUTTER] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  void _showStatusChangeDialog(String currentStatus) {
    // Get allowed next statuses based on current status
    List<String> allowedStatuses = _getAllowedStatuses(currentStatus);
    
    if (allowedStatuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No status transitions available')),
      );
      return;
    }

    final descriptionController = TextEditingController();
    final selectedStatusNotifier = ValueNotifier<String?>(null);

    showDialog(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<String?>(
          valueListenable: selectedStatusNotifier,
          builder: (context, selectedStatus, _) {
            return AlertDialog(
              title: const Text('Change Status'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentStatus,
                      style: TextStyle(
                        color: _getStatusColor(currentStatus),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'New Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select new status',
                      ),
                      items: allowedStatuses.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (value) {
                        selectedStatusNotifier.value = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Description (Optional):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Add a note about this status change...',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    selectedStatusNotifier.dispose();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedStatus == null
                      ? null
                      : () {
                          final statusToUpdate = selectedStatus;
                          final descriptionText = descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim();
                          selectedStatusNotifier.dispose();
                          Navigator.pop(context);
                          _updateStatus(
                            statusToUpdate,
                            description: descriptionText,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Update Status'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> _getAllowedStatuses(String currentStatus) {
    switch (currentStatus.toLowerCase()) {
      case 'open':
        return ['Assigned', 'Cancelled'];
      case 'assigned':
        return ['In Progress', 'Cancelled', 'Open'];
      case 'in progress':
        return ['Resolved', 'Cancelled'];
      case 'resolved':
        return ['Closed', 'Reopened'];
      case 'closed':
        return ['Reopened'];
      case 'reopened':
        return ['Assigned', 'In Progress', 'Cancelled'];
      case 'cancelled':
        return []; // Terminal state
      default:
        return [];
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
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
      case 'reopened':
        return Colors.purple;
      case 'cancelled':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket: ${_complaint?['ticketNumber'] ?? 'N/A'}'),
        backgroundColor: AppColors.primary,
        actions: [
          if (_complaint != null && _complaint!['status'] != 'Cancelled' && _complaint!['status'] != 'Closed')
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Change Status',
              onPressed: _isUpdatingStatus
                  ? null
                  : () => _showStatusChangeDialog(_complaint!['status'] ?? 'Open'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _complaint == null
              ? const Center(child: Text('Complaint not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card with Change Button
                      _buildStatusCard(),
                      const SizedBox(height: 16),
                      // Complaint Details
                      _buildDetailsCard(),
                      const SizedBox(height: 16),
                      // Assigned Staff Section
                      if (_complaint?['assignedTo'] != null && 
                          _complaint!['assignedTo']['staff'] != null)
                        _buildAssignedStaffCard(),
                      const SizedBox(height: 16),
                      // Progress Reports (Work Updates)
                      if (_complaint?['workUpdates'] != null && 
                          (_complaint!['workUpdates'] as List).isNotEmpty)
                        _buildProgressReports(),
                      const SizedBox(height: 16),
                      // Timeline
                      if (_complaint?['timeline'] != null &&
                          (_complaint!['timeline'] as List).isNotEmpty)
                        _buildTimeline(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusCard() {
    final status = _complaint?['status'] ?? 'Unknown';
    final statusColor = _getStatusColor(status);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.description, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _complaint?['title'] ?? 'No Title',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${_complaint?['category'] ?? 'N/A'}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (status != 'Cancelled' && status != 'Closed')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdatingStatus
                      ? null
                      : () => _showStatusChangeDialog(status),
                  icon: const Icon(Icons.edit),
                  label: const Text('Change Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complaint Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            label: 'Ticket Number',
            value: _complaint?['ticketNumber'] ?? 'N/A',
          ),
          _DetailRow(
            label: 'Priority',
            value: _complaint?['priority'] ?? 'N/A',
          ),
          _DetailRow(
            label: 'Description',
            value: _complaint?['description'] ?? 'No description',
            isMultiline: true,
          ),
          if (_complaint?['location'] != null) ...[
            const Divider(),
            const Text(
              'Location',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_complaint!['location']['flatNumber'] != null)
              _DetailRow(
                label: 'Flat',
                value: 'Floor ${_complaint!['location']['floorNumber']} - ${_complaint!['location']['flatNumber']}',
              ),
            if (_complaint!['location']['specificLocation'] != null)
              _DetailRow(
                label: 'Specific Location',
                value: _complaint!['location']['specificLocation'],
              ),
          ],
          if (_complaint?['createdBy'] != null) ...[
            const Divider(),
            const Text(
              'Created By',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Name',
              value: _complaint!['createdBy']['fullName'] ?? 'N/A',
            ),
            if (_complaint!['createdBy']['flatNumber'] != null)
              _DetailRow(
                label: 'Flat',
                value: 'Floor ${_complaint!['createdBy']['floorNumber']} - ${_complaint!['createdBy']['flatNumber']}',
              ),
            if (_complaint!['createdBy']['phoneNumber'] != null)
              _DetailRow(
                label: 'Phone',
                value: _complaint!['createdBy']['phoneNumber'],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignedStaffCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Assigned Staff',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Name',
            value: _complaint!['assignedTo']['staff']['user']?['fullName'] ?? 'N/A',
          ),
          if (_complaint!['assignedTo']['assignedAt'] != null)
            _DetailRow(
              label: 'Assigned On',
              value: DateFormat('MMM d, yyyy • h:mm a').format(
                DateTime.parse(_complaint!['assignedTo']['assignedAt']),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressReports() {
    final workUpdates = _complaint!['workUpdates'] as List;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Progress Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...workUpdates.map((update) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue,
                        child: Text(
                          update['updatedBy']?['fullName']?[0].toUpperCase() ?? 'S',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              update['updatedBy']?['fullName'] ?? 'Staff',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              update['updatedAt'] != null
                                  ? DateFormat('MMM d, yyyy • h:mm a')
                                      .format(DateTime.parse(update['updatedAt']))
                                  : 'Recently',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    update['description'] ?? 'No description',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final timeline = _complaint!['timeline'] as List;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Status Change History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (timeline.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No status changes yet',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            )
          else
            ...timeline.asMap().entries.map((entry) {
              final index = entry.key;
              final event = entry.value;
              final isLast = index == timeline.length - 1;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getStatusColor(event['status'] ?? 'Open'),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 40,
                            color: Colors.grey.shade300,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                      ],
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
                                  event['action'] ?? event['status'] ?? 'Status changed',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(event['status'] ?? 'Open')
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getStatusColor(event['status'] ?? 'Open'),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  event['status'] ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(event['status'] ?? 'Open'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (event['description'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              event['description'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                event['updatedBy']?['fullName'] ?? 
                                event['updatedByName'] ?? 
                                'Admin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                event['timestamp'] != null || event['updatedAt'] != null
                                    ? DateFormat('MMM d, yyyy • h:mm a').format(
                                        DateTime.parse(
                                          event['timestamp'] ?? 
                                          event['updatedAt'] ?? 
                                          DateTime.now().toIso8601String()
                                        )
                                      )
                                    : 'Recently',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
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
            }).toList(),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMultiline;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isMultiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
            ),
            maxLines: isMultiline ? null : 2,
            overflow: isMultiline ? null : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

