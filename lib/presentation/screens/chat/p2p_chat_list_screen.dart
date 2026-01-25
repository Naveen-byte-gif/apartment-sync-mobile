import 'package:intl/intl.dart';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/chat_data.dart';
import '../../../data/models/user_data.dart';
import '../../../core/services/chat_service.dart';
import '../../widgets/chat_empty_state_widget.dart';
import 'dart:convert';
import 'p2p_chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class P2PChatListScreen extends StatefulWidget {
  final String? buildingCode;
  final bool isAdmin;

  const P2PChatListScreen({
    super.key,
    this.buildingCode,
    this.isAdmin = false,
  });

  @override
  State<P2PChatListScreen> createState() => _P2PChatListScreenState();
}

class _P2PChatListScreenState extends State<P2PChatListScreen> {
  List<P2PChat> _chats = [];
  List<UserData> _chatableUsers = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserRole;
  String _searchQuery = '';
  int _selectedTab = 0; // 0: Chats, 1: Contacts

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadChats();
    _loadChatableUsers();
    _setupSocketListeners();
  }

  void _loadUser() {
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      final user = UserData.fromJson(jsonDecode(userJson));
      setState(() {
        _currentUserId = user.id;
        _currentUserRole = user.role;
      });
    }
  }

  Future<void> _loadChats({bool showLoading = false}) async {
    if (showLoading && _chats.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      final chats = await ChatService.getP2PChats(
        buildingCode: widget.buildingCode,
        isAdmin: widget.isAdmin,
      );
      setState(() {
        _chats = chats;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ [FLUTTER] Error loading chats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChatableUsers() async {
    try {
      final users = await ChatService.getChatableUsers(
        buildingCode: widget.buildingCode,
        isAdmin: widget.isAdmin,
      );
      setState(() {
        _chatableUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading chatable users: $e');
      if (_chats.isEmpty) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupSocketListeners() {
    final socketService = SocketService();
    
    // Listen for new P2P messages to update unread counts in real-time
    socketService.on('p2p_message_received', (data) {
      if (mounted) {
        // Only refresh if we're on the chats tab (index 0)
        if (_selectedTab == 0) {
          _loadChats(); // Refresh to update unread counts
        }
      }
    });

    // Listen for sent messages to update last message
    socketService.on('p2p_message_sent', (data) {
      if (mounted) {
        // Only refresh if we're on the chats tab (index 0)
        if (_selectedTab == 0) {
          _loadChats(); // Refresh to update last message and unread counts
        }
      }
    });
  }

  String _getInitials(String name) {
    return name.split(' ').map((n) => n[0]).take(2).join().toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.orange,
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.red,
    ];
    return colors[name.hashCode % colors.length];
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'staff':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'ADMIN';
      case 'staff':
        return 'STAFF';
      default:
        return 'RESIDENT';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    0,
                    'My Chats',
                    _chats.fold<int>(
                      0,
                      (sum, chat) {
                        final count = chat.getUnreadCount(_currentUserId?.toString().trim() ?? '');
                        return sum + (count > 0 ? count : 0);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: _buildTabButton(1, 'Contacts', _chatableUsers.length),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search ${_selectedTab == 0 ? 'conversations' : 'contacts'}...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Content
          Expanded(
            child: _selectedTab == 0 ? _buildChatsList() : _buildContactsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, int count) {
    final isSelected = _selectedTab == index;
    final isUnreadCount = index == 0; // Only show unread badge for "My Chats"
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _searchQuery = '';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : Colors.grey[600],
                fontSize: 16,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isUnreadCount ? 8 : 6,
                  vertical: isUnreadCount ? 4 : 2,
                ),
                decoration: BoxDecoration(
                  color: isUnreadCount ? AppColors.primary : Colors.grey[400],
                  borderRadius: BorderRadius.circular(isUnreadCount ? 12 : 10),
                ),
                constraints: isUnreadCount
                    ? const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      )
                    : null,
                child: Center(
                  child: Text(
                    isUnreadCount && count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chats.isEmpty) {
      return ChatEmptyStateWidget(
        type: ChatEmptyStateType.p2p,
        customDescription: 'Start a conversation from the Contacts tab. Your chats will appear here.',
      );
    }

    // Sort chats by last message time (most recent first)
    final sortedChats = List<P2PChat>.from(_chats);
    sortedChats.sort((a, b) {
      final aTime = a.lastMessage?.sentAt ?? a.updatedAt;
      final bTime = b.lastMessage?.sentAt ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });

    return RefreshIndicator(
      onRefresh: _loadChats,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: sortedChats.length,
        itemBuilder: (context, index) {
          final chat = sortedChats[index];
          final otherParticipant = chat.participants
              .firstWhere((p) => p.userId != _currentUserId,
                  orElse: () => chat.participants.first);
          
          // Filter by search query
          if (_searchQuery.isNotEmpty) {
            final name = otherParticipant.fullName ?? '';
            if (!name.toLowerCase().contains(_searchQuery)) {
              return const SizedBox.shrink();
            }
          }

          // Get unread count for current user
          // Ensure we use the correct userId format - normalize to handle ObjectId strings
          final currentUserIdString = _currentUserId?.toString().trim() ?? '';
          final unreadCount = chat.getUnreadCount(currentUserIdString);
          final lastMessage = chat.lastMessage;
          // Ensure unread count is always non-negative and valid
          final displayUnreadCount = unreadCount < 0 ? 0 : unreadCount;
          final hasUnread = displayUnreadCount > 0;

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => P2PChatScreen(
                    chatId: chat.id,
                    receiverId: otherParticipant.userId,
                    receiverName: otherParticipant.fullName ?? 'Unknown',
                    receiverRole: otherParticipant.role,
                    receiverProfilePicture: otherParticipant.profilePicture,
                  ),
                  fullscreenDialog: true,
                ),
              ).then((_) => _loadChats());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: hasUnread ? Colors.orange[50]?.withOpacity(0.3) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[200]!,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Avatar with unread indicator
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: _getAvatarColor(otherParticipant.fullName ?? ''),
                        backgroundImage: otherParticipant.profilePicture != null
                            ? CachedNetworkImageProvider(otherParticipant.profilePicture!)
                            : null,
                        child: otherParticipant.profilePicture == null
                            ? Text(
                                _getInitials(otherParticipant.fullName ?? 'Unknown'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      if (hasUnread)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: displayUnreadCount > 9 ? 6 : 5,
                              vertical: 3,
                            ),
                            constraints: BoxConstraints(
                              minWidth: displayUnreadCount > 99 ? 28 : (displayUnreadCount > 9 ? 22 : 20),
                              minHeight: 20,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: displayUnreadCount > 99 
                                  ? BoxShape.rectangle 
                                  : BoxShape.circle,
                              borderRadius: displayUnreadCount > 99 
                                  ? BorderRadius.circular(12) 
                                  : null,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                displayUnreadCount > 99 ? '99+' : '$displayUnreadCount',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: displayUnreadCount > 99 ? 9 : (displayUnreadCount > 9 ? 10 : 11),
                                  fontWeight: FontWeight.bold,
                                  height: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Name and message preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                otherParticipant.fullName ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                  fontSize: 16,
                                  color: hasUnread ? Colors.black87 : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (otherParticipant.role == 'admin' || otherParticipant.role == 'staff')
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(otherParticipant.role),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getRoleLabel(otherParticipant.role),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            // Time
                            if (lastMessage != null)
                              Text(
                                _formatTime(lastMessage.sentAt),
                                style: TextStyle(
                                  color: hasUnread ? AppColors.primary : Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getLastMessagePreview(lastMessage),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: hasUnread ? Colors.black87 : Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Trailing unread count badge (for better visibility)
                  if (hasUnread) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: displayUnreadCount > 9 ? 8 : 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: BoxConstraints(
                        minWidth: displayUnreadCount > 99 ? 32 : (displayUnreadCount > 9 ? 28 : 24),
                        minHeight: 24,
                      ),
                      child: Center(
                        child: Text(
                          displayUnreadCount > 99 ? '99+' : '$displayUnreadCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: displayUnreadCount > 99 ? 11 : 12,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return DateFormat('h:mm a').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(messageDate).inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  String _getLastMessagePreview(P2PMessage? message) {
    if (message == null) return 'No messages yet';
    if (message.messageType == 'image') {
      return '📷 Image';
    } else if (message.message.isNotEmpty) {
      return message.message;
    }
    return 'Media';
  }

  Widget _buildContactsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Group users by role
    final residents = _chatableUsers.where((u) => u.role == 'resident').toList();
    final staff = _chatableUsers.where((u) => u.role == 'staff').toList();
    final admins = _chatableUsers.where((u) => u.role == 'admin').toList();

    // Filter by search
    final filteredResidents = residents.where((u) {
      if (_searchQuery.isEmpty) return true;
      return u.fullName.toLowerCase().contains(_searchQuery) ||
          (u.flatNumber?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();

    final filteredStaff = staff.where((u) {
      if (_searchQuery.isEmpty) return true;
      return u.fullName.toLowerCase().contains(_searchQuery);
    }).toList();

    final filteredAdmins = admins.where((u) {
      if (_searchQuery.isEmpty) return true;
      return u.fullName.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredResidents.isEmpty && filteredStaff.isEmpty && filteredAdmins.isEmpty) {
      return ChatEmptyStateWidget(
        type: ChatEmptyStateType.p2p,
        customTitle: 'No Contacts Found',
        customDescription: _searchQuery.isNotEmpty
            ? 'No contacts match your search "$_searchQuery"'
            : 'No contacts available',
      );
    }

    return ListView(
      children: [
        if (filteredAdmins.isNotEmpty) ...[
          _buildSectionHeader('Admin'),
          ...filteredAdmins.map((user) => _buildContactItem(user)),
        ],
        if (filteredStaff.isNotEmpty) ...[
          _buildSectionHeader('Staff'),
          ...filteredStaff.map((user) => _buildContactItem(user)),
        ],
        if (filteredResidents.isNotEmpty) ...[
          _buildSectionHeader('Residents'),
          ...filteredResidents.map((user) => _buildContactItem(user)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildContactItem(UserData user) {
    // Check if chat already exists
    final existingChat = _chats.firstWhere(
      (chat) => chat.participants.any((p) => p.userId == user.id),
      orElse: () => _chats.isNotEmpty ? _chats.first : P2PChat(
        id: '',
        participants: [],
        apartmentCode: '',
        messages: [],
        unreadCount: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final hasExistingChat = existingChat.id.isNotEmpty;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: _getAvatarColor(user.fullName),
            backgroundImage: user.profilePicture != null
                ? CachedNetworkImageProvider(user.profilePicture!)
                : null,
            child: user.profilePicture == null
                ? Text(
                    _getInitials(user.fullName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          if (user.isOnline == true)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              user.fullName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getRoleColor(user.role),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getRoleLabel(user.role),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.flatNumber != null)
            Text(
              '${user.wing ?? ''}-${user.flatNumber}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          if (user.isOnline == true)
            const Text(
              'Online',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
              ),
            )
          else if (user.lastSeen != null)
            Text(
              'Last seen ${DateFormat('h:mm a').format(user.lastSeen!)}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
        ],
      ),
      trailing: hasExistingChat
          ? const Icon(Icons.chat_bubble, color: Colors.orange)
          : const Icon(Icons.chat_bubble_outline, color: Colors.grey),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => P2PChatScreen(
              chatId: hasExistingChat ? existingChat.id : null,
              receiverId: user.id,
              receiverName: user.fullName,
              receiverRole: user.role,
              receiverProfilePicture: user.profilePicture,
            ),
            fullscreenDialog: true,
          ),
        ).then((_) {
          _loadChats();
          _loadChatableUsers();
        });
      },
    );
  }
}
