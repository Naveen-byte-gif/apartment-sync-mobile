import '../../../core/imports/app_imports.dart';
import 'private_chat_screen.dart';

class PrivateChatListScreen extends StatefulWidget {
  const PrivateChatListScreen({super.key});

  @override
  State<PrivateChatListScreen> createState() => _PrivateChatListScreenState();
}

class _PrivateChatListScreenState extends State<PrivateChatListScreen> {
  List<Map<String, dynamic>> _privateChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrivateChats();
  }

  Future<void> _loadPrivateChats() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get(ApiConstants.chatPrivate);
      if (response['success'] == true && mounted) {
        setState(() {
          _privateChats = List<Map<String, dynamic>>.from(
            response['data']?['chats'] ?? []
          );
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading private chats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        AppMessageHandler.handleError(context, e);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_privateChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No private chats yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation with a resident',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPrivateChats,
      child: ListView.builder(
        itemCount: _privateChats.length,
        itemBuilder: (context, index) {
          final chat = _privateChats[index];
          final otherParticipant = chat['otherParticipant'] as Map<String, dynamic>?;
          final lastMessage = chat['lastMessage'] as Map<String, dynamic>?;
          final unreadCount = chat['unreadCount'] as int? ?? 0;
          final lastMessageAt = chat['lastMessageAt'] != null
              ? DateTime.parse(chat['lastMessageAt'])
              : null;

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: otherParticipant?['profilePicture']?['url'] != null
                  ? NetworkImage(otherParticipant!['profilePicture']['url'])
                  : null,
              child: otherParticipant?['profilePicture']?['url'] == null
                  ? Text(
                      (otherParticipant?['name'] as String? ?? 'U')
                          .substring(0, 1)
                          .toUpperCase(),
                    )
                  : null,
            ),
            title: Text(
              otherParticipant?['name'] as String? ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    lastMessage?['content'] as String? ?? 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
                if (lastMessageAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatTimestamp(lastMessageAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
            trailing: unreadCount > 0
                ? Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrivateChatScreen(
                    chatId: chat['id'] as String,
                    chatName: otherParticipant?['name'] as String? ?? 'Private Chat',
                    otherParticipant: otherParticipant,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

