import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_room.dart';
import '../../../data/models/chat_user.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import 'private_chat_screen.dart';
import 'community_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showUsersList = true; // Show users list by default
  List<ChatUser> _users = [];
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
      context.read<ChatProvider>().loadChats();
    });
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
      // Admin can see all residents - pass null to get all users from admin's buildings
      apartmentCode = null;
    } else {
      // Residents/Staff: only same apartment
      apartmentCode = currentUser.apartmentCode;
    }
    
    try {
      final users = await chatProvider.getUsersForChat(
        apartmentCode: apartmentCode,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      
      if (mounted) {
        setState(() {
          _users = users;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      print('Error loading users: $e');
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  Widget _buildAvatar(ChatRoom chat) {
    if (chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(chat.avatarUrl!),
        radius: 28,
      );
    }
    
    // Default avatar with initials or icon
    return CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      child: Text(
        chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
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
        // Create or get personal chat with this user
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
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: user.profilePicture != null && user.profilePicture!.isNotEmpty
                      ? NetworkImage(user.profilePicture!)
                      : null,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: user.profilePicture == null || user.profilePicture!.isEmpty
                      ? Text(
                          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                          style: TextStyle(
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
                        border: Border.all(color: Colors.white, width: 2),
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
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textLight,
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

    return InkWell(
      onTap: () {
        if (chat.isPersonal) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrivateChatScreen(chatId: chat.id, chatName: chat.name),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityChatScreen(chatId: chat.id, chatName: chat.name),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            _buildAvatar(chat),
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
                  Text(
                    previewText,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (chat.unread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Q Search',
                    hintStyle: TextStyle(color: AppColors.textLight),
                    prefixIcon: Icon(Icons.search, color: AppColors.textLight, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    // Trigger search
                    _loadUsers();
                    context.read<ChatProvider>().loadChats();
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
              onPressed: () {
                // Handle notifications
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ALL RESIDENTS and BUILDING OWNER',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Person To Person CHAT',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Tabs for Users and Chats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _showUsersList = true);
                      _loadUsers();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _showUsersList ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'ALL RESIDENTS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _showUsersList ? FontWeight.w600 : FontWeight.normal,
                          color: _showUsersList ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _showUsersList = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: !_showUsersList ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'CHATS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: !_showUsersList ? FontWeight.w600 : FontWeight.normal,
                          color: !_showUsersList ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content - Users List or Chats List
          Expanded(
            child: _showUsersList ? _buildUsersList() : _buildChatsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_isLoadingUsers) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No users found'
                  : 'No users available',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadUsers,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          return _buildUserItem(_users[index]);
        },
      ),
    );
  }

  Widget _buildChatsList() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.isLoading && chatProvider.chats.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: AppColors.textLight,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No chats found'
                      : 'No chats yet',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => chatProvider.loadChats(),
          child: ListView.builder(
            itemCount: filteredChats.length,
            itemBuilder: (context, index) {
              return _buildChatItem(filteredChats[index]);
            },
          ),
        );
      },
    );
  }
}

