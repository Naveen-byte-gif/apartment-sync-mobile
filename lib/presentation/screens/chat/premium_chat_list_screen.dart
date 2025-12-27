import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_room.dart';
import '../../../data/models/chat_user.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import 'private_chat_screen.dart';
import 'community_chat_screen.dart';

class PremiumChatListScreen extends StatefulWidget {
  const PremiumChatListScreen({super.key});

  @override
  State<PremiumChatListScreen> createState() => _PremiumChatListScreenState();
}

class _PremiumChatListScreenState extends State<PremiumChatListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  
  String _searchQuery = '';
  String _selectedRoleFilter = 'all'; // all, resident, staff, admin
  String? _selectedFlatFilter;
  bool _isRefreshing = false;
  
  List<ChatUser> _users = [];
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
      context.read<ChatProvider>().loadChats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    
    setState(() => _isLoadingUsers = true);
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    
    if (currentUser == null) {
      setState(() => _isLoadingUsers = false);
      return;
    }
    
    String? apartmentCode;
    if (currentUser.role == 'admin') {
      apartmentCode = null; // Admin can see all
    } else {
      apartmentCode = currentUser.apartmentCode;
    }
    
    try {
      final users = await chatProvider.getUsersForChat(
        apartmentCode: apartmentCode,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      
      // Apply role filter
      var filteredUsers = users;
      if (_selectedRoleFilter != 'all') {
        filteredUsers = users.where((u) => u.role == _selectedRoleFilter).toList();
      }
      
      // Apply flat filter
      if (_selectedFlatFilter != null && _selectedFlatFilter!.isNotEmpty) {
        filteredUsers = filteredUsers.where((u) => 
          u.flatNumber?.toLowerCase().contains(_selectedFlatFilter!.toLowerCase()) ?? false
        ).toList();
      }
      
      if (mounted) {
        setState(() {
          _users = filteredUsers;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      print('Error loading users: $e');
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.wait([
      _loadUsers(),
      context.read<ChatProvider>().loadChats(),
    ]);
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  PreferredSizeWidget _buildPremiumAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: const Text(
        'Chat',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        // Notification bell
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
              onPressed: () {
                // Handle priority alerts
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Priority alerts feature coming soon')),
                );
              },
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        // Quick action (+) button
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
          onPressed: () {
            _showNewChatOptions();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _showNewChatOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add, color: AppColors.primary),
              title: const Text('New Chat'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to user selection
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign, color: AppColors.warning),
              title: const Text('New Announcement'),
              onTap: () {
                Navigator.pop(context);
                // Handle announcement
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name, role, or flat...',
          hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppColors.textLight, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  color: AppColors.textLight,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _loadUsers();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _loadUsers();
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip('All Roles', 'all', _selectedRoleFilter == 'all'),
          _buildFilterChip('Residents', 'resident', _selectedRoleFilter == 'resident'),
          _buildFilterChip('Staff', 'staff', _selectedRoleFilter == 'staff'),
          if (currentUser?.role == 'admin')
            _buildFilterChip('Admins', 'admin', _selectedRoleFilter == 'admin'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedRoleFilter = value);
          _loadUsers();
        },
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildUserItem(ChatUser user) {
    final isOnline = user.isOnline;
    final lastSeen = user.lastSeen;
    String statusText = '';
    
    if (isOnline) {
      statusText = 'Online';
    } else if (lastSeen != null) {
      final now = DateTime.now();
      final difference = now.difference(lastSeen);
      if (difference.inMinutes < 1) {
        statusText = 'Just now';
      } else if (difference.inMinutes < 60) {
        statusText = '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        statusText = '${difference.inHours}h ago';
      } else {
        statusText = DateFormat('MMM d').format(lastSeen);
      }
    } else {
      statusText = 'Offline';
    }

    return InkWell(
      onTap: () async {
        final chatProvider = context.read<ChatProvider>();
        final chat = await chatProvider.getOrCreatePersonalChat(user.id);
        
        if (chat != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrivateChatScreen(
                chatId: chat.id,
                chatName: user.fullName,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: AppColors.divider.withOpacity(0.5), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: user.profilePicture != null && user.profilePicture!.isNotEmpty
                      ? CachedNetworkImageProvider(user.profilePicture!)
                      : null,
                  child: user.profilePicture == null || user.profilePicture!.isEmpty
                      ? Text(
                          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
              ],
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
                          user.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: user.role == 'admin'
                              ? AppColors.error.withOpacity(0.1)
                              : user.role == 'staff'
                                  ? AppColors.warning.withOpacity(0.1)
                                  : AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user.roleLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: user.role == 'admin'
                                ? AppColors.error
                                : user.role == 'staff'
                                    ? AppColors.warning
                                    : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline ? AppColors.success : AppColors.textLight,
                          fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (user.flatNumber != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${user.flatNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (user.floorNumber != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          'Floor ${user.floorNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(ChatRoom chat) {
    final lastMessage = chat.lastMessagePreview;
    final previewText = lastMessage?.text ?? 'No messages yet';
    final timestamp = _formatTimestamp(chat.lastMessageAt);
    final unreadCount = chat.unread ? 1 : 0; // You can enhance this with actual count

    return InkWell(
      onTap: () {
        if (chat.isPersonal) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrivateChatScreen(
                chatId: chat.id,
                chatName: chat.name,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityChatScreen(
                chatId: chat.id,
                chatName: chat.name,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: AppColors.divider.withOpacity(0.5), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(chat.avatarUrl!)
                      : null,
                  child: chat.avatarUrl == null || chat.avatarUrl!.isEmpty
                      ? Text(
                          chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                // Mute indicator
                if (chat.participants?.any((p) => p.isMuted) ?? false)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volume_off,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
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
                          chat.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timestamp.isNotEmpty)
                        Text(
                          timestamp,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          previewText,
                          style: TextStyle(
                            fontSize: 14,
                            color: unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh or start a new conversation',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllResidentsTab() {
    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty ? 'No users found' : 'No users available',
        Icons.people_outline,
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _users.length,
        itemBuilder: (context, index) => _buildUserItem(_users[index]),
      ),
    );
  }

  Widget _buildChatsTab() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.isLoading && chatProvider.chats.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (chatProvider.error != null && chatProvider.chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  chatProvider.error!,
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    chatProvider.clearError();
                    chatProvider.loadChats();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        var filteredChats = chatProvider.chats;
        
        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          filteredChats = filteredChats.where((chat) {
            return chat.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (chat.lastMessagePreview?.text ?? '')
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());
          }).toList();
        }

        if (filteredChats.isEmpty) {
          return _buildEmptyState(
            _searchQuery.isNotEmpty ? 'No chats found' : 'No chats yet',
            Icons.chat_bubble_outline,
          );
        }

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView.builder(
            itemCount: filteredChats.length,
            itemBuilder: (context, index) => _buildChatItem(filteredChats[index]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildPremiumAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'All Residents'),
              Tab(text: 'Chats'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllResidentsTab(),
                _buildChatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

