import '../../../core/imports/app_imports.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/complaint_data.dart';

class AdminComplaintDetailScreen extends StatefulWidget {
  final String complaintId;

  const AdminComplaintDetailScreen({super.key, required this.complaintId});

  @override
  State<AdminComplaintDetailScreen> createState() => _AdminComplaintDetailScreenState();
}

class _AdminComplaintDetailScreenState extends State<AdminComplaintDetailScreen> {
  Map<String, dynamic>? _complaint;
  List<Map<String, dynamic>>? _staffList;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  bool _isUploadingMedia = false;
  bool _isAddingNote = false;
  bool _isPostingComment = false;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _internalNoteController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<File> _selectedCommentMedia = [];

  String? _getUserRole() {
    try {
      final userJson = StorageService.getString(AppConstants.userKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        return userData['role']?.toString();
      }
    } catch (e) {
      print('❌ [FLUTTER] Error getting user role: $e');
    }
    return null;
  }

  bool get _isStaff => _getUserRole() == 'staff';
  bool get _isAdmin => _getUserRole() == 'admin';

  @override
  void initState() {
    super.initState();
    _loadComplaintDetails();
    if (_isAdmin) {
      _loadStaffList();
    }
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _internalNoteController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
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
          
          // Listen for complaint updates
          socketService.on('complaint_updated', (data) {
            print('📡 [FLUTTER] Complaint updated event received: $data');
            if (mounted && (data['complaintId'] == widget.complaintId || 
                           data['ticketId'] == widget.complaintId ||
                           data['complaint']?['id'] == widget.complaintId ||
                           data['id'] == widget.complaintId)) {
              _loadComplaintDetails();
            }
          });
          
          // Listen for status updates
          socketService.on('ticket_status_updated', (data) {
            print('📡 [FLUTTER] Ticket status updated event received: $data');
            if (mounted && (data['complaintId'] == widget.complaintId || 
                           data['ticketId'] == widget.complaintId ||
                           data['complaint']?['id'] == widget.complaintId ||
                           data['id'] == widget.complaintId)) {
              _loadComplaintDetails();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Status updated to ${data['newStatus'] ?? data['status'] ?? 'new status'}'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          });

          // Listen for status change confirmation
          socketService.on('status_change_confirmation', (data) {
            print('📡 [FLUTTER] Status change confirmation received: $data');
            if (mounted && (data['complaintId'] == widget.complaintId || 
                           data['ticketId'] == widget.complaintId ||
                           data['id'] == widget.complaintId)) {
              _loadComplaintDetails();
            }
          });

          // Listen for complaint status updates
          socketService.on('complaint_status_updated', (data) {
            print('📡 [FLUTTER] Complaint status updated event received: $data');
            if (mounted && (data['complaintId'] == widget.complaintId ||
                           data['ticketId'] == widget.complaintId ||
                           data['complaint']?['id'] == widget.complaintId ||
                           data['id'] == widget.complaintId)) {
              _loadComplaintDetails();
            }
          });

          // Listen for new comments (from other users only - our own comments are added instantly)
          socketService.on('comment_added', (data) {
            print('📡 [FLUTTER] Comment added event received: $data');
            if (mounted && (data['complaintId'] == widget.complaintId ||
                           data['ticketId'] == widget.complaintId ||
                           data['complaint']?['id'] == widget.complaintId ||
                           data['id'] == widget.complaintId)) {
              // Only update if comment is from another user (not our own)
              final commentData = data['comment'] ?? data;
              final postedBy = commentData['postedBy'];
              final currentUserId = userData['_id'] ?? userData['id'];
              final commentUserId = postedBy?['_id'] ?? postedBy?['id'];
              
              // If comment is from current user, ignore (we already added it instantly)
              if (currentUserId != null && commentUserId != null && 
                  currentUserId.toString() == commentUserId.toString()) {
                print('📡 [FLUTTER] Ignoring own comment from socket (already added instantly)');
                return;
              }
              
              // Add comment from other users instantly without full reload
              if (commentData != null && _complaint != null) {
                setState(() {
                  final comments = List<Map<String, dynamic>>.from(
                    _complaint!['comments'] ?? [],
                  );
                  
                  // Check if comment already exists (avoid duplicates)
                  final commentId = commentData['_id'] ?? commentData['id'];
                  final exists = comments.any((c) => 
                    (c['_id'] ?? c['id'])?.toString() == commentId?.toString()
                  );
                  
                  if (!exists) {
                    comments.insert(0, Map<String, dynamic>.from(commentData));
                    _complaint!['comments'] = comments;
                  }
                });
              }
            }
          });

          // Listen for media uploads
          socketService.on('media_uploaded', (data) {
            print('📡 [FLUTTER] Media uploaded event received: $data');
            if (mounted && (data['complaintId'] == widget.complaintId ||
                           data['ticketId'] == widget.complaintId ||
                           data['complaint']?['id'] == widget.complaintId ||
                           data['id'] == widget.complaintId)) {
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
      final response = await ApiService.get(ApiConstants.complaintById(widget.complaintId));
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

  Future<void> _loadStaffList() async {
    try {
      final response = await ApiService.get(ApiConstants.adminStaff);
      if (response['success'] == true && mounted) {
        setState(() {
          _staffList = List<Map<String, dynamic>>.from(
            response['data']?['staff'] ?? []
          );
        });
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading staff list: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isAdmin) {
      await Future.wait([
        _loadComplaintDetails(),
        _loadStaffList(),
      ]);
    } else {
      await _loadComplaintDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _complaint == null
              ? const Center(child: Text('Complaint not found'))
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: Resident & Flat Context
                        _buildResidentContextCard(),
                        const SizedBox(height: 16),
                        
                        // Section 2: Complaint Summary
                        _buildComplaintSummaryCard(),
                        const SizedBox(height: 16),
                        
                        // Section 3: Media Attachments
                        _buildMediaSection(),
                        const SizedBox(height: 16),
                        
                        // Section 4: Status & Assignment Control
                        _buildStatusAndAssignmentCard(),
                        const SizedBox(height: 16),
                        
                        // Section 5: Internal Admin Notes
                        _buildInternalNotesCard(),
                        const SizedBox(height: 16),
                        
                        // Section 6: Resident Communication Timeline
                        _buildCommunicationTimeline(),
                        const SizedBox(height: 16),
                        
                        // Section 7: Add Comment
                        _buildCommentInputSection(),
                        const SizedBox(height: 16),
                        
                        // Section 8: Resolution & Closure Flow
                        if (_complaint?['status'] == 'Resolved' || _complaint?['status'] == 'Closed')
                          _buildResolutionCard(),
                        const SizedBox(height: 100), // Space for FAB
                      ],
                    ),
                  ),
                ),
    );
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
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _refreshData,
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

  Widget _buildResidentContextCard() {
    final createdBy = _complaint?['createdBy'];
    if (createdBy == null) return const SizedBox.shrink();

    final profilePicUrl = _getProfilePictureUrl(createdBy);
    final phone = createdBy['phoneNumber']?.toString();
    final flatInfo = '${createdBy['wing'] ?? ''}${createdBy['wing'] != null && createdBy['flatNumber'] != null ? '-' : ''}${createdBy['flatNumber'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.background,
                  backgroundImage: profilePicUrl != null
                      ? NetworkImage(profilePicUrl)
                      : null,
                  onBackgroundImageError: profilePicUrl != null
                      ? (exception, stackTrace) {
                          print('❌ [FLUTTER] Failed to load profile picture: $exception');
                        }
                      : null,
                  child: profilePicUrl == null
                      ? Text(
                          (createdBy['fullName']?[0] ?? 'R').toUpperCase(),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
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
                        createdBy['fullName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (flatInfo.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.border.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.home_rounded,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                flatInfo,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                _buildPriorityBadge(_complaint?['priority'] ?? 'Medium'),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.phone_rounded,
                    label: 'Call',
                    color: AppColors.success,
                    onTap: () {
                      if (phone != null) {
                        launchUrl(Uri.parse('tel:$phone'));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.message_rounded,
                    label: 'SMS',
                    color: AppColors.info,
                    onTap: () {
                      if (phone != null) {
                        launchUrl(Uri.parse('sms:$phone'));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Raised: ${_formatDateTime(_complaint?['createdAt'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withOpacity(0.3),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1), // Soft indigo
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Complaint Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _complaint?['title'] ?? 'No Title',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_complaint?['category'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.category_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _complaint!['category'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_complaint?['subCategory'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.label_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _complaint!['subCategory'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.3),
                ),
              ),
              child: Text(
                _complaint?['description'] ?? 'No description',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
            if (_complaint?['location']?['specificLocation'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _complaint!['location']['specificLocation'],
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
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
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  String? _getProfilePictureUrl(Map<String, dynamic>? userData) {
    if (userData == null) return null;
    
    try {
      final profilePicture = userData['profilePicture'];
      if (profilePicture == null) return null;

      // If it's a string, return it directly (after trimming)
      if (profilePicture is String) {
        final url = profilePicture.trim();
        return url.isNotEmpty ? url : null;
      }

      // If it's a Map, extract the URL
      if (profilePicture is Map) {
        final url = profilePicture['url']?.toString()?.trim();
        return url != null && url.isNotEmpty ? url : null;
      }

      return null;
    } catch (e) {
      print('❌ [FLUTTER] Error extracting profile picture URL: $e');
      return null;
    }
  }

  Widget _buildMediaSection() {
    final residentMedia = List<Map<String, dynamic>>.from(_complaint?['media'] ?? []);
    final adminMedia = List<Map<String, dynamic>>.from(_complaint?['adminMedia'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withOpacity(0.3),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6), // Soft blue
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Media Attachments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Resident Attachments
            if (residentMedia.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Resident Attachments',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${residentMedia.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: residentMedia.length,
                  itemBuilder: (context, index) {
                    final media = residentMedia[index];
                    return _buildMediaThumbnail(
                      media['url'] ?? '',
                      media['type'] ?? 'image',
                      isAdmin: false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Admin Media
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Admin Evidence',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (adminMedia.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${adminMedia.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (adminMedia.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: adminMedia.length,
                  itemBuilder: (context, index) {
                    final media = adminMedia[index];
                    return _buildMediaThumbnail(
                      media['url'] ?? '',
                      media['type'] ?? 'image',
                      isAdmin: true,
                      purpose: media['purpose'],
                    );
                  },
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border.withOpacity(0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Text(
                    'No evidence added yet',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploadingMedia ? null : _showMediaUploadDialog,
                icon: _isUploadingMedia
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.camera_alt_rounded),
                label: Text(_isUploadingMedia ? 'Uploading...' : 'Add Evidence'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6), // Soft blue
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaThumbnail(String url, String type, {bool isAdmin = false, String? purpose}) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdmin
              ? AppColors.primary
              : AppColors.border.withOpacity(0.3),
          width: isAdmin ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isAdmin
                ? AppColors.primary.withOpacity(0.2)
                : Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (type == 'image')
              Image.network(
                url,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: AppColors.background,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.background,
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: AppColors.textLight,
                      size: 40,
                    ),
                  );
                },
              )
            else
              Container(
                color: AppColors.background,
                child: const Icon(
                  Icons.videocam_rounded,
                  size: 40,
                  color: AppColors.textLight,
                ),
              ),
            if (isAdmin && purpose != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6), // Soft blue
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    purpose.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showMediaViewer(url, type),
                  borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black.withOpacity(0.2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.zoom_in_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
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
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: type == 'image'
                    ? Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(40),
                            child: const Icon(
                              Icons.broken_image_rounded,
                              size: 64,
                              color: Colors.white70,
                            ),
                          );
                        },
                      )
                    : Container(
                        padding: const EdgeInsets.all(40),
                        child: const Icon(
                          Icons.videocam_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaUploadDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Add Evidence',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6), // Soft blue
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              ),
              title: const Text(
                'Take Photo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1), // Soft indigo
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Colors.white),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null && mounted) {
        // Upload without reloading - just update state
        await _uploadAdminMedia(File(image.path), skipReload: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadAdminMedia(File file, {bool skipReload = false}) async {
    setState(() => _isUploadingMedia = true);
    try {
      final response = await ApiService.uploadFile(
        ApiConstants.complaintUploadAdminMedia(widget.complaintId),
        file,
        fieldName: 'media',
        additionalFields: {
          'purpose': 'evidence',
          'description': '',
        },
      );

      if (response['success'] == true) {
        if (mounted) {
          // Update local state immediately for instant feedback
          final uploadedMedia = response['data']?['media'] ?? 
                                response['data']?['adminMedia'] ??
                                response['data'];
          
          if (uploadedMedia != null && _complaint != null) {
            setState(() {
              final adminMedia = List<Map<String, dynamic>>.from(
                _complaint!['adminMedia'] ?? [],
              );
              
              // Add the new media item
              if (uploadedMedia is Map) {
                adminMedia.insert(0, Map<String, dynamic>.from(uploadedMedia));
              } else if (uploadedMedia is List && uploadedMedia.isNotEmpty) {
                adminMedia.insertAll(0, 
                  uploadedMedia.cast<Map<String, dynamic>>().map((m) => 
                    Map<String, dynamic>.from(m)
                  ),
                );
              }
              
              _complaint!['adminMedia'] = adminMedia;
            });
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Evidence uploaded successfully!',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981), // Soft green
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          
          // No reload - instant update only
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(response['message'] ?? 'Upload failed'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444), // Soft red
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error uploading: ${e.toString().length > 50 ? e.toString().substring(0, 50) + "..." : e.toString()}'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  Widget _buildStatusAndAssignmentCard() {
    final status = _complaint?['status'] ?? 'Open';
    final assignedTo = _complaint?['assignedTo'];
    final assignedStaff = assignedTo?['staff'];
    final assignedStaffUser = assignedStaff is Map
        ? assignedStaff['user'] ?? {}
        : {};

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6), // Soft purple
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Status & Assignment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Status Dropdown
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.3),
                ),
              ),
              child: DropdownButtonFormField<String>(
                value: status,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: ['Open', 'Assigned', 'In Progress', 'Resolved', 'Closed']
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(s).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getStatusIcon(s),
                                  size: 16,
                                  color: _getStatusColor(s),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(s),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: _isUpdatingStatus
                    ? null
                    : (newStatus) {
                        if (newStatus != null && newStatus != status) {
                          _updateStatus(newStatus);
                        }
                      },
              ),
            ),
            if (_isUpdatingStatus)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Priority Dropdown
            const Text(
              'Priority',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.3),
                ),
              ),
              child: DropdownButtonFormField<String>(
                value: _complaint?['priority'] ?? 'Medium',
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: ['Low', 'Medium', 'High', 'Emergency']
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(p).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.flag_rounded,
                                  size: 16,
                                  color: _getPriorityColor(p),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(p),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (newPriority) {
                  if (newPriority != null) {
                    _updatePriority(newPriority);
                  }
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Staff Assignment
            const Text(
              'Assign Staff',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (_staffList != null && _staffList!.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.border.withOpacity(0.3),
                  ),
                ),
                child: DropdownButtonFormField<String>(
                  value: assignedTo?['staff']?['_id']?.toString() ?? 
                         assignedTo?['staff']?.toString(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    hintText: 'Select staff member',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ..._staffList!.map((staff) {
                      final staffId = staff['_id']?.toString() ?? '';
                      final user = staff['user'] ?? {};
                      final userName = user['fullName'] ?? 'Unknown';
                      final specialization = staff['specialization'] ?? '';
                      final staffProfilePic = _getProfilePictureUrl(user);
                      return DropdownMenuItem<String>(
                        value: staffId,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              backgroundImage: staffProfilePic != null
                                  ? NetworkImage(staffProfilePic)
                                  : null,
                              child: staffProfilePic == null
                                  ? Text(
                                      (userName[0] ?? 'S').toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (specialization.isNotEmpty)
                                    Text(
                                      specialization,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (staffId) {
                    if (staffId != null) {
                      _assignStaff(staffId);
                    } else {
                      _assignStaff('');
                    }
                  },
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No staff available',
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
            
            // Current Assignment Display
            if (assignedTo != null && assignedStaff != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.border.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.info.withOpacity(0.1),
                      backgroundImage: _getProfilePictureUrl(assignedStaffUser) != null
                          ? NetworkImage(_getProfilePictureUrl(assignedStaffUser)!)
                          : null,
                      child: _getProfilePictureUrl(assignedStaffUser) == null
                          ? Text(
                              (assignedStaffUser['fullName']?[0] ?? 'S').toUpperCase(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.info,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignedStaffUser['fullName'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (assignedTo['assignedAt'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: AppColors.textLight,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Assigned: ${_formatDateTime(assignedTo['assignedAt'])}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'emergency':
        return AppColors.error;
      case 'high':
        return Colors.orange;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildInternalNotesCard() {
    final notes = List<Map<String, dynamic>>.from(_complaint?['internalNotes'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B), // Soft amber
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Internal Admin Notes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.border.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'Private',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Notes List
            if (notes.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border.withOpacity(0.3),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.note_add_outlined,
                        size: 40,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No internal notes yet',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...notes.map((note) => _buildNoteItem(note)),
            
            const SizedBox(height: 16),
            
            // Add Note Field
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.3),
                ),
              ),
              child: TextField(
                controller: _internalNoteController,
                decoration: InputDecoration(
                  hintText: 'Add internal note (not visible to residents)...',
                  hintStyle: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAddingNote ? null : _addInternalNote,
                icon: _isAddingNote
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.note_add_rounded),
                    label: Text(_isAddingNote ? 'Adding...' : 'Add Note'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B), // Soft amber
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem(Map<String, dynamic> note) {
    final addedBy = note['addedBy'];
    final addedByMap = addedBy is Map
        ? Map<String, dynamic>.from(addedBy)
        : <String, dynamic>{};
    final profilePicUrl = _getProfilePictureUrl(addedByMap);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.background,
                backgroundImage: profilePicUrl != null
                    ? NetworkImage(profilePicUrl)
                    : null,
                onBackgroundImageError: profilePicUrl != null
                    ? (exception, stackTrace) {
                        print('❌ [FLUTTER] Failed to load profile picture: $exception');
                      }
                    : null,
                child: profilePicUrl == null
                    ? Text(
                        (addedByMap['fullName']?[0] ?? 'A').toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addedByMap['fullName'] ?? 'Admin',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note['note'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _formatDateTime(note['addedAt']),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommunicationTimeline() {
    final timeline = List<Map<String, dynamic>>.from(_complaint?['timeline'] ?? []);
    final comments = List<Map<String, dynamic>>.from(_complaint?['comments'] ?? []);

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
      final commentData = comment is Map
          ? Map<String, dynamic>.from(comment)
          : <String, dynamic>{};
      
      if (commentData['postedBy'] != null && commentData['postedBy'] is Map) {
        commentData['postedBy'] = Map<String, dynamic>.from(commentData['postedBy']);
      }
      
      allEvents.add({
        'type': 'comment',
        'data': commentData,
        'timestamp': commentData['postedAt'],
      });
    }
    
    // Sort by timestamp
    allEvents.sort((a, b) {
      final aTime = _parseDateTime(a['timestamp']);
      final bTime = _parseDateTime(b['timestamp']);
      return bTime.compareTo(aTime); // Newest first
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withOpacity(0.3),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981), // Soft green
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.timeline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Communication Timeline',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (allEvents.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${allEvents.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (allEvents.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border.withOpacity(0.3),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 48,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No activity yet',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                      ),
                    ],
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
    final updatedByRaw = data['updatedBy'];
    final updatedBy = updatedByRaw is Map
        ? Map<String, dynamic>.from(updatedByRaw)
        : <String, dynamic>{};
    final statusColor = _getStatusColor(status);
    final profilePicUrl = _getProfilePictureUrl(updatedBy);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(status),
              color: Colors.white,
              size: 20,
            ),
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
                        'Status Changed: $status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: profilePicUrl != null
                          ? NetworkImage(profilePicUrl)
                          : null,
                      child: profilePicUrl == null
                          ? Text(
                              (updatedBy['fullName']?[0] ?? 'A').toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  updatedBy['fullName'] ?? 'Admin',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (updatedBy['role'] != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRoleBadgeColor(updatedBy['role']?.toString().toLowerCase() ?? ''),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getRoleBadgeLabel(updatedBy['role']?.toString().toLowerCase() ?? ''),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 11,
                                color: AppColors.textLight,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _formatDateTime(timestamp),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
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
    final text = data['text']?.toString().trim() ?? '';
    final postedByRaw = data['postedBy'];
    final postedBy = postedByRaw is Map
        ? Map<String, dynamic>.from(postedByRaw)
        : null;
    final media = List<Map<String, dynamic>>.from(data['media'] ?? []);

    // Get role from postedBy
    final role = postedBy?['role']?.toString().toLowerCase() ?? 'resident';
    final isAdmin = role == 'admin';
    final isStaff = role == 'staff';
    
    final profilePicUrl = postedBy != null ? _getProfilePictureUrl(postedBy) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isAdmin
                    ? AppColors.primary
                    : AppColors.border.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: isAdmin
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.background,
              backgroundImage: profilePicUrl != null
                  ? NetworkImage(profilePicUrl)
                  : null,
              onBackgroundImageError: profilePicUrl != null
                  ? (exception, stackTrace) {
                      print('❌ [FLUTTER] Failed to load profile picture: $exception');
                    }
                  : null,
              child: profilePicUrl == null
                  ? Text(
                      (postedBy?['fullName']?[0] ?? 'U').toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isAdmin ? AppColors.primary : AppColors.textSecondary,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      postedBy?['fullName'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (role.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleBadgeColor(role),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getRoleBadgeLabel(role),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
                if (media.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: media.map((m) {
                      return GestureDetector(
                        onTap: () => _showMediaViewer(
                          m['url'] ?? '',
                          m['type'] ?? 'image',
                        ),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border.withOpacity(0.3),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: m['type'] == 'image'
                                ? Image.network(
                                    m['url'] ?? '',
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: AppColors.background,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                : null,
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: AppColors.background,
                                        child: const Icon(
                                          Icons.broken_image_rounded,
                                          color: AppColors.textLight,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: AppColors.background,
                                    child: const Icon(
                                      Icons.videocam_rounded,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _formatDateTime(timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputSection() {
    final status = _complaint?['status'] ?? 'Open';
    if (status == 'Closed' || status == 'Cancelled') {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withOpacity(0.3),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6), // Soft blue
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.comment_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add Comment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.3),
                ),
              ),
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Type your comment...',
                  hintStyle: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                maxLines: 4,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            if (_selectedCommentMedia.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border.withOpacity(0.3),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedCommentMedia.asMap().entries.map((entry) {
                    final index = entry.key;
                    final file = entry.value;
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              file,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCommentMedia.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.border.withOpacity(0.3),
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.photo_camera_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: _pickCommentMedia,
                    tooltip: 'Add Photo',
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isPostingComment ? null : _postComment,
                  icon: _isPostingComment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isPostingComment ? 'Posting...' : 'Post'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6), // Soft blue
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCommentMedia() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6), // Soft blue
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              ),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera, isComment: true);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1), // Soft indigo
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Colors.white),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.gallery, isComment: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source, {bool isComment = false}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null && mounted) {
        if (isComment) {
          setState(() {
            _selectedCommentMedia.add(File(image.path));
          });
        } else {
          await _uploadAdminMedia(File(image.path), skipReload: true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _selectedCommentMedia.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a comment or add media'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    setState(() => _isPostingComment = true);

    try {
      List<ComplaintMedia>? mediaList;
      
      // Upload media files if any
      if (_selectedCommentMedia.isNotEmpty) {
        mediaList = [];
        for (var file in _selectedCommentMedia) {
          try {
            final uploadResponse = await ApiService.uploadFile(
              '/upload/media',
              file,
              fieldName: 'image',
            );
            if (uploadResponse['success'] == true) {
              final mediaData = uploadResponse['data']?['media'] ?? uploadResponse['data'];
              mediaList.add(ComplaintMedia(
                url: mediaData['url'] ?? uploadResponse['data']?['url'] ?? '',
                publicId: mediaData['publicId']?.toString() ?? uploadResponse['data']?['publicId']?.toString(),
                type: 'image',
              ));
            }
          } catch (e) {
            print('❌ [FLUTTER] Error uploading media: $e');
          }
        }
      }

      // Post comment with media
      final response = await ApiService.post(
        '${ApiConstants.complaints}/${widget.complaintId}/comments',
        {
          'text': text.isEmpty ? ' ' : text,
          if (mediaList != null && mediaList.isNotEmpty)
            'media': mediaList.map((m) => m.toJson()).toList(),
        },
      );

      if (response['success'] == true) {
        // Get current user info for instant display
        final userJson = StorageService.getString(AppConstants.userKey);
        Map<String, dynamic>? currentUser;
        if (userJson != null) {
          try {
            currentUser = jsonDecode(userJson);
          } catch (e) {
            print('Error parsing user data: $e');
          }
        }
        
        // Prepare comment data from response or create new
        final newComment = response['data']?['comment'] ?? 
                          response['data']?['data'] ?? 
                          response['data'];
        
        // Create comment object with all necessary data
        Map<String, dynamic> commentData;
        if (newComment is Map && newComment.isNotEmpty) {
          commentData = Map<String, dynamic>.from(newComment);
          // Ensure postedBy is properly set
          if (commentData['postedBy'] == null && currentUser != null) {
            commentData['postedBy'] = currentUser;
          }
          // Ensure postedAt is set
          if (commentData['postedAt'] == null) {
            commentData['postedAt'] = DateTime.now().toIso8601String();
          }
          // Ensure media is properly formatted
          if (mediaList != null && mediaList.isNotEmpty && commentData['media'] == null) {
            commentData['media'] = mediaList.map((m) => m.toJson()).toList();
          }
        } else {
          // Create new comment object if response doesn't have it
          commentData = <String, dynamic>{
            'text': text.isEmpty ? ' ' : text,
            'postedAt': DateTime.now().toIso8601String(),
            'postedBy': currentUser ?? {'fullName': 'Admin', 'role': 'admin'},
            if (mediaList != null && mediaList.isNotEmpty)
              'media': mediaList.map((m) => m.toJson()).toList(),
          };
        }
        
        // Update state immediately - instant feedback
        if (_complaint != null) {
          setState(() {
            // Clear inputs first
            _commentController.clear();
            _selectedCommentMedia.clear();
            
            // Add comment to the list immediately
            final comments = List<Map<String, dynamic>>.from(
              _complaint!['comments'] ?? [],
            );
            comments.insert(0, commentData);
            _complaint!['comments'] = comments;
          });
        } else {
          // Clear inputs even if complaint is null
          _commentController.clear();
          setState(() {
            _selectedCommentMedia.clear();
          });
        }
        
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Comment posted successfully!',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF3B82F6), // Soft blue
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          
          // Scroll to top to show new comment after a brief delay
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
        
        // NO RELOAD - Instant update only, real-time display
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(response['message'] ?? 'Failed to post comment'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [FLUTTER] Error posting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error: ${e.toString().length > 50 ? e.toString().substring(0, 50) + "..." : e.toString()}'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPostingComment = false);
      }
    }
  }

  Widget _buildResolutionCard() {
    final resolution = _complaint?['resolution'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981), // Soft green
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Resolution',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (resolution?['description'] != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  resolution['description'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            if (resolution?['resolvedAt'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Resolved: ${_formatDateTime(resolution['resolvedAt'])}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
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


  Future<void> _updateStatus(String newStatus) async {
    final oldStatus = _complaint?['status'] ?? 'Unknown';
    
    // Show confirmation dialog for critical status changes
    if (newStatus == 'Closed' || newStatus == 'Resolved') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Change Status to $newStatus?'),
          content: Text(
            newStatus == 'Closed'
                ? 'Are you sure you want to close this complaint? Once closed, it cannot be reopened automatically.'
                : 'Are you sure the issue has been resolved? The resident will be notified.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isUpdatingStatus = true);
    try {
      // Prepare request body with status
      final requestBody = {
        'status': newStatus,
        'description': 'Status changed from $oldStatus to $newStatus',
      };

      print('🔄 [FLUTTER] Updating status from $oldStatus to $newStatus');
      final response = await ApiService.put(
        ApiConstants.complaintStatus(widget.complaintId),
        requestBody,
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated to $newStatus'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
          // Reload complaint details to get latest state
          await _loadComplaintDetails();
          print('✅ [FLUTTER] Status updated successfully to $newStatus');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to update status'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        print('❌ [FLUTTER] Status update failed: ${response['message']}');
      }
    } catch (e) {
      print('❌ [FLUTTER] Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _updatePriority(String priority) async {
    try {
      final response = await ApiService.put(
        ApiConstants.complaintPriority(widget.complaintId),
        {'priority': priority},
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Priority updated to $priority'),
              backgroundColor: AppColors.success,
            ),
          );
          await _loadComplaintDetails();
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

  Future<void> _assignStaff(String staffId) async {
    try {
      final response = await ApiService.post(
        ApiConstants.complaintAssign(widget.complaintId),
        staffId.isEmpty ? {} : {'staffId': staffId},
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(staffId.isEmpty ? 'Staff unassigned' : 'Staff assigned'),
              backgroundColor: AppColors.success,
            ),
          );
          await _loadComplaintDetails();
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

  Future<void> _addInternalNote() async {
    final note = _internalNoteController.text.trim();
    if (note.isEmpty) return;

    setState(() => _isAddingNote = true);
    
    // Get current user info for instant display
    final userJson = StorageService.getString(AppConstants.userKey);
    Map<String, dynamic>? currentUser;
    if (userJson != null) {
      try {
        currentUser = jsonDecode(userJson);
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }

    try {
      final response = await ApiService.post(
        ApiConstants.complaintInternalNotes(widget.complaintId),
        {'note': note},
      );

      if (response['success'] == true) {
        // Update local state immediately for instant feedback
        final newNote = response['data']?['note'] ?? response['data'];
        if (newNote != null && _complaint != null) {
          setState(() {
            final notes = List<Map<String, dynamic>>.from(
              _complaint!['internalNotes'] ?? [],
            );
            
            // Create note object with current user if available
            final noteData = newNote is Map
                ? Map<String, dynamic>.from(newNote)
                : <String, dynamic>{
                    'note': note,
                    'addedAt': DateTime.now().toIso8601String(),
                    'addedBy': currentUser ?? {'fullName': 'Admin'},
                  };
            
            notes.insert(0, noteData);
            _complaint!['internalNotes'] = notes;
          });
        }
        
        _internalNoteController.clear();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.note_add, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Internal note added successfully!',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFF59E0B), // Soft orange
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          
          // Scroll to show new note
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
          
          // No reload - instant update only
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(response['message'] ?? 'Failed to add note'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error: ${e.toString().length > 50 ? e.toString().substring(0, 50) + "..." : e.toString()}'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingNote = false);
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

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Icons.radio_button_unchecked;
      case 'assigned':
        return Icons.person_add;
      case 'in progress':
        return Icons.hourglass_empty;
      case 'resolved':
        return Icons.check_circle;
      case 'closed':
        return Icons.lock;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'Recently';
    try {
      final dt = dateTime is String ? DateTime.parse(dateTime) : dateTime as DateTime;
      return DateFormat('MMM d, yyyy • h:mm a').format(dt);
    } catch (e) {
      return 'Recently';
    }
  }

  DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return DateTime.now();
    try {
      return dateTime is String ? DateTime.parse(dateTime) : dateTime as DateTime;
    } catch (e) {
      return DateTime.now();
    }
  }

  Color _getRoleBadgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const Color(0xFF8B5CF6); // Purple
      case 'staff':
        return const Color(0xFF3B82F6); // Blue
      case 'resident':
        return const Color(0xFF10B981); // Green
      default:
        return AppColors.textSecondary;
    }
  }

  String _getRoleBadgeLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'ADMIN';
      case 'staff':
        return 'STAFF';
      case 'resident':
        return 'RESIDENT';
      default:
        return role.toUpperCase();
    }
  }
}
