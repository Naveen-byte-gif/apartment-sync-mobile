import 'dart:io';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../../data/models/chat_data.dart';
import '../../data/models/user_data.dart';

class ChatService {
  // ==================== COMMUNITY CHAT ====================

  /// Get or create community chat
  static Future<CommunityChat> getCommunityChat({
    String? chatType,
    String? wing,
    String? block,
    int? floorNumber,
  }) async {
    final queryParams = <String, String>{};
    if (chatType != null) queryParams['chatType'] = chatType;
    if (wing != null) queryParams['wing'] = wing;
    if (block != null) queryParams['block'] = block;
    if (floorNumber != null)
      queryParams['floorNumber'] = floorNumber.toString();

    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

    final response = await ApiService.get(
      '${ApiConstants.communityChat}$queryString',
    );

    if (response['success'] == true && response['data'] != null) {
      return CommunityChat.fromJson(response['data']['chat']);
    }
    throw Exception(response['message'] ?? 'Failed to get community chat');
  }

  /// Send message to community chat
  static Future<ChatMessage> sendCommunityMessage({
    required String messageText,
    String? mediaUrl,
    String messageType = 'text',
    String? chatType,
    String? wing,
    String? block,
    int? floorNumber,
  }) async {
    final response = await ApiService.post(ApiConstants.sendCommunityMessage, {
      'messageText': messageText,
      'messageType': messageType,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (chatType != null) 'chatType': chatType,
      if (wing != null) 'wing': wing,
      if (block != null) 'block': block,
      if (floorNumber != null) 'floorNumber': floorNumber,
    });

    if (response['success'] == true && response['data'] != null) {
      return ChatMessage.fromJson(response['data']['message']);
    }
    throw Exception(response['message'] ?? 'Failed to send message');
  }

  /// Pin/unpin message (Admin only)
  static Future<ChatMessage> pinCommunityMessage({
    required String messageId,
    required String chatId,
    required bool isPinned,
  }) async {
    final response = await ApiService.put(
      ApiConstants.pinCommunityMessage(messageId),
      {'chatId': chatId, 'isPinned': isPinned},
    );

    if (response['success'] == true && response['data'] != null) {
      return ChatMessage.fromJson(response['data']['message']);
    }
    throw Exception(response['message'] ?? 'Failed to pin message');
  }

  /// Add reaction to message
  static Future<List<MessageReaction>> addReaction({
    required String messageId,
    required String chatId,
    required String emoji,
  }) async {
    final response = await ApiService.post(
      ApiConstants.addMessageReaction(messageId),
      {'chatId': chatId, 'emoji': emoji},
    );

    if (response['success'] == true && response['data'] != null) {
      return (response['data']['reactions'] as List)
          .map((r) => MessageReaction.fromJson(r))
          .toList();
    }
    throw Exception(response['message'] ?? 'Failed to add reaction');
  }

  // ==================== P2P CHAT ====================

  /// Get chatable users (users that can be chatted with)
  static Future<List<UserData>> getChatableUsers() async {
    final response = await ApiService.get(ApiConstants.chatableUsers);

    if (response['success'] == true && response['data'] != null) {
      return (response['data']['users'] as List)
          .map((u) => UserData.fromJson(u))
          .toList();
    }
    throw Exception(response['message'] ?? 'Failed to get chatable users');
  }

  /// Get user's P2P chats
  static Future<List<P2PChat>> getP2PChats() async {
    final response = await ApiService.get(ApiConstants.p2pChats);

    if (response['success'] == true && response['data'] != null) {
      return (response['data']['chats'] as List)
          .map((c) => P2PChat.fromJson(c))
          .toList();
    }
    throw Exception(response['message'] ?? 'Failed to get chats');
  }

  /// Get or create P2P chat with specific user
  static Future<P2PChat> getP2PChat(String receiverId) async {
    final response = await ApiService.get(ApiConstants.p2pChat(receiverId));

    if (response['success'] == true && response['data'] != null) {
      return P2PChat.fromJson(response['data']['chat']);
    }
    throw Exception(response['message'] ?? 'Failed to get chat');
  }

  /// Send P2P message
  static Future<P2PMessage> sendP2PMessage({
    String? chatId,
    String? receiverId,
    required String message,
    String? mediaUrl,
    String messageType = 'text',
  }) async {
    final response = await ApiService.post(ApiConstants.sendP2PMessage, {
      if (chatId != null) 'chatId': chatId,
      if (receiverId != null) 'receiverId': receiverId,
      'message': message,
      'messageType': messageType,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
    });

    if (response['success'] == true && response['data'] != null) {
      return P2PMessage.fromJson(response['data']['message']);
    }
    throw Exception(response['message'] ?? 'Failed to send message');
  }

  /// Mark P2P messages as read
  static Future<void> markP2PAsRead(String chatId) async {
    final response = await ApiService.put(
      ApiConstants.markP2PAsRead(chatId),
      {},
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to mark as read');
    }
  }

  // ==================== COMPLAINT CHAT ====================

  /// Get complaint chat
  static Future<ComplaintChat> getComplaintChat(String complaintId) async {
    final response = await ApiService.get(
      ApiConstants.complaintChat(complaintId),
    );

    if (response['success'] == true && response['data'] != null) {
      return ComplaintChat.fromJson(response['data']['chat']);
    }
    throw Exception(response['message'] ?? 'Failed to get complaint chat');
  }

  /// Send complaint chat message
  static Future<ComplaintChatMessage> sendComplaintMessage({
    required String complaintId,
    required String message,
    String? mediaUrl,
    String messageType = 'text',
    bool isInternalNote = false,
  }) async {
    final response = await ApiService.post(ApiConstants.sendComplaintMessage, {
      'complaintId': complaintId,
      'message': message,
      'messageType': messageType,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      'isInternalNote': isInternalNote,
    });

    if (response['success'] == true && response['data'] != null) {
      return ComplaintChatMessage.fromJson(response['data']['message']);
    }
    throw Exception(response['message'] ?? 'Failed to send message');
  }

  // ==================== UTILITIES ====================

  /// Upload chat image
  static Future<Map<String, String>> uploadChatImage(File imageFile) async {
    final response = await ApiService.uploadFile(
      ApiConstants.uploadChatImage,
      imageFile,
      fieldName: 'image',
    );

    if (response['success'] == true && response['data'] != null) {
      return {
        'url': response['data']['url'] ?? '',
        'publicId': response['data']['publicId'] ?? '',
      };
    }
    throw Exception(response['message'] ?? 'Failed to upload image');
  }
}
