// Chat Data Models for ApartmentSync

class ChatMessage {
  final String messageId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String messageType; // 'text', 'image', 'poll', 'announcement'
  final String messageText;
  final String? mediaUrl;
  final List<MessageReaction> reactions;
  final bool isEdited;
  final bool isDeleted;
  final bool isPinned;
  final bool isEmergency;
  final List<String>? emergencyKeywords;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.messageType,
    required this.messageText,
    this.mediaUrl,
    required this.reactions,
    required this.isEdited,
    required this.isDeleted,
    required this.isPinned,
    required this.isEmergency,
    this.emergencyKeywords,
    required this.createdAt,
    this.updatedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['messageId']?.toString() ?? json['_id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? json['senderId']?['_id']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      senderRole: json['senderRole']?.toString() ?? 'resident',
      messageType: json['messageType']?.toString() ?? 'text',
      messageText: json['messageText']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString(),
      reactions: (json['reactions'] as List<dynamic>?)
          ?.map((r) => MessageReaction.fromJson(r))
          .toList() ?? [],
      isEdited: json['isEdited'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
      isPinned: json['isPinned'] ?? false,
      isEmergency: json['isEmergency'] ?? false,
      emergencyKeywords: json['emergencyKeywords'] != null
          ? List<String>.from(json['emergencyKeywords'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'messageType': messageType,
      'messageText': messageText,
      'mediaUrl': mediaUrl,
      'reactions': reactions.map((r) => r.toJson()).toList(),
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'isPinned': isPinned,
      'isEmergency': isEmergency,
      'emergencyKeywords': emergencyKeywords,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class MessageReaction {
  final String userId;
  final String emoji;

  MessageReaction({
    required this.userId,
    required this.emoji,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      userId: json['userId']?.toString() ?? json['userId']?['_id']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '👍',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'emoji': emoji,
    };
  }
}

class CommunityChat {
  final String id;
  final String apartmentCode;
  final String chatType; // 'community', 'wing', 'block', 'floor'
  final String? wing;
  final String? block;
  final int? floorNumber;
  final List<ChatMessage> messages;
  final int onlineCount;

  CommunityChat({
    required this.id,
    required this.apartmentCode,
    required this.chatType,
    this.wing,
    this.block,
    this.floorNumber,
    required this.messages,
    required this.onlineCount,
  });

  factory CommunityChat.fromJson(Map<String, dynamic> json) {
    return CommunityChat(
      id: json['_id']?.toString() ?? '',
      apartmentCode: json['apartmentCode']?.toString() ?? '',
      chatType: json['chatType']?.toString() ?? 'community',
      wing: json['wing']?.toString(),
      block: json['block']?.toString(),
      floorNumber: json['floorNumber'] != null ? int.tryParse(json['floorNumber'].toString()) : null,
      messages: (json['messages'] as List<dynamic>?)
          ?.map((m) => ChatMessage.fromJson(m))
          .toList() ?? [],
      onlineCount: json['onlineCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'apartmentCode': apartmentCode,
      'chatType': chatType,
      'wing': wing,
      'block': block,
      'floorNumber': floorNumber,
      'messages': messages.map((m) => m.toJson()).toList(),
      'onlineCount': onlineCount,
    };
  }
}

class P2PChatParticipant {
  final String userId;
  final String role;
  final String? fullName;
  final String? profilePicture;
  final String? phoneNumber;

  P2PChatParticipant({
    required this.userId,
    required this.role,
    this.fullName,
    this.profilePicture,
    this.phoneNumber,
  });

  factory P2PChatParticipant.fromJson(Map<String, dynamic> json) {
    final userData = json['userId'] is Map ? json['userId'] : {};
    return P2PChatParticipant(
      userId: json['userId']?['_id']?.toString() ?? json['userId']?.toString() ?? '',
      role: json['role']?.toString() ?? 'resident',
      fullName: userData['fullName']?.toString() ?? json['fullName']?.toString(),
      profilePicture: userData['profilePicture']?.toString() ?? json['profilePicture']?.toString(),
      phoneNumber: userData['phoneNumber']?.toString() ?? json['phoneNumber']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'role': role,
      'fullName': fullName,
      'profilePicture': profilePicture,
      'phoneNumber': phoneNumber,
    };
  }
}

class P2PMessage {
  final String id;
  final String senderId;
  final String message;
  final String? mediaUrl;
  final String messageType; // 'text', 'image', 'file'
  final bool seen;
  final bool delivered;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool isEdited;
  final bool isDeleted;

  P2PMessage({
    required this.id,
    required this.senderId,
    required this.message,
    this.mediaUrl,
    required this.messageType,
    required this.seen,
    required this.delivered,
    required this.sentAt,
    this.deliveredAt,
    this.readAt,
    required this.isEdited,
    required this.isDeleted,
  });

  factory P2PMessage.fromJson(Map<String, dynamic> json) {
    return P2PMessage(
      id: json['_id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? json['senderId']?['_id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString(),
      messageType: json['messageType']?.toString() ?? 'text',
      seen: json['seen'] ?? false,
      delivered: json['delivered'] ?? false,
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'].toString())
          : null,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
      isEdited: json['isEdited'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'senderId': senderId,
      'message': message,
      'mediaUrl': mediaUrl,
      'messageType': messageType,
      'seen': seen,
      'delivered': delivered,
      'sentAt': sentAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'isEdited': isEdited,
      'isDeleted': isDeleted,
    };
  }
}

class P2PChat {
  final String id;
  final List<P2PChatParticipant> participants;
  final String apartmentCode;
  final List<P2PMessage> messages;
  final Map<String, int> unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  P2PChat({
    required this.id,
    required this.participants,
    required this.apartmentCode,
    required this.messages,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
  });

  String? getOtherParticipantName(String currentUserId) {
    final other = participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => participants.first,
    );
    return other.fullName;
  }

  String? getOtherParticipantId(String currentUserId) {
    final other = participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => participants.first,
    );
    return other.userId;
  }

  int getUnreadCount(String userId) {
    if (userId.isEmpty) return 0;
    
    // Normalize userId to string format for comparison
    final normalizedUserId = userId.toString().trim();
    
    // Try exact match first
    if (unreadCount.containsKey(normalizedUserId)) {
      return unreadCount[normalizedUserId] ?? 0;
    }
    
    // Try matching with normalized keys (handle ObjectId string format)
    for (final key in unreadCount.keys) {
      final normalizedKey = key.toString().trim();
      if (normalizedKey == normalizedUserId) {
        return unreadCount[key] ?? 0;
      }
    }
    
    return 0;
  }

  P2PMessage? get lastMessage {
    return messages.isNotEmpty ? messages.last : null;
  }

  factory P2PChat.fromJson(Map<String, dynamic> json) {
    final unreadCountMap = <String, int>{};
    if (json['unreadCount'] is Map) {
      json['unreadCount'].forEach((key, value) {
        unreadCountMap[key.toString()] = int.tryParse(value.toString()) ?? 0;
      });
    }

    return P2PChat(
      id: json['_id']?.toString() ?? '',
      participants: (json['participants'] as List<dynamic>?)
          ?.map((p) => P2PChatParticipant.fromJson(p))
          .toList() ?? [],
      apartmentCode: json['apartmentCode']?.toString() ?? '',
      messages: (json['messages'] as List<dynamic>?)
          ?.map((m) => P2PMessage.fromJson(m))
          .toList() ?? [],
      unreadCount: unreadCountMap,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'participants': participants.map((p) => p.toJson()).toList(),
      'apartmentCode': apartmentCode,
      'messages': messages.map((m) => m.toJson()).toList(),
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class ComplaintChatParticipant {
  final String userId;
  final String role;
  final String? fullName;
  final String? profilePicture;
  final DateTime joinedAt;

  ComplaintChatParticipant({
    required this.userId,
    required this.role,
    this.fullName,
    this.profilePicture,
    required this.joinedAt,
  });

  factory ComplaintChatParticipant.fromJson(Map<String, dynamic> json) {
    final userData = json['userId'] is Map ? json['userId'] : {};
    return ComplaintChatParticipant(
      userId: json['userId']?['_id']?.toString() ?? json['userId']?.toString() ?? '',
      role: json['role']?.toString() ?? 'resident',
      fullName: userData['fullName']?.toString() ?? json['fullName']?.toString(),
      profilePicture: userData['profilePicture']?.toString() ?? json['profilePicture']?.toString(),
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'role': role,
      'fullName': fullName,
      'profilePicture': profilePicture,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}

class ComplaintChatMessage {
  final String id;
  final String senderId;
  final String senderRole;
  final String message;
  final String? mediaUrl;
  final String messageType; // 'text', 'image', 'status_update', 'internal_note'
  final bool isInternalNote;
  final DateTime sentAt;
  final bool isEdited;
  final bool isDeleted;

  ComplaintChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.message,
    this.mediaUrl,
    required this.messageType,
    required this.isInternalNote,
    required this.sentAt,
    required this.isEdited,
    required this.isDeleted,
  });

  factory ComplaintChatMessage.fromJson(Map<String, dynamic> json) {
    return ComplaintChatMessage(
      id: json['_id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? json['senderId']?['_id']?.toString() ?? '',
      senderRole: json['senderRole']?.toString() ?? 'resident',
      message: json['message']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString(),
      messageType: json['messageType']?.toString() ?? 'text',
      isInternalNote: json['isInternalNote'] ?? false,
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isEdited: json['isEdited'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'senderId': senderId,
      'senderRole': senderRole,
      'message': message,
      'mediaUrl': mediaUrl,
      'messageType': messageType,
      'isInternalNote': isInternalNote,
      'sentAt': sentAt.toIso8601String(),
      'isEdited': isEdited,
      'isDeleted': isDeleted,
    };
  }
}

class ComplaintChat {
  final String id;
  final String complaintId;
  final String apartmentCode;
  final List<ComplaintChatParticipant> participants;
  final List<ComplaintChatMessage> messages;
  final bool isActive;

  ComplaintChat({
    required this.id,
    required this.complaintId,
    required this.apartmentCode,
    required this.participants,
    required this.messages,
    required this.isActive,
  });

  factory ComplaintChat.fromJson(Map<String, dynamic> json) {
    return ComplaintChat(
      id: json['_id']?.toString() ?? '',
      complaintId: json['complaintId']?.toString() ?? json['complaintId']?['_id']?.toString() ?? '',
      apartmentCode: json['apartmentCode']?.toString() ?? '',
      participants: (json['participants'] as List<dynamic>?)
          ?.map((p) => ComplaintChatParticipant.fromJson(p))
          .toList() ?? [],
      messages: (json['messages'] as List<dynamic>?)
          ?.map((m) => ComplaintChatMessage.fromJson(m))
          .toList() ?? [],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'complaintId': complaintId,
      'apartmentCode': apartmentCode,
      'participants': participants.map((p) => p.toJson()).toList(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'isActive': isActive,
    };
  }
}

