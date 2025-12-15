import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class ResidentNoticesScreen extends StatefulWidget {
  const ResidentNoticesScreen({super.key});

  @override
  State<ResidentNoticesScreen> createState() => _ResidentNoticesScreenState();
}

class _ResidentNoticesScreenState extends State<ResidentNoticesScreen> {
  List<Map<String, dynamic>> _notices = [];
  List<Map<String, dynamic>> _filteredNotices = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotices();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for notices');
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      final user = UserData.fromJson(jsonDecode(userJson));
      socketService.connect(user.id);
      
      socketService.on('new_notice', (data) {
        print('📡 [FLUTTER] New notice event received');
        _loadNotices(); // Refresh notices
      });
    }
  }

  Future<void> _loadNotices() async {
    print('🖱️ [FLUTTER] Loading notices...');
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get(ApiConstants.announcements);
      print('✅ [FLUTTER] Notices response received');
      print('📦 [FLUTTER] Response: ${response.toString()}');

      if (response['success'] == true) {
        final noticesList = response['data']?['notices'] as List?;
        if (noticesList != null) {
          setState(() {
            _notices = noticesList.cast<Map<String, dynamic>>();
            _unreadCount = _notices.where((n) => n['isRead'] == false).length;
            _applyFilters();
          });
          print('✅ [FLUTTER] Loaded ${_notices.length} notices');
        }
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading notices: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notices: ${e.toString()}')),
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
      _filteredNotices = _notices.where((notice) {
        // Category filter
        if (_selectedCategory != 'all' && notice['category'] != _selectedCategory) {
          return false;
        }
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return (notice['title']?.toString().toLowerCase().contains(query) ?? false) ||
              (notice['content']?.toString().toLowerCase().contains(query) ?? false);
        }
        return true;
      }).toList();
    });
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'general':
        return Icons.campaign;
      case 'maintenance':
        return Icons.build;
      case 'security':
        return Icons.security;
      case 'events':
        return Icons.celebration;
      default:
        return Icons.notifications;
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notices'),
            Text(
              '$_unreadCount unread',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              print('🖱️ [FLUTTER] Refresh notices button clicked');
              _loadNotices();
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
                    hintText: 'Search notices...',
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
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedCategory == 'all',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'all';
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'General',
                        isSelected: _selectedCategory == 'General',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'General';
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Maintenance',
                        isSelected: _selectedCategory == 'Maintenance',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Maintenance';
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Security',
                        isSelected: _selectedCategory == 'Security',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Security';
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Events',
                        isSelected: _selectedCategory == 'Events',
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'Events';
                            _applyFilters();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Notices List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No notices found'
                                  : 'No notices yet',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotices,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredNotices.length,
                          itemBuilder: (context, index) {
                            final notice = _filteredNotices[index];
                            final isUnread = notice['isRead'] == false;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: isUnread
                                    ? Border.all(color: AppColors.primary, width: 2)
                                    : Border.all(color: Colors.grey.shade200),
                              ),
                              child: InkWell(
                                onTap: () {
                                  print('🖱️ [FLUTTER] Notice tapped: ${notice['title']}');
                                  _showNoticeDetails(notice);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: _getPriorityColor(notice['priority'])
                                              .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(notice['category']),
                                          color: _getPriorityColor(notice['priority']),
                                        ),
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
                                                    notice['title'] ?? 'No Title',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: isUnread
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isUnread)
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(
                                                      color: AppColors.primary,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            if (notice['category'] != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  notice['category'],
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey.shade700,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 4),
                                            Text(
                                              notice['content'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              notice['createdAt'] != null
                                                  ? DateFormat('MMM d, yyyy')
                                                      .format(DateTime.parse(notice['createdAt']))
                                                  : 'Recently',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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

  void _showNoticeDetails(Map<String, dynamic> notice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notice['title'] ?? 'Notice'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (notice['category'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    notice['category'],
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                notice['content'] ?? 'No content',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                'Published: ${notice['createdAt'] != null ? DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(notice['createdAt'])) : 'Recently'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}



