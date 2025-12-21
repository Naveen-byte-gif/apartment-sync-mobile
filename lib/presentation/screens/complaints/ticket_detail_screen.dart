import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/ticket_service.dart';
import '../../../data/models/complaint_data.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final String? userRole;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    this.userRole,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  ComplaintData? _ticket;
  bool _isLoading = true;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserRole;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadUserInfo();
    _setupSocketListeners();
    _loadTicketDetails();
  }

  Future<void> _loadUserInfo() async {
    final userData = StorageService.getString(AppConstants.userKey);
    if (userData != null) {
      try {
        final user = jsonDecode(userData);
        setState(() {
          _currentUserRole = widget.userRole ?? user['role'] ?? 'resident';
          _currentUserId = user['_id'] ?? user['id'];
        });
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }
  }

  Future<void> _loadTicketDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await TicketService.getTicket(widget.ticketId);
      if (response['success'] == true && response['data']?['complaint'] != null) {
        setState(() {
          _ticket = ComplaintData.fromJson(response['data']['complaint']);
          _isLoading = false;
        });
      } else {
        if (mounted) {
          ErrorSnackBar.show(context, response['message'] ?? 'Failed to load ticket');
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading ticket: $e');
      if (mounted) {
        ErrorSnackBar.show(context, 'Error loading ticket: ${e.toString()}');
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupSocketListeners() {
    final socketService = SocketService();
    final userId = _currentUserId ?? '';
    
    if (userId.isNotEmpty) {
      socketService.connect(userId);

      // Listen for ticket updates
      socketService.on('ticket_assigned', (data) {
        print('📡 [FLUTTER] Ticket assigned event: $data');
        if (data['complaint']?['id'] == widget.ticketId) {
          _loadTicketDetails();
        }
      });

      socketService.on('ticket_comment_added', (data) {
        print('📡 [FLUTTER] Comment added event: $data');
        if (data['complaint']?['id'] == widget.ticketId) {
          _loadTicketDetails();
          _scrollToBottom();
        }
      });

      socketService.on('complaint_status_updated', (data) {
        print('📡 [FLUTTER] Status updated event: $data');
        if (data['complaint']?['id'] == widget.ticketId) {
          _loadTicketDetails();
        }
      });

      socketService.on('work_update_added', (data) {
        print('📡 [FLUTTER] Work update added event: $data');
        if (data['complaint']?['id'] == widget.ticketId) {
          _loadTicketDetails();
        }
      });

      socketService.on('ticket_reopened', (data) {
        print('📡 [FLUTTER] Ticket reopened event: $data');
        if (data['complaintId'] == widget.ticketId) {
          _loadTicketDetails();
        }
      });

      socketService.on('ticket_closed', (data) {
        print('📡 [FLUTTER] Ticket closed event: $data');
        if (data['complaintId'] == widget.ticketId) {
          _loadTicketDetails();
        }
      });

      socketService.on('ticket_cancelled', (data) {
        print('📡 [FLUTTER] Ticket cancelled event: $data');
        if (data['complaintId'] == widget.ticketId) {
          _loadTicketDetails();
        }
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

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ErrorSnackBar.show(context, 'Please enter a comment');
      return;
    }

    try {
      final response = await TicketService.addComment(widget.ticketId, text);
      if (response['success'] == true) {
        _commentController.clear();
        _loadTicketDetails();
        SuccessSnackBar.show(context, 'Comment added successfully');
      } else {
        ErrorSnackBar.show(context, response['message'] ?? 'Failed to add comment');
      }
    } catch (e) {
      ErrorSnackBar.show(context, 'Error adding comment: ${e.toString()}');
    }
  }

  Future<void> _reopenTicket() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen Ticket'),
        content: const Text('Are you sure you want to reopen this ticket?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await TicketService.reopenTicket(widget.ticketId);
      ApiResponseHandler.handle(
        context,
        response,
        onSuccess: () => _loadTicketDetails(),
      );
    } catch (e) {
      ErrorSnackBar.show(context, 'Error reopening ticket: ${e.toString()}');
    }
  }

  Future<void> _closeTicket() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Ticket'),
        content: const Text('Are you sure the issue has been resolved?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await TicketService.closeTicket(widget.ticketId);
      ApiResponseHandler.handle(
        context,
        response,
        onSuccess: () => _loadTicketDetails(),
      );
    } catch (e) {
      ErrorSnackBar.show(context, 'Error closing ticket: ${e.toString()}');
    }
  }

  Future<void> _cancelTicket() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ticket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for cancellation:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Cancellation reason',
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await TicketService.cancelTicket(
        widget.ticketId,
        reason: reasonController.text.trim(),
      );
      ApiResponseHandler.handle(
        context,
        response,
        onSuccess: () => _loadTicketDetails(),
      );
    } catch (e) {
      ErrorSnackBar.show(context, 'Error cancelling ticket: ${e.toString()}');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'in progress':
        return Colors.purple;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      case 'reopened':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket: ${_ticket?.ticketNumber ?? 'Loading...'}'),
        backgroundColor: AppColors.primary,
        actions: [
          if (_ticket != null && _currentUserRole == 'admin' && _ticket!.status == 'Open')
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _showAssignDialog(),
              tooltip: 'Assign Ticket',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ticket == null
              ? const Center(child: Text('Ticket not found'))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatusCard(),
                            const SizedBox(height: 16),
                            _buildDetailsCard(),
                            if (_ticket!.assignedTo != null) ...[
                              const SizedBox(height: 16),
                              _buildAssignmentCard(),
                            ],
                            if (_ticket!.workUpdates != null && _ticket!.workUpdates!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildWorkUpdatesCard(),
                            ],
                            if (_ticket!.timeline != null && _ticket!.timeline!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildTimelineCard(),
                            ],
                            if (_ticket!.comments != null && _ticket!.comments!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildCommentsCard(),
                            ],
                            const SizedBox(height: 80), // Space for comment input
                          ],
                        ),
                      ),
                    ),
                    _buildCommentInput(),
                  ],
                ),
      bottomNavigationBar: _ticket != null ? _buildActionButtons() : null,
    );
  }

  Widget _buildStatusCard() {
    final status = _ticket!.status;
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      _ticket!.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${_ticket!.category} • Priority: ${_ticket!.priority}',
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ticket Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            label: 'Ticket Number',
            value: _ticket!.ticketNumber,
          ),
          _DetailRow(
            label: 'Priority',
            value: _ticket!.priority,
          ),
          _DetailRow(
            label: 'Description',
            value: _ticket!.description,
            isMultiline: true,
          ),
          if (_ticket!.location != null) ...[
            const Divider(),
            const Text(
              'Location',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Address',
              value: _ticket!.location!.displayAddress,
            ),
            if (_ticket!.location!.accessInstructions != null)
              _DetailRow(
                label: 'Access Instructions',
                value: _ticket!.location!.accessInstructions!,
                isMultiline: true,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignmentCard() {
    final assignedTo = _ticket!.assignedTo!;
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
              Icon(Icons.person, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'Assigned To',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (assignedTo.staff?.user != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: assignedTo.staff!.user!.profilePicture != null
                    ? NetworkImage(assignedTo.staff!.user!.profilePicture!)
                    : null,
                child: assignedTo.staff!.user!.profilePicture == null
                    ? Text(assignedTo.staff!.user!.fullName[0].toUpperCase())
                    : null,
              ),
              title: Text(assignedTo.staff!.user!.fullName),
              subtitle: Text(
                assignedTo.assignedAt != null
                    ? 'Assigned on ${DateFormat('MMM d, yyyy').format(assignedTo.assignedAt!)}'
                    : 'Assigned',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkUpdatesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Work Updates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._ticket!.workUpdates!.map((update) {
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
                        backgroundImage: update.updatedByUser?.profilePicture != null
                            ? NetworkImage(update.updatedByUser!.profilePicture!)
                            : null,
                        child: update.updatedByUser?.profilePicture == null
                            ? Text(
                                (update.updatedByUser?.fullName[0] ?? 'S').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              update.updatedByUser?.fullName ?? 'Staff',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('MMM d, yyyy • h:mm a').format(update.timestamp),
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
                  Text(update.description),
                  if (update.images.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: update.images.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Image.network(
                              update.images[index].url,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._ticket!.timeline!.asMap().entries.map((entry) {
            final index = entry.key;
            final event = entry.value;
            final isLast = index == _ticket!.timeline!.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getStatusColor(event.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: Colors.grey.shade300,
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.status,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (event.description.isNotEmpty)
                          Text(
                            event.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        Text(
                          DateFormat('MMM d, yyyy • h:mm a').format(event.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCommentsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.comment, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._ticket!.comments!.map((comment) {
            final isMyComment = comment.postedBy == _currentUserId;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isMyComment ? Colors.blue.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMyComment ? Colors.blue.shade200 : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: comment.postedByUser?.profilePicture != null
                            ? NetworkImage(comment.postedByUser!.profilePicture!)
                            : null,
                        child: comment.postedByUser?.profilePicture == null
                            ? Text(
                                (comment.postedByUser?.fullName[0] ?? 'U').toUpperCase(),
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comment.postedByUser?.fullName ?? 'User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('MMM d, yyyy • h:mm a').format(comment.postedAt),
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
                  Text(comment.text),
                  if (comment.media.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: comment.media.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Image.network(
                              comment.media[index].url,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
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
            icon: const Icon(Icons.send, color: AppColors.primary),
            onPressed: _addComment,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_ticket == null) return const SizedBox.shrink();

    final isResident = _currentUserRole == 'resident';
    final isMyTicket = _ticket!.createdBy == _currentUserId;

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (isResident && isMyTicket && _ticket!.canReopen)
            ElevatedButton.icon(
              onPressed: _reopenTicket,
              icon: const Icon(Icons.refresh),
              label: const Text('Reopen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          if (isResident && isMyTicket && _ticket!.canClose)
            ElevatedButton.icon(
              onPressed: _closeTicket,
              icon: const Icon(Icons.check_circle),
              label: const Text('Close'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          if (isResident && isMyTicket && _ticket!.canCancel)
            ElevatedButton.icon(
              onPressed: _cancelTicket,
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAssignDialog() async {
    // This would show a dialog to select staff
    // For now, just show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Ticket'),
        content: const Text('Staff selection dialog - to be implemented'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
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

