import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';

class CommunityChatScreen extends StatefulWidget {
  final String? chatId;
  final String? chatName;

  const CommunityChatScreen({super.key, this.chatId, this.chatName});

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  File? _selectedImage;
  String? _chatId;
  String? _chatName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use provided chatId if available, otherwise load from API
    if (widget.chatId != null) {
      _chatId = widget.chatId;
      _chatName = widget.chatName;
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final chatProvider = context.read<ChatProvider>();
        chatProvider.setCurrentChat(_chatId!);
        chatProvider.loadCachedMessages(_chatId!);
        chatProvider.loadMessages(_chatId!);
      });
    } else {
      _loadCommunityChat();
    }
  }

  Future<void> _loadCommunityChat() async {
    try {
      // Get community chat (auto-created if doesn't exist)
      final response = await ApiService.get(ApiConstants.chatCommunity);
      if (response['success'] == true && mounted) {
        setState(() {
          _chatId = response['data']?['chat']?['id'];
          _chatName = response['data']?['chat']?['name'] ?? 'Community Chat';
          _isLoading = false;
        });

        if (_chatId != null) {
          final chatProvider = context.read<ChatProvider>();
          chatProvider.setCurrentChat(_chatId!);
          chatProvider.loadCachedMessages(_chatId!);
          chatProvider.loadMessages(_chatId!);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading community chat: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_chatId != null) {
      context.read<ChatProvider>().stopTyping(_chatId!);
    }
    context.read<ChatProvider>().setCurrentChat(null);
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final hasImage = _selectedImage != null;

    if (text.isEmpty && !hasImage) return;

    _messageController.clear();
    if (_chatId != null) {
      context.read<ChatProvider>().stopTyping(_chatId!);
    }

    final chatProvider = context.read<ChatProvider>();

    if (hasImage) {
      // Upload image first, then send message
      try {
        final media = await chatProvider.uploadChatMedia(_selectedImage!);
        if (media != null) {
          await chatProvider.sendMessage(
            _chatId!,
            text.isEmpty ? null : text,
            media: media,
          );
        }
        setState(() {
          _selectedImage = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
      }
    } else {
      await chatProvider.sendMessage(_chatId!, text);
    }

    _scrollToBottom();
  }

  void _onTextChanged(String text) {
    final chatProvider = context.read<ChatProvider>();
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      if (_chatId != null) {
        chatProvider.startTyping(_chatId!);
      }
    } else if (text.isEmpty && _isTyping) {
      _isTyping = false;
      if (_chatId != null) {
        chatProvider.stopTyping(_chatId!);
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mma').format(dateTime).toLowerCase();
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return 'Today';
    } else if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day - 1) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'staff':
        return 'Staff';
      case 'resident':
        return 'Resident';
      case 'owner':
        return 'Owner';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppColors.error;
      case 'staff':
        return AppColors.warning;
      case 'resident':
        return AppColors.primary;
      case 'owner':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  bool _hasValidMedia(ChatMessage message) {
    return message.media != null &&
        message.media!.url.isNotEmpty &&
        message.type == 'image';
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    bool isOwnMessage, {
    bool showSenderName = true,
  }) {
    final hasMedia = _hasValidMedia(message);
    final hasText = message.text != null && message.text!.isNotEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: showSenderName ? 4 : 2,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender info with role badge (only show if different sender)
            if (showSenderName)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage:
                          message.sender.profilePicture != null &&
                              message.sender.profilePicture!.isNotEmpty
                          ? NetworkImage(message.sender.profilePicture!)
                          : null,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child:
                          message.sender.profilePicture == null ||
                              message.sender.profilePicture!.isEmpty
                          ? Text(
                              message.sender.name.isNotEmpty
                                  ? message.sender.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              message.sender.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleColor(
                                message.sender.role,
                              ).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _getRoleColor(
                                  message.sender.role,
                                ).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getRoleLabel(message.sender.role),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _getRoleColor(message.sender.role),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Message bubble
            Container(
              padding: EdgeInsets.fromLTRB(
                hasMedia && hasText ? 12 : 16,
                10,
                16,
                10,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: const Radius.circular(4),
                  bottomRight: const Radius.circular(16),
                ),
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
                  // Media (if exists and valid)
                  if (hasMedia) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        message.media!.url,
                        width: 250,
                        height: 250,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 250,
                            height: 250,
                            color: AppColors.divider,
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 250,
                            height: 200,
                            color: AppColors.divider,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.broken_image,
                                  color: AppColors.textLight,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (hasText) const SizedBox(height: 8),
                  ],
                  // Text message (if exists)
                  if (hasText)
                    SelectableText(
                      message.text!,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  // Edited indicator
                  if (message.isEdited)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Edited',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: Text(
                _formatTime(message.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatDate(date),
              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
          ),
          Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _chatId == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Community Chat'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.user?.id;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                (_chatName?.isNotEmpty ?? false)
                    ? _chatName![0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _chatName ?? 'Community Chat',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onPressed: () {
              // Handle menu
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final messages = _chatId != null
                    ? chatProvider.getMessagesForChat(_chatId!)
                    : <ChatMessage>[];

                if (messages.isEmpty && chatProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (messages.isEmpty) {
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
                          'No messages yet',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isOwnMessage = message.sender.id == currentUserId;

                    // Show sender name if different from previous message or first message
                    final showSenderName =
                        index == 0 ||
                        messages[index - 1].sender.id != message.sender.id;

                    // Show date separator if needed
                    if (index == 0 ||
                        (index > 0 &&
                            messages[index - 1].createdAt.day !=
                                message.createdAt.day)) {
                      return Column(
                        children: [
                          _buildDateSeparator(message.createdAt),
                          _buildMessageBubble(
                            message,
                            isOwnMessage,
                            showSenderName: showSenderName,
                          ),
                        ],
                      );
                    }

                    return _buildMessageBubble(
                      message,
                      isOwnMessage,
                      showSenderName: showSenderName,
                    );
                  },
                );
              },
            ),
          ),
          // Typing indicator
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              if (_chatId != null && !chatProvider.isUserTyping(_chatId!)) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'Someone is typing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Selected image preview
          if (_selectedImage != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.background,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Image selected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Tap send to upload',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.error),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _showEmojiPicker
                            ? Icons.keyboard
                            : Icons.emoji_emotions_outlined,
                        color: _showEmojiPicker
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      onPressed: _toggleEmojiPicker,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'EVERY ONE MESSAGE THIS IS COMMUNITY CHAT',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: _onTextChanged,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.image_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: _pickImage,
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
                // Emoji picker
                if (_showEmojiPicker)
                  SizedBox(
                    height: 250,
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        _messageController.text += emoji.emoji;
                      },
                      config: Config(
                        height: 256,
                        checkPlatformCompatibility: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
