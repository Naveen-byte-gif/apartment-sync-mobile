import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/chat_data.dart';
import '../../../data/models/user_data.dart';
import '../../../core/services/chat_service.dart';
import '../../widgets/chat_empty_state_widget.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class CommunityChatScreen extends StatefulWidget {
  final String? buildingCode;
  final bool isAdmin;

  const CommunityChatScreen({
    super.key,
    this.buildingCode,
    this.isAdmin = false,
  });

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
  final FocusNode _focusNode = FocusNode();
  // Message deduplication - track seen message IDs
  final Set<String> _seenMessageIds = {};
  // Track last read message timestamp
  DateTime? _lastReadTimestamp;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {}); // Update UI when text changes for send button state
    });
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
          // Use building code if admin, otherwise use user's apartment code
          _apartmentName = widget.isAdmin && widget.buildingCode != null
              ? widget.buildingCode!
              : (user.apartmentCode ?? 'Community');
        });
      }

      final chat = await ChatService.getCommunityChat(
        buildingCode: widget.buildingCode,
        isAdmin: widget.isAdmin,
      );
      
      // Initialize seen message IDs to prevent duplicates
      _seenMessageIds.clear();
      for (final message in chat.messages) {
        _seenMessageIds.add(message.messageId);
      }
      
      // Mark all messages as read when chat loads
      _lastReadTimestamp = DateTime.now();
      
      setState(() {
        _chat = chat;
        _onlineCount = chat.onlineCount;
        _isLoading = false;
        _hasError = false;
        _errorMessage = null;
        // Update apartment name from chat
        _apartmentName = chat.apartmentCode;
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
        
        // Prevent duplicate messages - check if message ID already exists
        if (!_seenMessageIds.contains(message.messageId)) {
          _seenMessageIds.add(message.messageId);
          setState(() {
            _chat?.messages.add(message);
          });
          _scrollToBottom();
          
          // Mark as read if user is viewing the chat
          _lastReadTimestamp = DateTime.now();
        }
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
      // Clear input immediately for better UX
      _messageController.clear();
      
      await ChatService.sendCommunityMessage(messageText: text);
      _scrollToBottom();
    } catch (e) {
      print('❌ [FLUTTER] Error sending message: $e');
      // Restore message text on error
      _messageController.text = text;
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
    if (_chat == null || _isSending) return;
    
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Compress for faster upload
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image == null) return;

      setState(() => _isSending = true);
      final file = File(image.path);
      
      // Show loading indicator
      if (mounted) {
        AppMessageHandler.showInfo(context, 'Uploading image...');
      }
      
      final uploadResult = await ChatService.uploadChatImage(file);
      
      // Prevent duplicate if message already exists
      if (uploadResult['url'] != null) {
        await ChatService.sendCommunityMessage(
          messageText: '',
          mediaUrl: uploadResult['url'],
          messageType: 'image',
        );
        _scrollToBottom();
      }
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

  bool _shouldShowDateSeparator(DateTime previous, DateTime current) {
    return previous.year != current.year ||
        previous.month != current.month ||
        previous.day != current.day;
  }

  Widget _buildDateSeparator(DateTime date) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    
    String dateText;
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    
    if (isToday) {
      dateText = 'Today';
    } else if (isYesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMM d, yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[300]!.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        dateText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
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
          // Header - WhatsApp-like design
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(
                      Icons.group,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _apartmentName ?? 'Community',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '$_onlineCount online',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),

          // Messages or Empty State - WhatsApp-like background
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
              ),
              child: hasMessages
                  ? ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: visibleMessages.length,
                      itemBuilder: (context, index) {
                        final message = visibleMessages[index];
                        // Show date separator if needed
                        final showDateSeparator = index == 0 ||
                            _shouldShowDateSeparator(
                              visibleMessages[index - 1].createdAt,
                              message.createdAt,
                            );
                        return Column(
                          children: [
                            if (showDateSeparator)
                              _buildDateSeparator(message.createdAt),
                            _buildMessageBubble(message),
                          ],
                        );
                      },
                    )
                  : ChatEmptyStateWidget(
                      type: ChatEmptyStateType.community,
                      customTitle: 'No Messages Yet',
                      customDescription:
                          'Be the first to start the conversation! Share updates, ask questions, or connect with your community.',
                    ),
            ),
          ),

          // Input Area - Clean WhatsApp-like design
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
              top: false,
              child: Row(
                children: [
                  // Image Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.image_outlined,
                        color: _isSending ? Colors.grey[400] : AppColors.primary,
                        size: 22,
                      ),
                      onPressed: _isSending ? null : _sendImage,
                      tooltip: 'Send image',
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Text Input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 15),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send Button
                  Container(
                    decoration: BoxDecoration(
                      color: _messageController.text.trim().isNotEmpty && !_isSending
                          ? AppColors.primary
                          : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                      onPressed: (_messageController.text.trim().isNotEmpty && !_isSending)
                          ? _sendMessage
                          : null,
                      tooltip: 'Send message',
                    ),
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
    final isRead = _lastReadTimestamp != null && 
                   message.createdAt.isBefore(_lastReadTimestamp!);

    return Container(
      margin: EdgeInsets.only(
        bottom: 8,
        top: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: roleColor,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.senderName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: roleColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                message.senderRole == 'admin'
                                    ? Icons.shield
                                    : message.senderRole == 'staff'
                                    ? Icons.work
                                    : Icons.person,
                                size: 10,
                                color: roleColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                message.senderRole.toUpperCase(),
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (message.isPinned) ...[
                  Padding(
                    padding: EdgeInsets.only(
                      left: isMe ? 0 : 4,
                      right: isMe ? 4 : 0,
                      bottom: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.push_pin,
                          size: 12,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pinned',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: message.messageType == 'image' ? 4 : 12,
                    vertical: message.messageType == 'image' ? 4 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? (message.isEmergency
                            ? Colors.red[400]
                            : AppColors.primary)
                        : (message.isEmergency
                            ? Colors.red[50]
                            : message.senderRole == 'admin'
                            ? Colors.purple[50]
                            : Colors.grey[100]),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.messageText.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            message.messageText,
                            style: TextStyle(
                              fontSize: 15,
                              color: isMe
                                  ? Colors.white
                                  : (message.isEmergency
                                      ? Colors.red[900]
                                      : Colors.black87),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      if (message.mediaUrl != null) ...[
                        if (message.messageText.isNotEmpty)
                          const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: message.mediaUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => Container(
                              width: 250,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isMe ? Colors.white70 : AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 250,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    color: Colors.grey[400],
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (message.messageText.isNotEmpty || message.mediaUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('h:mm a').format(message.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMe
                                      ? Colors.white70
                                      : Colors.grey[600],
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  isRead ? Icons.done_all : Icons.done,
                                  size: 14,
                                  color: isRead
                                      ? Colors.blue[300]
                                      : Colors.white70,
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (message.reactions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(
                      left: isMe ? 0 : 4,
                      right: isMe ? 4 : 0,
                    ),
                    child: Wrap(
                      spacing: 6,
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
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
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
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
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: roleColor,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
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
