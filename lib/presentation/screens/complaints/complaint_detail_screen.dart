import '../../../core/imports/app_imports.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isAddingComment = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadComplaintDetails();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupSocketListeners() {
    print(
      '🔌 [FLUTTER] Setting up socket listeners for resident complaint detail',
    );
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          socketService.connect(userId);

          // Listen for ticket assignment
          socketService.on('ticket_assigned', (data) {
            print('📡 [FLUTTER] Ticket assigned event received: $data');
            if (mounted &&
                (data['complaintId'] == widget.complaintId ||
                    data['ticketId'] == widget.complaintId)) {
              _loadComplaintDetails();
              _showNotificationSnackBar(
                title: 'Ticket Assigned',
                message:
                    'Your complaint has been assigned to ${data['assignedTo'] ?? 'staff'}. We\'re actively working on it. 👍',
                color: AppColors.info,
              );
            }
          });

          // Listen for status updates
          socketService.on('ticket_status_updated', (data) {
            print('📡 [FLUTTER] Ticket status updated event received: $data');
            if (mounted &&
                (data['complaintId'] == widget.complaintId ||
                    data['ticketId'] == widget.complaintId)) {
              _loadComplaintDetails();
              final newStatus = data['newStatus'] as String? ?? '';
              final updatedBy = data['updatedBy'] as String? ?? 'Admin';
              _showNotificationSnackBar(
                title: 'Status Updated',
                message:
                    'Your complaint has been updated 👍\nStatus: $newStatus\nWe\'re actively working on it.',
                color: AppColors.success,
              );
            }
          });

          // Listen for comments (admin messages)
          socketService.on('ticket_comment_added', (data) {
            print('📡 [FLUTTER] Comment added event: $data');
            if (mounted &&
                (data['ticketId'] == widget.complaintId ||
                    data['complaintId'] == widget.complaintId)) {
              _loadComplaintDetails();
              _scrollToBottom();
              final postedBy = data['postedBy'] as String? ?? 'Admin';
              _showNotificationSnackBar(
                title: 'New Message',
                message:
                    '$postedBy replied to your complaint. 👍\nWe\'re actively working on it.',
                color: AppColors.info,
              );
            }
          });

          // Listen for work updates
          socketService.on('work_update_added', (data) {
            print('📡 [FLUTTER] Work update added: $data');
            if (mounted &&
                (data['ticketId'] == widget.complaintId ||
                    data['complaintId'] == widget.complaintId)) {
              _loadComplaintDetails();
              _showNotificationSnackBar(
                title: 'Progress Update',
                message:
                    'Work progress has been updated. We\'re actively working on it. 👍',
                color: AppColors.info,
              );
            }
          });

          // Listen for resolution
          socketService.on('ticket_resolved', (data) {
            print('📡 [FLUTTER] Ticket resolved: $data');
            if (mounted &&
                (data['ticketId'] == widget.complaintId ||
                    data['complaintId'] == widget.complaintId)) {
              _loadComplaintDetails();
              _showNotificationSnackBar(
                title: 'Issue Resolved',
                message:
                    'Your complaint has been resolved! Please verify and close if satisfied. 👍',
                color: AppColors.success,
              );
            }
          });

          // Generic complaint updates
          socketService.on('complaint_updated', (data) {
            if (mounted &&
                (data['complaintId'] == widget.complaintId ||
                    data['ticketId'] == widget.complaintId)) {
              _loadComplaintDetails();
            }
          });
        }
      } catch (e) {
        print('❌ [FLUTTER] Error setting up socket: $e');
      }
    }
  }

  void _showNotificationSnackBar({
    required String title,
    required String message,
    required Color color,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadComplaintDetails() async {
    print('🖱️ [FLUTTER] Loading complaint details: ${widget.complaintId}');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.get(
        ApiConstants.complaintById(widget.complaintId),
      );

      if (response['success'] == true) {
        setState(() {
          _complaint = response['data']?['complaint'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              response['message'] ?? 'Failed to load complaint details';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading complaint details: $e');
      setState(() {
        _errorMessage = 'Error loading complaint: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : _complaint == null
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadComplaintDetails,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Admin/Staff Context (At-a-Glance)
                    _buildAdminStaffContextCard(),
                    const SizedBox(height: 16),

                    // Section 2: Complaint Summary
                    _buildComplaintSummaryCard(),
                    const SizedBox(height: 16),

                    // Section 3: Media Attachments
                    _buildMediaSection(),
                    const SizedBox(height: 16),

                    // Section 4: Status Display (Read-only)
                    _buildStatusDisplayCard(),
                    const SizedBox(height: 16),

                    // Section 6: Resident Communication Timeline
                    _buildCommunicationTimeline(),
                    const SizedBox(height: 16),

                    // Section 7: Resolution & Closure
                    if (_complaint?['status'] == 'Resolved' ||
                        _complaint?['status'] == 'Closed')
                      _buildResolutionCard(),
                    const SizedBox(height: 100), // Space for comment input
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    final status = _complaint?['status'] ?? '';
    final canReopen = status == 'Closed' || status == 'Resolved';
    final canClose = status == 'Resolved';
    final canCancel = status != 'Closed' && status != 'Cancelled';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Action Buttons
        if (canReopen || canClose || canCancel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (canReopen)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _reopenTicket,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reopen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (canReopen && (canClose || canCancel))
                    const SizedBox(width: 12),
                  if (canClose)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _closeTicket,
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (canClose && canCancel) const SizedBox(width: 12),
                  if (canCancel)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _cancelTicket,
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        // Comment Input
        _buildCommentInput(),
      ],
    );
  }

  Future<void> _reopenTicket() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen Complaint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for reopening:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for reopening...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await ApiService.post(
        '${ApiConstants.complaints}/${widget.complaintId}/reopen',
        {'reason': reasonController.text.trim()},
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complaint reopened successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          await _loadComplaintDetails();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to reopen'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _closeTicket() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Complaint'),
        content: const Text(
          'Are you sure this issue is fully resolved?\n\nOnce closed, you can reopen if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Yes, Close'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await ApiService.post(
        '${ApiConstants.complaints}/${widget.complaintId}/close',
        {},
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complaint closed successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          await _loadComplaintDetails();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to close'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _cancelTicket() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Complaint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for cancellation:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Cancellation reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await ApiService.post(
        '${ApiConstants.complaints}/${widget.complaintId}/cancel',
        {'reason': reasonController.text.trim()},
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complaint cancelled successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          await _loadComplaintDetails();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to cancel'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final status = _complaint?['status'] ?? 'Unknown';
    final statusColor = _getStatusColor(status);

    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complaint Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_complaint?['ticketNumber'] != null)
            Text(
              _complaint!['ticketNumber'],
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadComplaintDetails,
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor, width: 1.5),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminStaffContextCard() {
    final assignedTo = _complaint?['assignedTo'];
    final createdBy = _complaint?['createdBy'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Handled By',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Assigned Staff Info
            if (assignedTo != null && assignedTo['staff'] != null) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage:
                        assignedTo['staff']?['user']?['profilePicture'] != null
                        ? NetworkImage(
                            assignedTo['staff']['user']['profilePicture']
                                .toString(),
                          )
                        : null,
                    child:
                        assignedTo['staff']?['user']?['profilePicture'] == null
                        ? Text(
                            (assignedTo['staff']?['user']?['fullName']?[0] ??
                                    'S')
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignedTo['staff']?['user']?['fullName'] ??
                              'Staff Member',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (assignedTo['staff']?['specialization'] != null)
                          Text(
                            assignedTo['staff']['specialization'],
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (assignedTo['assignedAt'] != null)
                          Text(
                            'Assigned: ${_formatDateTime(assignedTo['assignedAt'])}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Not assigned yet
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pending, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Waiting for assignment',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Raised: ${_formatDateTime(_complaint?['createdAt'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                _buildPriorityBadge(_complaint?['priority'] ?? 'Medium'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'emergency':
        color = AppColors.error;
        break;
      case 'high':
        color = Colors.orange;
        break;
      case 'medium':
        color = AppColors.warning;
        break;
      case 'low':
        color = AppColors.success;
        break;
      default:
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildComplaintSummaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Complaint Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _complaint?['title'] ?? 'No Title',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip('Category', _complaint?['category'] ?? 'N/A'),
                const SizedBox(width: 8),
                _buildInfoChip(
                  'Sub-category',
                  _complaint?['subCategory'] ?? 'N/A',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _complaint?['description'] ?? 'No description',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            if (_complaint?['location']?['specificLocation'] != null) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _complaint!['location']['specificLocation'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }

  // Helper function to safely extract URL from media object
  String? _extractMediaUrl(dynamic mediaItem) {
    if (mediaItem == null) return null;

    // If it's already a string URL
    if (mediaItem is String) {
      if (mediaItem.startsWith('http')) return mediaItem;
      // If it looks like a stringified object, try to parse it
      if (mediaItem.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(mediaItem);
          if (decoded is Map && decoded['url'] != null) {
            return decoded['url'].toString();
          }
        } catch (e) {
          print('Error parsing media string: $e');
        }
      }
      return null;
    }

    // If it's a Map, extract the URL
    if (mediaItem is Map) {
      final url = mediaItem['url'];
      if (url != null) {
        final urlStr = url.toString();
        // Check if URL is valid
        if (urlStr.startsWith('http')) {
          return urlStr;
        }
      }
    }

    return null;
  }

  // Helper function to safely extract type from media object
  String _extractMediaType(dynamic mediaItem) {
    if (mediaItem == null) return 'image';
    if (mediaItem is Map) {
      return mediaItem['type']?.toString() ?? 'image';
    }
    return 'image';
  }

  Widget _buildMediaSection() {
    final residentMediaRaw = _complaint?['media'] ?? [];
    final adminMediaRaw = _complaint?['adminMedia'] ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Media Attachments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Resident Attachments
            if (residentMediaRaw is List && residentMediaRaw.isNotEmpty) ...[
              const Text(
                'Your Attachments',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: residentMediaRaw.length,
                  itemBuilder: (context, index) {
                    final media = residentMediaRaw[index];
                    final url = _extractMediaUrl(media);
                    if (url == null || url.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return _buildMediaThumbnail(
                      url,
                      _extractMediaType(media),
                      isAdmin: false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Admin Evidence
            if (adminMediaRaw is List && adminMediaRaw.isNotEmpty) ...[
              const Text(
                'Admin Evidence',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: adminMediaRaw.length,
                  itemBuilder: (context, index) {
                    final media = adminMediaRaw[index];
                    final url = _extractMediaUrl(media);
                    if (url == null || url.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final purpose = media is Map
                        ? media['purpose']?.toString()
                        : null;
                    return _buildMediaThumbnail(
                      url,
                      _extractMediaType(media),
                      isAdmin: true,
                      purpose: purpose,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaThumbnail(
    String url,
    String type, {
    bool isAdmin = false,
    String? purpose,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAdmin ? AppColors.primary : AppColors.border,
          width: isAdmin ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            if (type == 'image')
              Image.network(
                url,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.background,
                    child: const Icon(
                      Icons.broken_image,
                      color: AppColors.textLight,
                    ),
                  );
                },
              )
            else
              Container(
                color: AppColors.background,
                child: const Icon(
                  Icons.videocam,
                  size: 40,
                  color: AppColors.textLight,
                ),
              ),
            if (isAdmin && purpose != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    purpose,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showMediaViewer(url, type),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaViewer(String url, String type) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: type == 'image'
                  ? Image.network(url)
                  : const Icon(Icons.videocam, size: 64, color: Colors.white),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Download functionality can be added here
                },
                icon: const Icon(Icons.download),
                label: const Text('Download'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDisplayCard() {
    final status = _complaint?['status'] ?? 'Unknown';
    final statusColor = _getStatusColor(status);
    final assignedTo = _complaint?['assignedTo'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status & Assignment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Status Display
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor, width: 2),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: statusColor, size: 12),
                            const SizedBox(width: 12),
                            Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Priority Display
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Priority',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPriorityBadge(_complaint?['priority'] ?? 'Medium'),
                    ],
                  ),
                ),
              ],
            ),

            // Current Assignment Display
            if (assignedTo != null && assignedTo['staff'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assigned to: ${assignedTo['staff']?['user']?['fullName'] ?? 'Staff Member'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (assignedTo['assignedAt'] != null)
                            Text(
                              'Assigned: ${_formatDateTime(assignedTo['assignedAt'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommunicationTimeline() {
    final timeline = List<Map<String, dynamic>>.from(
      _complaint?['timeline'] ?? [],
    );
    final comments = List<Map<String, dynamic>>.from(
      _complaint?['comments'] ?? [],
    );

    // Combine timeline and comments for unified timeline
    final allEvents = <Map<String, dynamic>>[];

    // Add timeline events
    for (var event in timeline) {
      allEvents.add({
        'type': 'status_change',
        'data': event,
        'timestamp': event['timestamp'] ?? event['updatedAt'],
      });
    }

    // Add comments
    for (var comment in comments) {
      allEvents.add({
        'type': 'comment',
        'data': comment,
        'timestamp': comment['postedAt'],
      });
    }

    // Sort by timestamp
    allEvents.sort((a, b) {
      final aTime = _parseDateTime(a['timestamp']);
      final bTime = _parseDateTime(b['timestamp']);
      return bTime.compareTo(aTime); // Newest first
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Communication Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All updates and messages',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),

            if (allEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No activity yet',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...allEvents.map((event) => _buildTimelineEvent(event)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineEvent(Map<String, dynamic> event) {
    final type = event['type'];
    final data = event['data'] as Map<String, dynamic>;
    final timestamp = event['timestamp'];

    if (type == 'status_change') {
      return _buildStatusChangeEvent(data, timestamp);
    } else if (type == 'comment') {
      return _buildCommentEvent(data, timestamp);
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatusChangeEvent(Map<String, dynamic> data, dynamic timestamp) {
    final status = data['status'] ?? '';
    final description = data['description'] ?? '';
    final updatedBy = data['updatedBy'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.update, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Changed: $status',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      updatedBy?['fullName'] ?? 'Admin',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
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
  }

  Widget _buildCommentEvent(Map<String, dynamic> data, dynamic timestamp) {
    final text = data['text'] ?? '';
    final postedBy = data['postedBy'];
    final mediaRaw = data['media'] ?? [];
    final media = mediaRaw is List ? mediaRaw : [];
    final userJson = StorageService.getString(AppConstants.userKey);
    String? currentUserId;
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        currentUserId = userData['_id'] ?? userData['id'];
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }
    final isMyComment =
        postedBy?['_id']?.toString() == currentUserId ||
        postedBy?.toString() == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMyComment
            ? AppColors.primary.withOpacity(0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyComment
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isMyComment
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.background,
            backgroundImage: postedBy?['profilePicture'] != null
                ? NetworkImage(postedBy['profilePicture'].toString())
                : null,
            child: postedBy?['profilePicture'] == null
                ? Text(
                    (postedBy?['fullName']?[0] ?? 'U').toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isMyComment
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        postedBy?['fullName'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isMyComment)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (media.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: media.length,
                      itemBuilder: (context, index) {
                        final mediaItem = media[index];
                        final url = _extractMediaUrl(mediaItem);
                        if (url == null || url.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return _buildMediaThumbnail(
                          url,
                          _extractMediaType(mediaItem),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _formatDateTime(timestamp),
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionCard() {
    final resolution = _complaint?['resolution'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: 8),
                const Text(
                  'Resolution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (resolution?['description'] != null)
              Text(
                resolution['description'],
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            if (resolution?['resolvedAt'] != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Resolved: ${_formatDateTime(resolution['resolvedAt'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            if (resolution?['images'] != null &&
                resolution['images'] is List &&
                (resolution['images'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (resolution['images'] as List).length,
                  itemBuilder: (context, index) {
                    final imageItem = resolution['images'][index];
                    final url = _extractMediaUrl(imageItem);
                    if (url == null || url.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return _buildMediaThumbnail(url, 'image');
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    final status = _complaint?['status'] ?? '';
    if (status == 'Closed' || status == 'Cancelled') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null) ...[
            Container(
              height: 100,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() => _selectedImage = null);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.camera_alt, color: AppColors.primary),
                onPressed: _pickImage,
              ),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment or reply...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isAddingComment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: AppColors.primary),
                onPressed: _isAddingComment ? null : _addComment,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      // Show dialog to choose source
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    setState(() => _isAddingComment = true);
    try {
      Map<String, dynamic> requestBody = {'text': text};

      // If image is selected, upload it first
      if (_selectedImage != null) {
        // TODO: Upload image and get URL, then add to media array
        // For now, just send text comment
        // You may need to implement image upload for comments separately
      }

      final response = await ApiService.post(
        ApiConstants.complaintComments(widget.complaintId),
        requestBody,
      );

      if (response['success'] == true) {
        _commentController.clear();
        setState(() => _selectedImage = null);
        await _loadComplaintDetails();
        _scrollToBottom();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment added successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to add comment'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingComment = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return AppColors.statusOpen;
      case 'assigned':
        return AppColors.statusAssigned;
      case 'in progress':
        return AppColors.statusInProgress;
      case 'resolved':
        return AppColors.statusResolved;
      case 'closed':
        return AppColors.textSecondary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'Recently';
    try {
      final dt = dateTime is String
          ? DateTime.parse(dateTime)
          : dateTime as DateTime;
      return DateFormat('MMM d, yyyy • h:mm a').format(dt);
    } catch (e) {
      return 'Recently';
    }
  }

  DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return DateTime.now();
    try {
      return dateTime is String
          ? DateTime.parse(dateTime)
          : dateTime as DateTime;
    } catch (e) {
      return DateTime.now();
    }
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
            const Text(
              'Error Loading Complaint',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadComplaintDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Complaint Not Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
