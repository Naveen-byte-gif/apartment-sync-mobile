import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/chat_data.dart';
import '../../../data/models/user_data.dart';
import '../../../core/services/chat_service.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class P2PChatScreen extends StatefulWidget {
  final String? chatId;
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final String? receiverProfilePicture;

  const P2PChatScreen({
    super.key,
    this.chatId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverRole,
    this.receiverProfilePicture,
  });

  @override
  State<P2PChatScreen> createState() => _P2PChatScreenState();
}

class _P2PChatScreenState extends State<P2PChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  P2PChat? _chat;
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserRole;
  String? _currentUserName;
  bool _isSending = false;
  bool _isOnline = false;
  final FocusNode _focusNode = FocusNode();
  // Message deduplication
  final Set<String> _seenMessageIds = {};
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

  Future<void> _loadUserAndChat() async {
    try {
      final userJson = StorageService.getString(AppConstants.userKey);
      if (userJson != null) {
        final user = UserData.fromJson(jsonDecode(userJson));
        setState(() {
          _currentUserId = user.id;
          _currentUserRole = user.role;
          _currentUserName = user.fullName;
        });
      }

      final chat = await ChatService.getP2PChat(widget.receiverId);

      // Sort messages by sentAt timestamp to ensure correct order
      final sortedMessages = List<P2PMessage>.from(chat.messages);
      sortedMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

      // Initialize seen message IDs to prevent duplicates
      _seenMessageIds.clear();
      for (final message in sortedMessages) {
        _seenMessageIds.add(message.id);
      }

      // Mark all messages as read when chat loads
      _lastReadTimestamp = DateTime.now();

      setState(() {
        // Create updated chat with sorted messages
        _chat = P2PChat(
          id: chat.id,
          participants: chat.participants,
          apartmentCode: chat.apartmentCode,
          messages: sortedMessages,
          unreadCount: chat.unreadCount,
          createdAt: chat.createdAt,
          updatedAt: chat.updatedAt,
        );
        _isLoading = false;
        // Check if receiver is online
        final receiverParticipant = chat.participants.firstWhere(
          (p) => p.userId == widget.receiverId,
          orElse: () => chat.participants.first,
        );
        // Note: Online status would need to be fetched separately or from socket
      });

      // Mark as read
      await ChatService.markP2PAsRead(chat.id);

      _scrollToBottom();
    } catch (e) {
      print('Error loading chat: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setupSocketListeners() {
    final socketService = SocketService();

    // Listen for received messages (messages from other user)
    socketService.on('p2p_message_received', (data) {
      if (mounted && data['chatId'] == _chat?.id && data['message'] != null) {
        _handleNewMessage(data['message']);
      }
    });

    // Listen for sent messages (messages we sent)
    socketService.on('p2p_message_sent', (data) {
      if (mounted && data['chatId'] == _chat?.id && data['message'] != null) {
        _handleNewMessage(data['message']);
      }
    });
  }

  void _handleNewMessage(Map<String, dynamic> messageData) {
    if (_chat == null) return;

    try {
      final message = P2PMessage.fromJson(messageData);

      // Check if this message already exists (from optimistic update or duplicate)
      final existingIndex = _chat!.messages.indexWhere((m) => m.id == message.id);
      if (existingIndex != -1) {
        // Replace existing message (optimistic update being replaced by real message)
        final updatedMessages = List<P2PMessage>.from(_chat!.messages);
        updatedMessages[existingIndex] = message;
        updatedMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

        setState(() {
          _chat = P2PChat(
            id: _chat!.id,
            participants: _chat!.participants,
            apartmentCode: _chat!.apartmentCode,
            messages: updatedMessages,
            unreadCount: _chat!.unreadCount,
            createdAt: _chat!.createdAt,
            updatedAt: _chat!.updatedAt,
          );
        });

        _seenMessageIds.add(message.id);
      } else if (!_seenMessageIds.contains(message.id)) {
        // New message - add it
        _seenMessageIds.add(message.id);
        
        // Remove any temporary messages with similar content/timestamp (cleanup optimistic updates)
        // Match by sender, content, and timestamp within 5 seconds
        final updatedMessages = _chat!.messages
            .where((m) {
              if (!m.id.startsWith('temp_')) return true;
              
              // Check if this temp message matches the real message (same sender, content/media, similar time)
              final isMatch = m.senderId == message.senderId &&
                  ((m.message == message.message) || (m.mediaUrl != null && m.mediaUrl == message.mediaUrl)) &&
                  m.sentAt.difference(message.sentAt).abs().inSeconds < 5;
              
              // Keep temp messages that don't match (they'll be cleaned up later)
              return !isMatch;
            })
            .toList();
        
        updatedMessages.add(message);
        updatedMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

        setState(() {
          _chat = P2PChat(
            id: _chat!.id,
            participants: _chat!.participants,
            apartmentCode: _chat!.apartmentCode,
            messages: updatedMessages,
            unreadCount: _chat!.unreadCount,
            createdAt: _chat!.createdAt,
            updatedAt: _chat!.updatedAt,
          );
        });
      } else {
        // Message already seen, skip
        return;
      }

      _scrollToBottom();

      // Mark as read if it's a received message (not sent by us)
      if (message.senderId != _currentUserId) {
        ChatService.markP2PAsRead(_chat!.id);
        _lastReadTimestamp = DateTime.now();
      }
    } catch (e) {
      print('❌ [FLUTTER] Error handling new message: $e');
    }
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

    // Clear input immediately for better UX
    _messageController.clear();
    setState(() => _isSending = true);

    // Generate temporary message ID for optimistic update
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${_currentUserId}';
    final now = DateTime.now();

    // Create optimistic message (will be replaced by server response)
    final optimisticMessage = P2PMessage(
      id: tempMessageId,
      senderId: _currentUserId ?? '',
      message: text,
      messageType: 'text',
      seen: false,
      delivered: false,
      sentAt: now,
      isEdited: false,
      isDeleted: false,
    );

    // Add message immediately to UI (optimistic update)
    final updatedMessages = List<P2PMessage>.from(_chat!.messages);
    updatedMessages.add(optimisticMessage);
    updatedMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    
    setState(() {
      _chat = P2PChat(
        id: _chat!.id,
        participants: _chat!.participants,
        apartmentCode: _chat!.apartmentCode,
        messages: updatedMessages,
        unreadCount: _chat!.unreadCount,
        createdAt: _chat!.createdAt,
        updatedAt: _chat!.updatedAt,
      );
    });

    _seenMessageIds.add(tempMessageId);
    _scrollToBottom();

    try {
      // Send message to server
      await ChatService.sendP2PMessage(
        chatId: _chat?.id,
        receiverId: widget.receiverId,
        message: text,
      );

      // Socket will update with real message, which will replace the optimistic one
      // The deduplication logic will handle this
    } catch (e) {
      // Remove optimistic message on error
      if (mounted) {
        final errorMessages = _chat!.messages.where((m) => m.id != tempMessageId).toList();
        errorMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
        
        setState(() {
          _chat = P2PChat(
            id: _chat!.id,
            participants: _chat!.participants,
            apartmentCode: _chat!.apartmentCode,
            messages: errorMessages,
            unreadCount: _chat!.unreadCount,
            createdAt: _chat!.createdAt,
            updatedAt: _chat!.updatedAt,
          );
        });

        // Restore message text on error
        _messageController.text = text;
        _seenMessageIds.remove(tempMessageId);

        print('❌ [FLUTTER] Error sending message: $e');
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
    if (_isSending || _chat == null) return;

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image == null) return;

      setState(() => _isSending = true);

      // Show loading indicator
      if (mounted) {
        AppMessageHandler.showInfo(context, 'Uploading image...');
      }

      final file = File(image.path);
      final uploadResult = await ChatService.uploadChatImage(file);

      if (uploadResult['url'] != null) {
        // Generate temporary message ID for optimistic update
        final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${_currentUserId}';
        final now = DateTime.now();

        // Create optimistic message
        final optimisticMessage = P2PMessage(
          id: tempMessageId,
          senderId: _currentUserId ?? '',
          message: '',
          mediaUrl: uploadResult['url'],
          messageType: 'image',
          seen: false,
          delivered: false,
          sentAt: now,
          isEdited: false,
          isDeleted: false,
        );

        // Add message immediately to UI (optimistic update)
        final updatedMessages = List<P2PMessage>.from(_chat!.messages);
        updatedMessages.add(optimisticMessage);
        updatedMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
        
        setState(() {
          _chat = P2PChat(
            id: _chat!.id,
            participants: _chat!.participants,
            apartmentCode: _chat!.apartmentCode,
            messages: updatedMessages,
            unreadCount: _chat!.unreadCount,
            createdAt: _chat!.createdAt,
            updatedAt: _chat!.updatedAt,
          );
        });

        _seenMessageIds.add(tempMessageId);
        _scrollToBottom();

        // Send message to server
        await ChatService.sendP2PMessage(
          chatId: _chat?.id,
          receiverId: widget.receiverId,
          message: '',
          mediaUrl: uploadResult['url'],
          messageType: 'image',
        );

        // Socket will update with real message
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

  String _getInitials(String name) {
    return name.split(' ').map((n) => n[0]).take(2).join().toUpperCase();
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
      return Scaffold(
        appBar: AppBar(title: Text(widget.receiverName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Empty Messages State
    // Get visible messages (not deleted) and ensure they're sorted by timestamp
    final allMessages = _chat?.messages.where((m) => !m.isDeleted).toList() ?? [];
    final visibleMessages = List<P2PMessage>.from(allMessages);
    visibleMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    final hasMessages = visibleMessages.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          // Header - WhatsApp-like design (same as community chat)
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
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: widget.receiverProfilePicture != null
                            ? CachedNetworkImageProvider(
                                widget.receiverProfilePicture!,
                              )
                            : null,
                        child: widget.receiverProfilePicture == null
                            ? CircleAvatar(
                                radius: 20,
                                backgroundColor: _getRoleColor(
                                  widget.receiverRole,
                                ),
                                child: Text(
                                  _getInitials(widget.receiverName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      if (_isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
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
                        Text(
                          widget.receiverName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _isOnline ? 'Online' : 'Offline',
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

          // Messages or Empty State - WhatsApp-like background (same as community chat)
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.grey[50]),
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
                        final isMe = message.senderId == _currentUserId;
                        return _buildMessageBubble(message, isMe);
                      },
                    )
                  : Center(
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
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Start a conversation with ${widget.receiverName}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
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
                        color: _isSending
                            ? Colors.grey[400]
                            : AppColors.primary,
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
                          hintText: 'Message ${widget.receiverName}...',
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
                      color:
                          _messageController.text.trim().isNotEmpty &&
                              !_isSending
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
                      onPressed:
                          (_messageController.text.trim().isNotEmpty &&
                              !_isSending)
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

  Widget _buildMessageBubble(P2PMessage message, bool isMe) {
    if (_chat == null || message.isDeleted) return const SizedBox.shrink();

    // Get sender info from participants
    P2PChatParticipant? senderParticipant;
    if (isMe) {
      senderParticipant = _chat!.participants.firstWhere(
        (p) => p.userId == _currentUserId,
        orElse: () => _chat!.participants.first,
      );
    } else {
      senderParticipant = _chat!.participants.firstWhere(
        (p) => p.userId == message.senderId,
        orElse: () => _chat!.participants.firstWhere(
          (p) => p.userId != _currentUserId,
          orElse: () => _chat!.participants.first,
        ),
      );
    }

    final senderName = senderParticipant.fullName ?? 'Unknown';
    final senderRole = senderParticipant.role;
    final roleColor = _getRoleColor(senderRole);
    final initials = _getInitials(senderName);
    final isRead =
        _lastReadTimestamp != null &&
        message.sentAt.isBefore(_lastReadTimestamp!);

    return Container(
      margin: EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: roleColor,
              backgroundImage: senderParticipant.profilePicture != null
                  ? CachedNetworkImageProvider(
                      senderParticipant.profilePicture!,
                    )
                  : null,
              child: senderParticipant.profilePicture == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          senderName,
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
                                senderRole == 'admin'
                                    ? Icons.shield
                                    : senderRole == 'staff'
                                    ? Icons.work
                                    : Icons.person,
                                size: 10,
                                color: roleColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                senderRole.toUpperCase(),
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
                        ? AppColors.primary
                        : (senderRole == 'admin'
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
                      if (message.message.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            message.message,
                            style: TextStyle(
                              fontSize: 15,
                              color: isMe ? Colors.white : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      if (message.mediaUrl != null) ...[
                        if (message.message.isNotEmpty)
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
                      if (message.message.isNotEmpty ||
                          message.mediaUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('h:mm a').format(message.sentAt),
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
                                  message.seen
                                      ? Icons.done_all
                                      : message.delivered
                                      ? Icons.done_all
                                      : Icons.done,
                                  size: 14,
                                  color: message.seen
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
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
