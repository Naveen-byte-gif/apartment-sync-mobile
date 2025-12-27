import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/services/api_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/api_constants.dart';
import '../../data/models/chat_room.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_user.dart';

class ChatProvider with ChangeNotifier {
  final SocketService _socketService = SocketService();
  
  List<ChatRoom> _chats = [];
  Map<String, List<ChatMessage>> _messages = {}; // chatId -> messages
  Map<String, ChatUser> _users = {}; // userId -> user
  Map<String, bool> _typingUsers = {}; // chatId -> isTyping
  Map<String, Set<String>> _onlineUsers = {}; // chatId -> Set of userIds
  List<Map<String, dynamic>> _messageQueue = []; // Queue for offline messages
  String? _currentChatId;
  bool _isLoading = false;
  String? _error;
  bool _isOnline = true;

  List<ChatRoom> get chats => _chats;
  Map<String, List<ChatMessage>> get messages => _messages;
  Map<String, ChatUser> get users => _users;
  Map<String, bool> get typingUsers => _typingUsers;
  Map<String, Set<String>> get onlineUsers => _onlineUsers;
  String? get currentChatId => _currentChatId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<ChatMessage> getMessagesForChat(String chatId) {
    return _messages[chatId] ?? [];
  }

  ChatUser? getUser(String userId) {
    return _users[userId];
  }

  bool isUserTyping(String chatId) {
    return _typingUsers[chatId] ?? false;
  }

  bool isUserOnline(String userId, String chatId) {
    return _onlineUsers[chatId]?.contains(userId) ?? false;
  }

  ChatProvider() {
    _initializeSocketListeners();
    _loadCachedData();
    _checkConnectionStatus();
    _syncQueuedMessages();
    _ensureSocketConnected();
  }

  void _ensureSocketConnected() async {
    // Get user ID from API if socket not connected
    if (!_socketService.isConnected) {
      try {
        final response = await ApiService.get('/auth/me');
        if (response['success'] == true && response['data']?['user'] != null) {
          final userId = response['data']?['user']?['id']?.toString() ?? 
                         response['data']?['user']?['_id']?.toString();
          if (userId != null) {
            print('🔌 [CHAT] Connecting socket with user ID: $userId');
            _socketService.connect(userId);
          } else {
            print('⚠️ [CHAT] No user ID found in response');
          }
        } else {
          print('⚠️ [CHAT] Failed to get user data for socket connection');
        }
      } catch (e) {
        print('❌ [CHAT] Error connecting socket: $e');
      }
    } else {
      print('✅ [CHAT] Socket already connected');
    }
  }

  void _checkConnectionStatus() {
    _isOnline = _socketService.isConnected;
    if (_isOnline) {
      _syncQueuedMessages();
    }
    // Periodically check connection status
    Future.delayed(const Duration(seconds: 5), () {
      final wasOnline = _isOnline;
      _isOnline = _socketService.isConnected;
      if (!wasOnline && _isOnline) {
        _syncQueuedMessages();
      }
      notifyListeners();
    });
  }

  Future<void> _syncQueuedMessages() async {
    if (!_isOnline || _messageQueue.isEmpty) return;

    final queueCopy = List<Map<String, dynamic>>.from(_messageQueue);
    _messageQueue.clear();

    for (final queuedMessage in queueCopy) {
      try {
        final chatId = queuedMessage['chatId'] as String;
        final text = queuedMessage['text'] as String;
        final type = queuedMessage['type'] as String?;
        final media = queuedMessage['media'] as Map<String, dynamic>?;

        // Determine if it's community or private chat
        final chat = _chats.firstWhere((c) => c.id == chatId, orElse: () => ChatRoom(id: chatId, name: '', type: 'personal', participants: []));
        final isCommunity = chat.type == 'community';
        
        String endpoint;
        if (isCommunity) {
          endpoint = ApiConstants.chatCommunityMessage;
        } else {
          endpoint = ApiConstants.chatPrivateMessage(chatId);
        }
        
        final response = await ApiService.post(
          endpoint,
          {
            'content': text,
            'messageType': type ?? 'text',
            if (media != null) 'attachments': [media],
          },
        );

        if (response['success'] == true) {
          final sentMessage = ChatMessage.fromJson(response['data']?['message'] ?? {});
          _addMessage(sentMessage);
          _updateChatPreview(sentMessage);
        } else {
          // Re-add to queue if failed
          _messageQueue.add(queuedMessage);
        }
      } catch (e) {
        // Re-add to queue on error
        _messageQueue.add(queuedMessage);
      }
    }

    _cacheMessageQueue();
    notifyListeners();
  }

  void _initializeSocketListeners() {
    print('🔌 [CHAT] Initializing socket listeners');
    
    // Chat message received
    _socketService.on('chat_message', (data) {
      try {
        print('📨 [CHAT] Received chat_message: $data');
        final message = ChatMessage.fromJson(data);
        _addMessage(message);
        _updateChatPreview(message);
        notifyListeners();
      } catch (e) {
        print('❌ [CHAT] Error handling chat_message: $e');
        print('❌ [CHAT] Error stack: ${StackTrace.current}');
      }
    });

    // Typing indicators
    _socketService.on('typing_start', (data) {
      try {
        print('⌨️ [CHAT] Typing start: $data');
        final chatId = data['chatId']?.toString();
        if (chatId != null) {
          _typingUsers[chatId] = true;
          notifyListeners();
        }
      } catch (e) {
        print('❌ [CHAT] Error handling typing_start: $e');
      }
    });

    _socketService.on('typing_stop', (data) {
      try {
        print('⌨️ [CHAT] Typing stop: $data');
        final chatId = data['chatId']?.toString();
        if (chatId != null) {
          _typingUsers[chatId] = false;
          notifyListeners();
        }
      } catch (e) {
        print('❌ [CHAT] Error handling typing_stop: $e');
      }
    });

    // Presence updates
    _socketService.on('user_online', (data) {
      try {
        print('🟢 [CHAT] User online: $data');
        final userId = data['userId']?.toString();
        // For community chats, we might not have chatId in the event
        // We'll update online status for all chats
        if (userId != null) {
          // Update online status for all chats this user is part of
          for (final chat in _chats) {
            if (chat.isPersonal && chat.participants != null) {
              final isParticipant = chat.participants!.any((p) => p.userId == userId);
              if (isParticipant) {
                if (!_onlineUsers.containsKey(chat.id)) {
                  _onlineUsers[chat.id] = <String>{};
                }
                _onlineUsers[chat.id]!.add(userId);
              }
            } else if (chat.isCommunity) {
              // For community chats, track online users
              if (!_onlineUsers.containsKey(chat.id)) {
                _onlineUsers[chat.id] = <String>{};
              }
              _onlineUsers[chat.id]!.add(userId);
            }
          }
          notifyListeners();
        }
      } catch (e) {
        print('❌ [CHAT] Error handling user_online: $e');
      }
    });

    _socketService.on('user_offline', (data) {
      try {
        print('🔴 [CHAT] User offline: $data');
        final userId = data['userId']?.toString();
        if (userId != null) {
          // Remove from all chats
          for (final chatId in _onlineUsers.keys) {
            _onlineUsers[chatId]?.remove(userId);
          }
          notifyListeners();
        }
      } catch (e) {
        print('❌ [CHAT] Error handling user_offline: $e');
      }
    });

    // Message read receipts
    _socketService.on('chat_read', (data) {
      try {
        print('✓ [CHAT] Chat read: $data');
        final chatId = data['chatId']?.toString();
        if (chatId != null) {
          _updateReadReceipts(chatId);
          notifyListeners();
        }
      } catch (e) {
        print('❌ [CHAT] Error handling chat_read: $e');
      }
    });

    // Message delivered
    _socketService.on('message_delivered', (data) {
      try {
        print('✓✓ [CHAT] Message delivered: $data');
        final messageId = data['messageId']?.toString();
        final chatId = data['chatId']?.toString();
        if (messageId != null && chatId != null) {
          _updateMessageStatus(chatId, messageId, MessageStatus.delivered);
          notifyListeners();
        }
      } catch (e) {
        print('❌ [CHAT] Error handling message_delivered: $e');
      }
    });
  }

  void _addMessage(ChatMessage message) {
    if (!_messages.containsKey(message.chatId)) {
      _messages[message.chatId] = [];
    }
    
    // Check if message already exists (avoid duplicates)
    final existingIndex = _messages[message.chatId]!
        .indexWhere((m) => m.id == message.id);
    
    if (existingIndex >= 0) {
      _messages[message.chatId]![existingIndex] = message;
    } else {
      _messages[message.chatId]!.add(message);
      _messages[message.chatId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // The backend will handle delivery receipts automatically
    }

    _cacheMessages(message.chatId);
  }

  void _updateChatPreview(ChatMessage message) {
    final chatIndex = _chats.indexWhere((c) => c.id == message.chatId);
    if (chatIndex >= 0) {
      final chat = _chats[chatIndex];
      _chats[chatIndex] = ChatRoom(
        id: chat.id,
        type: chat.type,
        name: chat.name,
        description: chat.description,
        avatarUrl: chat.avatarUrl,
        apartmentCode: chat.apartmentCode,
        lastMessageAt: message.createdAt,
        lastMessagePreview: LastMessagePreview(
          text: message.text ?? (message.media != null ? '[Media]' : ''),
          senderName: message.sender.name,
          createdAt: message.createdAt,
        ),
        isAnnouncementOnly: chat.isAnnouncementOnly,
        unread: chat.unread,
        participants: chat.participants,
      );
      _cacheChats();
    }
  }

  void _updateReadReceipts(String chatId) {
    // Update read receipts for messages in this chat
    if (_messages.containsKey(chatId)) {
      // This would be updated from server response
      notifyListeners();
    }
  }

  void _updateMessageStatus(String chatId, String messageId, MessageStatus status) {
    if (_messages.containsKey(chatId)) {
      final index = _messages[chatId]!.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        _messages[chatId]![index] = _messages[chatId]![index].copyWith(status: status);
        _cacheMessages(chatId);
      }
    }
  }

  // Load chats from API
  Future<void> loadChats({String? filter}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Ensure socket is connected
    _ensureSocketConnected();

    try {
      // Load private chats
      final privateResponse = await ApiService.get(ApiConstants.chatPrivate);
      List<ChatRoom> allChats = [];
      
      if (privateResponse['success'] == true) {
        final privateChatsData = privateResponse['data']?['chats'] as List? ?? [];
        // Convert private chats to ChatRoom format if needed
        for (var chatData in privateChatsData) {
          // Create ChatRoom from private chat data
          final chatId = chatData['id'] as String?;
          final otherParticipant = chatData['otherParticipant'] as Map<String, dynamic>?;
          if (chatId != null && otherParticipant != null) {
            final chatName = otherParticipant['name'] as String? ?? 'Private Chat';
            final chatRoom = ChatRoom(
              id: chatId,
              name: chatName,
              type: 'personal',
              participants: [],
              lastMessageAt: chatData['lastMessageAt'] != null
                  ? DateTime.parse(chatData['lastMessageAt'])
                  : DateTime.now(),
            );
            allChats.add(chatRoom);
          }
        }
      }
      
      // Load community chat (if user has apartment)
      try {
        final communityResponse = await ApiService.get(ApiConstants.chatCommunity);
        if (communityResponse['success'] == true) {
          final chatData = communityResponse['data']?['chat'];
          if (chatData != null) {
            final chatRoom = ChatRoom(
              id: chatData['id'] as String? ?? 'community',
              name: chatData['name'] as String? ?? 'Community Chat',
              type: 'community',
              participants: [],
              lastMessageAt: chatData['lastMessageAt'] != null
                  ? DateTime.parse(chatData['lastMessageAt'])
                  : DateTime.now(),
            );
            allChats.insert(0, chatRoom); // Add community chat at the beginning
          }
        }
      } catch (e) {
        // Community chat might not be available, that's okay
        print('Note: Community chat not available: $e');
      }
      
      _chats = allChats;
      _cacheChats();
      _error = null;
    } catch (e) {
      _error = 'Error loading chats: $e';
      print('Error loading chats: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load messages for a chat
  Future<void> loadMessages(String chatId, {String? before, int limit = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String endpoint = '/chats/$chatId/messages?limit=$limit';
      if (before != null) {
        endpoint += '&before=$before';
      }

      final response = await ApiService.get(endpoint);
      
      if (response['success'] == true) {
        final messagesData = response['data']?['messages'] as List? ?? [];
        final loadedMessages = messagesData.map((m) => ChatMessage.fromJson(m)).toList();
        
        if (!_messages.containsKey(chatId)) {
          _messages[chatId] = [];
        }
        
        // Merge with existing messages, avoiding duplicates
        for (final message in loadedMessages) {
          if (!_messages[chatId]!.any((m) => m.id == message.id)) {
            _messages[chatId]!.add(message);
          }
        }
        
        _messages[chatId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _cacheMessages(chatId);
        _error = null;
        
        // Mark messages as delivered for personal chats
        // This is handled automatically by the backend when messages are loaded
        // But we can also call the API to mark as delivered
        try {
          // Mark as delivered for personal chats (backend handles this)
          // We'll mark as read when user views the chat
          await markAsRead(chatId);
        } catch (e) {
          // Ignore errors for marking as read
          print('Note: Could not mark messages as read: $e');
        }
      } else {
        _error = response['message'] ?? 'Failed to load messages';
      }
    } catch (e) {
      _error = 'Error loading messages: $e';
      print('Error loading messages: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send a message
  Future<ChatMessage?> sendMessage(String chatId, String? text, {String? type, Map<String, dynamic>? media}) async {
    try {
      final messageData = {
        if (text != null && text.isNotEmpty) 'text': text,
        'type': type ?? (media != null ? 'image' : 'text'),
        if (media != null) 'media': media,
      };

      // Optimistic update
      final tempMessage = ChatMessage(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        chatId: chatId,
        sender: ChatMessageSender(
          id: 'current_user', // Will be replaced by actual user data
          name: 'You',
          role: 'resident',
        ),
        type: type ?? (media != null ? 'image' : 'text'),
        text: text,
        media: media != null ? ChatMessageMedia.fromJson(media) : null,
        createdAt: DateTime.now(),
        status: MessageStatus.sending,
      );

      _addMessage(tempMessage);
      notifyListeners();

      // Check if online
      _isOnline = _socketService.isConnected;
      
      if (!_isOnline) {
        // Queue message for later
        _messageQueue.add({
          'chatId': chatId,
          'text': text,
          'type': type,
          'media': media,
          'tempId': tempMessage.id,
        });
        _cacheMessageQueue();
        
        // Update status to failed (will retry when online)
        final index = _messages[chatId]!.indexWhere((m) => m.id == tempMessage.id);
        if (index >= 0) {
          _messages[chatId]![index] = tempMessage.copyWith(status: MessageStatus.failed);
        }
        notifyListeners();
        return tempMessage;
      }

      // Determine if it's community or private chat
      // Try to find chat in loaded chats, otherwise assume private
      ChatRoom? chat;
      try {
        chat = _chats.firstWhere((c) => c.id == chatId);
      } catch (e) {
        // Chat not in list, try to determine from context
        // Community chats might have a specific pattern or we can try community first
        chat = null;
      }
      
      final isCommunity = chat?.type == 'community';
      
      String endpoint;
      Map<String, dynamic> requestBody;
      
      if (isCommunity) {
        endpoint = ApiConstants.chatCommunityMessage;
        requestBody = {
          'content': text ?? '',
          'messageType': type ?? (media != null ? 'image' : 'text'),
          if (media != null) 'attachments': [media],
        };
      } else {
        // Private chat
        endpoint = ApiConstants.chatPrivateMessage(chatId);
        requestBody = {
          'content': text ?? '',
          'messageType': type ?? (media != null ? 'image' : 'text'),
          if (media != null) 'attachments': [media],
        };
      }
      
      final response = await ApiService.post(endpoint, requestBody);
      
      if (response['success'] == true) {
        final sentMessage = ChatMessage.fromJson(response['data']?['message'] ?? {});
        
        // Replace temp message with actual message
        final index = _messages[chatId]!.indexWhere((m) => m.id == tempMessage.id);
        if (index >= 0) {
          _messages[chatId]![index] = sentMessage.copyWith(status: MessageStatus.sent);
        } else {
          _addMessage(sentMessage);
        }
        
        _updateChatPreview(sentMessage);
        _cacheMessages(chatId);
        notifyListeners();
        return sentMessage;
      } else {
        // Remove failed message or queue it
        final index = _messages[chatId]!.indexWhere((m) => m.id == tempMessage.id);
        if (index >= 0) {
          _messages[chatId]![index] = tempMessage.copyWith(status: MessageStatus.failed);
        }
        
        // Queue for retry
        _messageQueue.add({
          'chatId': chatId,
          'text': text,
          'type': type,
          'media': media,
          'tempId': tempMessage.id,
        });
        _cacheMessageQueue();
        
        _error = response['message'] ?? 'Failed to send message';
        notifyListeners();
        return null;
      }
    } catch (e) {
      // Network error - queue message
      final tempMessage = ChatMessage(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        chatId: chatId,
        sender: ChatMessageSender(
          id: 'current_user',
          name: 'You',
          role: 'resident',
        ),
        type: type ?? (media != null ? 'image' : 'text'),
        text: text,
        media: media != null ? ChatMessageMedia.fromJson(media) : null,
        createdAt: DateTime.now(),
        status: MessageStatus.failed,
      );

      _messageQueue.add({
        'chatId': chatId,
        'text': text,
        'type': type,
        'media': media,
        'tempId': tempMessage.id,
      });
      _cacheMessageQueue();
      
      _error = 'Error sending message: $e';
      print('Error sending message: $e');
      notifyListeners();
      return null;
    }
  }

  // Upload chat media
  Future<Map<String, dynamic>?> uploadChatMedia(File imageFile) async {
    try {
      final response = await ApiService.uploadFile(
        ApiConstants.uploadChatMedia,
        imageFile,
        fieldName: 'image',
      );
      
      if (response['success'] == true && response['data']?['media'] != null) {
        return response['data']?['media'] as Map<String, dynamic>?;
      } else {
        _error = response['message'] ?? 'Failed to upload media';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'Error uploading media: $e';
      print('Error uploading media: $e');
      notifyListeners();
      return null;
    }
  }

  // Mark messages as read
  Future<void> markAsRead(String chatId) async {
    try {
      await ApiService.put(ApiConstants.chatMarkRead(chatId), {});
      
      // Update local chat unread status
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex >= 0) {
        _chats[chatIndex] = ChatRoom(
          id: _chats[chatIndex].id,
          type: _chats[chatIndex].type,
          name: _chats[chatIndex].name,
          description: _chats[chatIndex].description,
          avatarUrl: _chats[chatIndex].avatarUrl,
          apartmentCode: _chats[chatIndex].apartmentCode,
          lastMessageAt: _chats[chatIndex].lastMessageAt,
          lastMessagePreview: _chats[chatIndex].lastMessagePreview,
          isAnnouncementOnly: _chats[chatIndex].isAnnouncementOnly,
          unread: false,
          participants: _chats[chatIndex].participants,
        );
        _cacheChats();
        notifyListeners();
      }
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  // Get or create personal chat
  Future<ChatRoom?> getOrCreatePersonalChat(String userId) async {
    try {
      final response = await ApiService.get(ApiConstants.chatPrivateWithUser(userId));
      
      if (response['success'] == true) {
        final chat = ChatRoom.fromJson(response['data']?['chat'] ?? {});
        
        // Add to chats list if not already present
        if (!_chats.any((c) => c.id == chat.id)) {
          _chats.add(chat);
          _cacheChats();
        }
        
        notifyListeners();
        return chat;
      }
      return null;
    } catch (e) {
      print('Error getting/creating personal chat: $e');
      return null;
    }
  }

  // Get or create community chat
  Future<ChatRoom?> getOrCreateCommunityChat(String apartmentCode) async {
    try {
      final response = await ApiService.get(ApiConstants.chatCommunity);
      
      if (response['success'] == true) {
        final chat = ChatRoom.fromJson(response['data']?['chat'] ?? {});
        
        // Add to chats list if not already present
        if (!_chats.any((c) => c.id == chat.id)) {
          _chats.add(chat);
          _cacheChats();
        }
        
        notifyListeners();
        return chat;
      }
      return null;
    } catch (e) {
      print('Error getting/creating community chat: $e');
      return null;
    }
  }

  // Get users for chat
  Future<List<ChatUser>> getUsersForChat({String? apartmentCode, String? search}) async {
    try {
      String endpoint = '/chats/residents';
      if (apartmentCode != null) {
        endpoint += '?apartmentCode=$apartmentCode';
      }
      if (search != null && search.isNotEmpty) {
        endpoint += apartmentCode != null ? '&search=$search' : '?search=$search';
      }

      final response = await ApiService.get(endpoint);
      
      if (response['success'] == true) {
        final usersData = response['data']?['users'] as List? ?? [];
        final users = usersData.map((u) => ChatUser.fromJson(u)).toList();
        
        // Cache users
        for (final user in users) {
          _users[user.id] = user;
        }
        
        return users;
      }
      return [];
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  // Typing indicators
  void startTyping(String chatId) {
    _socketService.emit('typing_start', {'chatId': chatId});
  }

  void stopTyping(String chatId) {
    _socketService.emit('typing_stop', {'chatId': chatId});
  }

  // Set current chat
  void setCurrentChat(String? chatId) {
    _currentChatId = chatId;
    if (chatId != null) {
      markAsRead(chatId);
    }
    notifyListeners();
  }

  // Caching methods
  void _cacheChats() {
    try {
      final chatsJson = _chats.map((c) => c.toJson()).toList();
      StorageService.setString('${AppConstants.cacheKey}_chats', jsonEncode(chatsJson));
    } catch (e) {
      print('Error caching chats: $e');
    }
  }

  void _loadCachedData() {
    try {
      final chatsJson = StorageService.getString('${AppConstants.cacheKey}_chats');
      if (chatsJson != null) {
        final chatsData = jsonDecode(chatsJson) as List;
        _chats = chatsData.map((c) => ChatRoom.fromJson(c)).toList();
        notifyListeners();
      }
      
      // Load message queue
      final queueJson = StorageService.getString('${AppConstants.cacheKey}_message_queue');
      if (queueJson != null) {
        final queueData = jsonDecode(queueJson) as List;
        _messageQueue = List<Map<String, dynamic>>.from(queueData);
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  void _cacheMessageQueue() {
    try {
      StorageService.setString('${AppConstants.cacheKey}_message_queue', jsonEncode(_messageQueue));
    } catch (e) {
      print('Error caching message queue: $e');
    }
  }

  void _cacheMessages(String chatId) {
    try {
      if (_messages.containsKey(chatId)) {
        final messagesJson = _messages[chatId]!.map((m) => m.toJson()).toList();
        StorageService.setString('${AppConstants.cacheKey}_messages_$chatId', jsonEncode(messagesJson));
      }
    } catch (e) {
      print('Error caching messages: $e');
    }
  }

  void loadCachedMessages(String chatId) {
    try {
      final messagesJson = StorageService.getString('${AppConstants.cacheKey}_messages_$chatId');
      if (messagesJson != null) {
        final messagesData = jsonDecode(messagesJson) as List;
        _messages[chatId] = messagesData.map((m) => ChatMessage.fromJson(m)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading cached messages: $e');
    }
  }

  // Search messages
  Future<List<ChatMessage>> searchMessages(String chatId, String query) async {
    try {
      final response = await ApiService.get('/chats/$chatId/search?query=$query');
      
      if (response['success'] == true) {
        final messagesData = response['data']?['messages'] as List? ?? [];
        return messagesData.map((m) => ChatMessage.fromJson(m)).toList();
      }
      return [];
    } catch (e) {
      print('Error searching messages: $e');
      return [];
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

