import '../../../core/imports/app_imports.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class ComplaintDetailScreen extends StatefulWidget {
  final String complaintId;

  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  Map<String, dynamic>? _complaint;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadComplaintDetails();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for complaint detail');
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
            print('📡 [FLUTTER] Event data: ${jsonEncode(data)}');
            print('📡 [FLUTTER] Complaint ID: ${widget.complaintId}');
            print('📡 [FLUTTER] Event complaintId: ${data['complaintId']}');
            print('📡 [FLUTTER] Event ticketId: ${data['ticketId']}');
            print('📡 [FLUTTER] Old Status: ${data['oldStatus']}');
            print('📡 [FLUTTER] New Status: ${data['newStatus']}');
            print('📡 [FLUTTER] Updated By: ${data['updatedBy']}');
            print('📡 [FLUTTER] Updated At: ${data['updatedAt']}');
            
            if (mounted && (data['complaintId'] == widget.complaintId || 
                           data['ticketId'] == widget.complaintId ||
                           data['complaint']?['id'] == widget.complaintId)) {
              print('✅ [FLUTTER] Reloading complaint details after status update');
              _loadComplaintDetails();
              // Show notification with admin name and time
              final updatedBy = data['updatedBy'] as String? ?? 
                               data['complaint']?['updatedBy'] as String? ?? 
                               'Admin';
              final updatedAt = data['updatedAt'] as String? ?? 
                               data['timestamp'] as String? ?? 
                               DateTime.now().toIso8601String();
              final newStatus = data['newStatus'] as String? ?? 
                               data['complaint']?['newStatus'] as String? ?? 
                               '';
              final oldStatus = data['oldStatus'] as String? ?? 
                              data['complaint']?['oldStatus'] as String? ?? 
                              '';
              final ticketNumber = data['ticketNumber'] as String? ?? 
                                  data['complaint']?['ticketNumber'] as String? ?? 
                                  '';
              
              if (updatedBy != null && updatedAt != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticketNumber.isNotEmpty 
                            ? 'Ticket $ticketNumber: $oldStatus → $newStatus'
                            : 'Status Changed: $oldStatus → $newStatus',
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
                            Expanded(
                              child: Text(
                                'Updated by: $updatedBy',
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
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
                  ),
                );
              }
            }
          });
          
          socketService.on('complaint_status_updated', (data) {
            print('📡 [FLUTTER] Complaint status updated event received: $data');
            if (mounted && (data['complaint']?['id'] == widget.complaintId ||
                           data['complaintId'] == widget.complaintId)) {
              _loadComplaintDetails();
            }
          });
          
          socketService.on('status_updated', (data) {
            print('📡 [FLUTTER] Status updated event received');
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
    final loadStartTime = DateTime.now();
    print('🖱️ [FLUTTER] Loading complaint details: ${widget.complaintId}');
    print('🖱️ [FLUTTER] Load start time: ${loadStartTime.toIso8601String()}');
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.get('${ApiConstants.complaints}/${widget.complaintId}');
      final loadEndTime = DateTime.now();
      final loadDuration = loadEndTime.difference(loadStartTime).inMilliseconds;
      
      print('✅ [FLUTTER] Complaint details response received');
      print('✅ [FLUTTER] Load end time: ${loadEndTime.toIso8601String()}');
      print('✅ [FLUTTER] Load duration: ${loadDuration}ms');
      
      if (response['success'] == true) {
        final complaint = response['data']?['complaint'];
        if (complaint != null) {
          print('✅ [FLUTTER] Complaint loaded: ${complaint['ticketNumber']}');
          print('✅ [FLUTTER] Current Status: ${complaint['status']}');
          print('✅ [FLUTTER] Created At: ${complaint['createdAt']}');
          print('✅ [FLUTTER] Updated At: ${complaint['updatedAt']}');
          if (complaint['statusHistory'] != null) {
            print('✅ [FLUTTER] Status History: ${(complaint['statusHistory'] as List).length} entries');
          }
        }
        
        setState(() {
          _complaint = complaint;
          _isLoading = false;
        });
        print('✅ [FLUTTER] Complaint details loaded successfully');
      } else {
        print('❌ [FLUTTER] Failed to load complaint: ${response['message']}');
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load complaint details';
          _isLoading = false;
        });
      }
    } catch (e) {
      final loadEndTime = DateTime.now();
      final loadDuration = loadEndTime.difference(loadStartTime).inMilliseconds;
      print('❌ [FLUTTER] Error loading complaint details: $e');
      print('❌ [FLUTTER] Error time: ${loadEndTime.toIso8601String()}');
      print('❌ [FLUTTER] Error duration: ${loadDuration}ms');
      setState(() {
        _errorMessage = 'Error loading complaint: ${e.toString()}';
        _isLoading = false;
      });
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComplaintDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _complaint == null
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadComplaintDetails,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Card with Color Coding
                            _buildStatusCard(),
                            const SizedBox(height: 16),
                            // Complaint Details Card
                            _buildDetailsCard(),
                            const SizedBox(height: 16),
                            // Assigned Staff Card (if assigned)
                            if (_complaint?['assignedTo'] != null && 
                                _complaint!['assignedTo']['staff'] != null)
                              _buildAssignedStaffCard(),
                            const SizedBox(height: 16),
                            // Admin Remarks/Work Updates
                            if (_complaint?['workUpdates'] != null && 
                                (_complaint!['workUpdates'] as List).isNotEmpty)
                              _buildWorkUpdatesCard(),
                            const SizedBox(height: 16),
                            // Timeline/History
                            if (_complaint?['timeline'] != null &&
                                (_complaint!['timeline'] as List).isNotEmpty)
                              _buildTimelineCard(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error Loading Complaint',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadComplaintDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Complaint Not Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The complaint you are looking for does not exist or has been removed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
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
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.description, color: statusColor, size: 32),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: statusColor, width: 2),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Complaint Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.confirmation_number,
            label: 'Ticket Number',
            value: _complaint?['ticketNumber'] ?? 'N/A',
          ),
          _DetailRow(
            icon: Icons.flag,
            label: 'Priority',
            value: _complaint?['priority'] ?? 'N/A',
            valueColor: _complaint?['priority'] == 'Emergency'
                ? Colors.red
                : _complaint?['priority'] == 'High'
                    ? Colors.orange
                    : Colors.blue,
          ),
          _DetailRow(
            icon: Icons.description,
            label: 'Description',
            value: _complaint?['description'] ?? 'No description',
            isMultiline: true,
          ),
          if (_complaint?['location'] != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.location_on, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
          if (_complaint?['createdAt'] != null) ...[
            const Divider(height: 24),
            _DetailRow(
              icon: Icons.calendar_today,
              label: 'Created At',
              value: DateFormat('MMM d, yyyy • h:mm a').format(
                DateTime.parse(_complaint!['createdAt']),
              ),
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
              Icon(Icons.engineering, color: Colors.blue.shade700),
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

  Widget _buildWorkUpdatesCard() {
    final workUpdates = _complaint!['workUpdates'] as List;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.update, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Work Updates & Admin Remarks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...workUpdates.asMap().entries.map((entry) {
            final index = entry.key;
            final update = entry.value;
            final isLast = index == workUpdates.length - 1;
            
            return Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
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
                        radius: 18,
                        backgroundColor: Colors.blue,
                        child: Text(
                          update['updatedBy']?['fullName']?[0].toUpperCase() ?? 'S',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              update['updatedBy']?['fullName'] ?? 'Staff',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
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

  Widget _buildTimelineCard() {
    final timeline = _complaint!['timeline'] as List;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Status History & Timeline',
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
              final eventStatus = event['status'] ?? 'Open';
              final statusColor = _getStatusColor(eventStatus);
              
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 3,
                            height: 50,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
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
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: statusColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  eventStatus,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (event['description'] != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              event['description'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
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
  final IconData? icon;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isMultiline = false,
    this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? Colors.black87,
              fontWeight: valueColor != null ? FontWeight.w500 : FontWeight.normal,
            ),
            maxLines: isMultiline ? null : 3,
            overflow: isMultiline ? null : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
