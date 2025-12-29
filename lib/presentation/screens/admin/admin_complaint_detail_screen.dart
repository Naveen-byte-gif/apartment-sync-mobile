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

  @override
  void initState() {
    super.initState();
    _loadComplaintDetails();
    _loadStaffList();
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
                           data['complaint']?['id'] == widget.complaintId)) {
              _loadComplaintDetails();
            }
          });
          
          // Listen for status updates
          socketService.on('ticket_status_updated', (data) {
            print('📡 [FLUTTER] Ticket status updated event received: $data');
            if (mounted && (data['complaintId'] == widget.complaintId || 
                           data['ticketId'] == widget.complaintId ||
                           data['complaint']?['id'] == widget.complaintId)) {
              _loadComplaintDetails();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Status updated to ${data['newStatus'] ?? 'new status'}'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          });

          // Listen for status change confirmation (when admin makes the change)
          socketService.on('status_change_confirmation', (data) {
            print('📡 [FLUTTER] Status change confirmation received: $data');
            if (mounted && (data['complaintId'] == widget.complaintId || 
                           data['ticketId'] == widget.complaintId)) {
              _loadComplaintDetails();
            }
          });

          // Listen for complaint status updates (alternative event name)
          socketService.on('complaint_status_updated', (data) {
            print('📡 [FLUTTER] Complaint status updated event received: $data');
            if (mounted && (data['complaintId'] == widget.complaintId ||
                           data['ticketId'] == widget.complaintId ||
                           data['complaint']?['id'] == widget.complaintId)) {
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
    await Future.wait([
      _loadComplaintDetails(),
      _loadStaffList(),
    ]);
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
      floatingActionButton: _buildFloatingActionButton(),
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
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: _getProfilePictureUrl(createdBy) != null
                      ? NetworkImage(_getProfilePictureUrl(createdBy)!)
                      : null,
                  onBackgroundImageError: (exception, stackTrace) {
                    print('❌ [FLUTTER] Failed to load profile picture: $exception');
                  },
                  child: _getProfilePictureUrl(createdBy) == null
                      ? Text(
                          (createdBy['fullName']?[0] ?? 'R').toUpperCase(),
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
                        createdBy['fullName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (createdBy['flatNumber'] != null || createdBy['floorNumber'] != null)
                        Text(
                          '${createdBy['floorNumber'] ?? ''}${createdBy['flatNumber'] != null ? ' - ${createdBy['flatNumber']}' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (createdBy['wing'] != null)
                        Text(
                          'Wing: ${createdBy['wing']}',
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.phone,
                    label: 'Call',
                    color: AppColors.success,
                    onTap: () {
                      final phone = createdBy['phoneNumber']?.toString();
                      if (phone != null) {
                        launchUrl(Uri.parse('tel:$phone'));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.message,
                    label: 'Message',
                    color: AppColors.info,
                    onTap: () {
                      final phone = createdBy['phoneNumber']?.toString();
                      if (phone != null) {
                        launchUrl(Uri.parse('sms:$phone'));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
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

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
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
                _buildInfoChip('Sub-category', _complaint?['subCategory'] ?? 'N/A'),
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
                  Icon(Icons.location_on, size: 18, color: AppColors.textSecondary),
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
            if (residentMedia.isNotEmpty) ...[
              const Text(
                'Resident Attachments',
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
              const SizedBox(height: 20),
            ],
            
            // Admin Media
            const Text(
              'Admin Evidence',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (adminMedia.isNotEmpty)
              SizedBox(
                height: 100,
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
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isUploadingMedia ? null : _showMediaUploadDialog,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Evidence'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    child: const Icon(Icons.broken_image, color: AppColors.textLight),
                  );
                },
              )
            else
              Container(
                color: AppColors.background,
                child: const Icon(Icons.videocam, size: 40, color: AppColors.textLight),
              ),
            if (isAdmin && purpose != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            const Text(
              'Add Evidence',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
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

      if (image != null) {
        await _uploadAdminMedia(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadAdminMedia(File file) async {
    setState(() => _isUploadingMedia = true);
    try {
      final response = await ApiService.uploadFile(
        ApiConstants.complaintUploadAdminMedia(widget.complaintId),
        file,
        fieldName: 'media',
        additionalFields: {
          'purpose': 'evidence', // Can be: inspection, resolution, evidence, other
          'description': '', // Optional description
        },
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Evidence uploaded successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          await _loadComplaintDetails();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Upload failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading: $e'),
            backgroundColor: AppColors.error,
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
            DropdownButtonFormField<String>(
              value: status,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
              items: ['Open', 'Assigned', 'In Progress', 'Resolved', 'Closed']
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Icon(
                              _getStatusIcon(s),
                              size: 18,
                              color: _getStatusColor(s),
                            ),
                            const SizedBox(width: 8),
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
            if (_isUpdatingStatus)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(),
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
            DropdownButtonFormField<String>(
              value: _complaint?['priority'] ?? 'Medium',
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
              items: ['Low', 'Medium', 'High', 'Emergency']
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p),
                      ))
                  .toList(),
              onChanged: (newPriority) {
                if (newPriority != null) {
                  _updatePriority(newPriority);
                }
              },
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
              DropdownButtonFormField<String>(
                value: assignedTo?['staff']?['_id']?.toString() ?? 
                       assignedTo?['staff']?.toString(),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  hintText: 'Select staff member',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  ..._staffList!.map((staff) {
                    final staffId = staff['_id']?.toString() ?? '';
                    final userName = staff['user']?['fullName'] ?? 'Unknown';
                    final specialization = staff['specialization'] ?? '';
                    return DropdownMenuItem<String>(
                      value: staffId,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName),
                          if (specialization.isNotEmpty)
                            Text(
                              specialization,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
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
                    // Unassign
                    _assignStaff('');
                  }
                },
              )
            else
              const Text(
                'No staff available',
                style: TextStyle(color: AppColors.textLight),
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
                            assignedTo['staff']?['user']?['fullName'] ?? 'Unknown',
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

  Widget _buildInternalNotesCard() {
    final notes = List<Map<String, dynamic>>.from(_complaint?['internalNotes'] ?? []);

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
                const Icon(Icons.lock, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text(
                  'Internal Admin Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Private',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Notes List
            if (notes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No internal notes yet',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...notes.map((note) => _buildNoteItem(note)),
            
            const SizedBox(height: 16),
            
            // Add Note Field
            TextField(
              controller: _internalNoteController,
              decoration: InputDecoration(
                hintText: 'Add internal note (not visible to residents)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAddingNote ? null : _addInternalNote,
                icon: const Icon(Icons.note_add),
                label: const Text('Add Note'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem(Map<String, dynamic> note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note['note'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person, size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(
                note['addedBy']?['fullName'] ?? 'Admin',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.access_time, size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(note['addedAt']),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
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
      // Ensure comment data is properly converted to Map<String, dynamic>
      final commentData = comment is Map
          ? Map<String, dynamic>.from(comment)
          : <String, dynamic>{};
      
      // Ensure postedBy is properly converted
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
                    Icon(Icons.access_time, size: 14, color: AppColors.textLight),
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
    final postedByRaw = data['postedBy'];
    final postedBy = postedByRaw is Map
        ? Map<String, dynamic>.from(postedByRaw)
        : null;
    final media = List<Map<String, dynamic>>.from(data['media'] ?? []);

    // Extract profile picture URL once
    final profilePicUrl = postedBy != null ? _getProfilePictureUrl(postedBy) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: profilePicUrl != null
                ? NetworkImage(profilePicUrl)
                : null,
            onBackgroundImageError: (exception, stackTrace) {
              print('❌ [FLUTTER] Failed to load profile picture: $exception');
            },
            child: profilePicUrl == null
                ? Text(
                    (postedBy?['fullName']?[0] ?? 'U').toUpperCase(),
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
              children: [
                Text(
                  postedBy?['fullName'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
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
                        return _buildMediaThumbnail(
                          media[index]['url'] ?? '',
                          media[index]['type'] ?? 'image',
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _formatDateTime(timestamp),
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
    );
  }

  Widget _buildCommentInputSection() {
    final status = _complaint?['status'] ?? 'Open';
    if (status == 'Closed' || status == 'Cancelled') {
      return const SizedBox.shrink();
    }

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
                Icon(Icons.comment, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Add Comment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Type your comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
              maxLines: 4,
            ),
            if (_selectedCommentMedia.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedCommentMedia.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedCommentMedia[index],
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
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library, color: AppColors.primary),
                  onPressed: _pickCommentMedia,
                  tooltip: 'Add Photo',
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isPostingComment ? null : _postComment,
                  icon: _isPostingComment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Post Comment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedCommentMedia.add(File(image.path));
        });
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
          const SnackBar(content: Text('Please enter a comment or add media')),
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
            // TODO: Replace with generic upload endpoint
            // Upload to generic media endpoint
            final uploadResponse = await ApiService.uploadFile(
              '/upload/media',
              file,
              fieldName: 'image',
            );
            if (uploadResponse['success'] == true) {
              // Extract media data from response
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
          'text': text.isEmpty ? ' ' : text, // Backend requires text, use space if empty
          if (mediaList != null && mediaList.isNotEmpty)
            'media': mediaList.map((m) => m.toJson()).toList(),
        },
      );

      if (response['success'] == true) {
        _commentController.clear();
        setState(() {
          _selectedCommentMedia.clear();
        });
        _loadComplaintDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment posted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to post comment'),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [FLUTTER] Error posting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: ${e.toString()}')),
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
                  Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
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
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    final status = _complaint?['status'] ?? 'Open';
    if (status == 'Closed' || status == 'Cancelled') return null;

    return FloatingActionButton.extended(
      onPressed: () => _showQuickActions(),
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Quick Actions',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  void _showQuickActions() {
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
            ListTile(
              leading: const Icon(Icons.note_add, color: AppColors.primary),
              title: const Text('Add Internal Note'),
              onTap: () {
                Navigator.pop(context);
                // Focus on note field
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate, color: AppColors.primary),
              title: const Text('Add Evidence'),
              onTap: () {
                Navigator.pop(context);
                _showMediaUploadDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: AppColors.primary),
              title: const Text('Assign Staff'),
              onTap: () {
                Navigator.pop(context);
                // Scroll to assignment section
              },
            ),
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
    try {
      final response = await ApiService.post(
        ApiConstants.complaintInternalNotes(widget.complaintId),
        {'note': note},
      );

      if (response['success'] == true) {
        _internalNoteController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Internal note added'),
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
}
