import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
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
      setState(() {
        _chat = chat;
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

    socketService.on('p2p_message_received', (data) {
      if (mounted && data['chatId'] == _chat?.id && data['message'] != null) {
        final message = P2PMessage.fromJson(data['message']);
        setState(() {
          _chat?.messages.add(message);
        });
        _scrollToBottom();
        ChatService.markP2PAsRead(_chat!.id);
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
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await ChatService.sendP2PMessage(
        chatId: _chat?.id,
        receiverId: widget.receiverId,
        message: text,
      );
      _messageController.clear();
      _loadUserAndChat(); // Refresh to get updated chat
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isSending = true);
      final file = File(image.path);
      final uploadResult = await ChatService.uploadChatImage(file);
      await ChatService.sendP2PMessage(
        chatId: _chat?.id,
        receiverId: widget.receiverId,
        message: '',
        mediaUrl: uploadResult['url'],
        messageType: 'image',
      );
      _loadUserAndChat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending image: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isSending = false);
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _getRoleColor(widget.receiverRole),
                  backgroundImage: widget.receiverProfilePicture != null
                      ? CachedNetworkImageProvider(
                          widget.receiverProfilePicture!,
                        )
                      : null,
                  child: widget.receiverProfilePicture == null
                      ? Text(
                          _getInitials(widget.receiverName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.phone), onPressed: () {}),
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _chat == null || _chat!.messages.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _chat!.messages.length,
                    itemBuilder: (context, index) {
                      final message = _chat!.messages[index];
                      final isMe = message.senderId == _currentUserId;
                      return _buildMessageBubble(message, isMe);
                    },
                  ),
          ),
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
                    onPressed: () {
                      setState(() {
                        _showEmojiPicker = !_showEmojiPicker;
                        if (_showEmojiPicker) {
                          _focusNode.unfocus();
                        }
                      });
                    },
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
                      focusNode: _focusNode,
                      onTap: () {
                        if (_showEmojiPicker) {
                          setState(() {
                            _showEmojiPicker = false;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.receiverName}...',
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
          if (_showEmojiPicker)
            SizedBox(
              height: 256,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _messageController.text += emoji.emoji;
                },
                config: const Config(
                  height: 256,
                  checkPlatformCompatibility: true,
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
              backgroundImage: senderParticipant.profilePicture != null
                  ? CachedNetworkImageProvider(senderParticipant.profilePicture!)
                  : null,
              child: senderParticipant.profilePicture == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
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
                        senderName,
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
                              senderRole == 'admin'
                                  ? Icons.shield
                                  : Icons.person,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              senderRole.toUpperCase(),
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
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.orange[100] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                      if (message.message.isNotEmpty)
                        Text(
                          message.message,
                          style: const TextStyle(fontSize: 14),
                        ),
                      if (message.mediaUrl != null) ...[
                        if (message.message.isNotEmpty) const SizedBox(height: 8),
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
                                child: const Icon(Icons.error, color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(message.sentAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.seen ? Icons.done_all : Icons.done,
                        size: 16,
                        color: message.seen ? Colors.blue : Colors.grey,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundColor: _currentUserRole != null
                  ? _getRoleColor(_currentUserRole!)
                  : Colors.orange,
              child: Text(
                _currentUserName != null ? _getInitials(_currentUserName!) : 'ME',
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
