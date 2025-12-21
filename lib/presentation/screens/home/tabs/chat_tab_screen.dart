import '../../../../core/imports/app_imports.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../../data/models/chat_room.dart';
import '../../../../data/models/chat_user.dart';
import '../../../screens/chat/chat_list_screen.dart';
import '../../../screens/chat/private_chat_screen.dart';
import '../../../screens/chat/community_chat_screen.dart';

class ChatTabScreen extends StatefulWidget {
  const ChatTabScreen({super.key});

  @override
  State<ChatTabScreen> createState() => _ChatTabScreenState();
}

class _ChatTabScreenState extends State<ChatTabScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showUsersList = true;
  List<ChatUser> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    context.read<ChatProvider>().loadChats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final chatProvider = context.read<ChatProvider>();
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.user;
      
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      String? apartmentCode;
      if (currentUser.role == 'admin') {
        apartmentCode = null;
      } else {
        apartmentCode = currentUser.apartmentCode;
      }
      
      final users = await chatProvider.getUsersForChat(
        apartmentCode: apartmentCode,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Navigate directly to ChatListScreen which has full functionality
    return const ChatListScreen();
  }

  Widget _buildOldChatTab() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Search bar (replacing AppBar)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
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
                        _loadUsers();
                        context.read<ChatProvider>().loadChats();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                  onPressed: () {},
                ),
              ],
            ),
          ),
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
          // Tabs
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
                        'Users',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _showUsersList ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: _showUsersList ? FontWeight.w600 : FontWeight.normal,
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
                        'Chats',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_showUsersList ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: !_showUsersList ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _showUsersList ? _buildUsersList() : _buildChatsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredUsers = _users.where((user) {
      if (_searchQuery.isEmpty) return true;
      final name = user.fullName.toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredUsers.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              user.fullName.isNotEmpty
                  ? user.fullName.substring(0, 1).toUpperCase()
                  : 'U',
            ),
          ),
          title: Text(user.fullName),
          subtitle: Text(user.email ?? ''),
          onTap: () async {
            // Navigate to private chat with user
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
        );
      },
    );
  }

  Widget _buildChatsList() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final chats = chatProvider.chats;
        if (chats.isEmpty) {
          return const Center(child: Text('No chats yet'));
        }
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final lastMessage = chat.lastMessagePreview?.text ?? '';
            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  chat.name.isNotEmpty 
                      ? chat.name.substring(0, 1).toUpperCase()
                      : 'C',
                ),
              ),
              title: Text(chat.name),
              subtitle: Text(lastMessage),
              trailing: Text(
                _formatTimestamp(chat.lastMessageAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              onTap: () {
                // Navigate to appropriate chat screen
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
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }
}

