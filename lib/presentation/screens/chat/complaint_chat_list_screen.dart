import '../../../core/imports/app_imports.dart';
import '../../../data/models/complaint_data.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../widgets/chat_empty_state_widget.dart';
import 'dart:convert';
import '../complaints/complaint_detail_screen.dart';

class ComplaintChatListScreen extends StatefulWidget {
  const ComplaintChatListScreen({super.key});

  @override
  State<ComplaintChatListScreen> createState() => _ComplaintChatListScreenState();
}

class _ComplaintChatListScreenState extends State<ComplaintChatListScreen> {
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('${ApiConstants.complaints}/my-complaints');
      if (response['success'] == true) {
        final complaints = (response['data']?['complaints'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _complaints = complaints;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading complaints: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_complaints.isEmpty) {
      return ChatEmptyStateWidget(
        type: ChatEmptyStateType.complaints,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadComplaints,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _complaints.length,
        itemBuilder: (context, index) {
          final complaint = _complaints[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(complaint['status']).withOpacity(0.2),
                child: Icon(
                  Icons.warning_rounded,
                  color: _getStatusColor(complaint['status']),
                ),
              ),
              title: Text(
                complaint['title'] ?? 'Untitled Complaint',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    complaint['ticketNumber'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(
                      complaint['status'] ?? 'Open',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: _getStatusColor(complaint['status']).withOpacity(0.2),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ComplaintDetailScreen(
                      complaintId: complaint['_id'] ?? complaint['id'],
                    ),
                  ),
                ).then((_) => _loadComplaints());
              },
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Open':
        return AppColors.statusOpen;
      case 'Assigned':
        return AppColors.statusAssigned;
      case 'In Progress':
        return AppColors.statusInProgress;
      case 'Resolved':
        return AppColors.statusResolved;
      default:
        return Colors.grey;
    }
  }
}

