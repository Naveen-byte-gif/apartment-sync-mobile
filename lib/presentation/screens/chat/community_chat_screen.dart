import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/chat_data.dart';
import '../../../data/models/user_data.dart';
import '../../../core/services/chat_service.dart';
import '../../widgets/chat_empty_state_widget.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class CommunityChatScreen extends StatefulWidget {
  const CommunityChatScreen({super.key});

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  CommunityChat? _chat;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasError = false;
  String? _currentUserId;
  String? _currentUserRole;
  String? _apartmentName;
  int _onlineCount = 0;
  bool _isSending = false;
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadUserAndChat();
    _setupSocketListeners();
  }

  Future<void> _loadUserAndChat({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    }

    try {
      final userJson = StorageService.getString(AppConstants.userKey);
      if (userJson != null) {
        final user = UserData.fromJson(jsonDecode(userJson));
        setState(() {
          _currentUserId = user.id;
          _currentUserRole = user.role;
          _apartmentName = user.apartmentCode ?? 'Community';
        });
      }

      final chat = await ChatService.getCommunityChat();
      setState(() {
        _chat = chat;
        _onlineCount = chat.onlineCount;
        _isLoading = false;
        _hasError = false;
        _errorMessage = null;
      });

      // Join chat room
      final socketService = SocketService();
      socketService.joinChatRoom('community_${chat.apartmentCode}');

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _chat != null) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('❌ [FLUTTER] Error loading chat: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection error. Please check your internet connection.';
    } else if (errorString.contains('timeout')) {
      return 'Request timeout. Please try again.';
    } else if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return 'Authentication error. Please log in again.';
    } else if (errorString.contains('403') || errorString.contains('forbidden')) {
      return 'Access denied. You don\'t have permission to access community chat.';
    } else if (errorString.contains('404') || errorString.contains('not found')) {
      return 'Community chat not found. Please contact support.';
    } else if (errorString.contains('500') || errorString.contains('server')) {
      return 'Server error. Please try again later.';
    } else {
      return 'Failed to load community chat. Please try again.';
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 32),
            
            // Error Title
            Text(
              'Error Loading Chat',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Error Message
            Text(
              _errorMessage ?? 'An unexpected error occurred',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Retry Button
            ElevatedButton.icon(
              onPressed: () => _loadUserAndChat(),
              icon: const Icon(Icons.refresh, size: 24),
              label: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setupSocketListeners() {
    final socketService = SocketService();

    socketService.on('new_community_message', (data) {
      if (mounted && data['message'] != null) {
        final message = ChatMessage.fromJson(data['message']);
        setState(() {
          _chat?.messages.add(message);
        });
        _scrollToBottom();
      }
    });

    socketService.on('message_pinned', (data) {
      if (mounted && _chat != null) {
        final messageId = data['messageId'];
        final isPinned = data['isPinned'] ?? false;
        final index = _chat!.messages.indexWhere(
          (m) => m.messageId == messageId,
        );
        if (index != -1) {
          setState(() {
            _chat!.messages[index] = ChatMessage(
              messageId: _chat!.messages[index].messageId,
              senderId: _chat!.messages[index].senderId,
              senderName: _chat!.messages[index].senderName,
              senderRole: _chat!.messages[index].senderRole,
              messageType: _chat!.messages[index].messageType,
              messageText: _chat!.messages[index].messageText,
              mediaUrl: _chat!.messages[index].mediaUrl,
              reactions: _chat!.messages[index].reactions,
              isEdited: _chat!.messages[index].isEdited,
              isDeleted: _chat!.messages[index].isDeleted,
              isPinned: isPinned,
              isEmergency: _chat!.messages[index].isEmergency,
              emergencyKeywords: _chat!.messages[index].emergencyKeywords,
              createdAt: _chat!.messages[index].createdAt,
              updatedAt: _chat!.messages[index].updatedAt,
            );
          });
        }
      }
    });

    socketService.on('message_reaction', (data) {
      if (mounted && _chat != null) {
        final messageId = data['messageId'];
        final reactions =
            (data['reactions'] as List?)
                ?.map((r) => MessageReaction.fromJson(r))
                .toList() ??
            [];
        final index = _chat!.messages.indexWhere(
          (m) => m.messageId == messageId,
        );
        if (index != -1) {
          setState(() {
            _chat!.messages[index] = ChatMessage(
              messageId: _chat!.messages[index].messageId,
              senderId: _chat!.messages[index].senderId,
              senderName: _chat!.messages[index].senderName,
              senderRole: _chat!.messages[index].senderRole,
              messageType: _chat!.messages[index].messageType,
              messageText: _chat!.messages[index].messageText,
              mediaUrl: _chat!.messages[index].mediaUrl,
              reactions: reactions,
              isEdited: _chat!.messages[index].isEdited,
              isDeleted: _chat!.messages[index].isDeleted,
              isPinned: _chat!.messages[index].isPinned,
              isEmergency: _chat!.messages[index].isEmergency,
              emergencyKeywords: _chat!.messages[index].emergencyKeywords,
              createdAt: _chat!.messages[index].createdAt,
              updatedAt: _chat!.messages[index].updatedAt,
            );
          });
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || _chat == null) return;

    setState(() => _isSending = true);
    try {
      await ChatService.sendCommunityMessage(messageText: text);
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('❌ [FLUTTER] Error sending message: $e');
      if (mounted) {
        AppMessageHandler.showError(
          context,
          'Failed to send message. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendImage() async {
    if (_chat == null) return;
    
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isSending = true);
      final file = File(image.path);
      final uploadResult = await ChatService.uploadChatImage(file);
      await ChatService.sendCommunityMessage(
        messageText: '',
        mediaUrl: uploadResult['url'],
        messageType: 'image',
      );
      _scrollToBottom();
    } catch (e) {
      print('❌ [FLUTTER] Error sending image: $e');
      if (mounted) {
        AppMessageHandler.showError(
          context,
          'Failed to send image. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _addReaction(String messageId, String emoji) async {
    if (_chat == null) return;
    try {
      await ChatService.addReaction(
        messageId: messageId,
        chatId: _chat!.id,
        emoji: emoji,
      );
    } catch (e) {
      print('❌ [FLUTTER] Error adding reaction: $e');
    }
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

  String _getInitials(String name) {
    return name.split(' ').map((n) => n[0]).take(2).join().toUpperCase();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Error State
    if (_hasError) {
      return Scaffold(
        body: _buildErrorState(),
      );
    }

    // No Chat Found
    if (_chat == null) {
      return Scaffold(
        body: ChatEmptyStateWidget(
          type: ChatEmptyStateType.community,
          customTitle: 'Community Chat Not Available',
          customDescription: 'Unable to load community chat. Please try again or contact support.',
          actionText: 'Retry',
          onAction: () => _loadUserAndChat(),
        ),
      );
    }

    // Empty Messages State
    final visibleMessages = _chat!.messages.where((m) => !m.isDeleted).toList();
    final hasMessages = visibleMessages.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.group, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _apartmentName ?? 'Community',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$_onlineCount online',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
            ),
          ),
          const Divider(height: 1),

          // Messages or Empty State
          Expanded(
            child: hasMessages
                ? ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleMessages.length,
                    itemBuilder: (context, index) {
                      final message = visibleMessages[index];
                      return _buildMessageBubble(message);
                    },
                  )
                : ChatEmptyStateWidget(
                    type: ChatEmptyStateType.community,
                    customTitle: 'No Messages Yet',
                    customDescription: 'Be the first to start the conversation! Share updates, ask questions, or connect with your community.',
                  ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.image_outlined),
                    onPressed: _sendImage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Message community...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.senderId == _currentUserId;
    final roleColor = _getRoleColor(message.senderRole);
    final initials = _getInitials(message.senderName);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 20,
              backgroundColor: roleColor,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Row(
                    children: [
                      Text(
                        message.senderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              message.senderRole == 'admin'
                                  ? Icons.shield
                                  : Icons.person,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              message.senderRole.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (message.isPinned) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.push_pin,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pinned',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isEmergency
                        ? Colors.red[50]
                        : (message.isPinned || message.senderRole == 'admin')
                        ? Colors.brown[50]
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: message.isEmergency
                        ? Border.all(color: Colors.red, width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.messageText.isNotEmpty)
                        Text(
                          message.messageText,
                          style: TextStyle(
                            fontSize: 14,
                            color: message.isEmergency
                                ? Colors.red[900]
                                : Colors.black87,
                          ),
                        ),
                      if (message.mediaUrl != null) ...[
                        if (message.messageText.isNotEmpty)
                          const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 250),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: message.mediaUrl!,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (message.reactions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final reaction in message.reactions)
                        GestureDetector(
                          onTap: () =>
                              _addReaction(message.messageId, reaction.emoji),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  reaction.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${message.reactions.where((r) => r.emoji == reaction.emoji).length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(message.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundColor: roleColor,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
