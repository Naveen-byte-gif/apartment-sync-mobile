class ChatMessage {
  final String id;
  final String chatId;
  final ChatMessageSender sender;
  final String type; // 'text', 'image', 'system', 'file', 'audio', 'video', 'location', 'emergency', 'announcement', 'delivery_alert', 'visitor_alert', 'maintenance_alert', 'outage_notification'
  final String? text;
  final ChatMessageMedia? media;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;
  final DateTime? editedAt;
  final List<EditHistory> editHistory;
  final bool deletedForEveryone;
  final DateTime? deletedAt;
  final List<String> deletedFor;
  final String? replyTo; // Message ID this is replying to
  final ForwardedFrom? forwardedFrom;
  final String priority; // 'normal', 'high', 'urgent', 'emergency'
  final bool isEmergency;
  final bool isAnnouncement;
  final bool requiresAcknowledgment;
  final String? alertType; // 'delivery', 'visitor', 'maintenance', 'outage'
  final Map<String, dynamic>? alertData;
  final List<MessageReceipt> deliveredTo;
  final List<MessageReceipt> readBy;
  final List<MessageAcknowledgment> acknowledgments;
  final DateTime? canEditUntil;
  final DateTime? canDeleteUntil;
  final MessageStatus status; // Local status for optimistic updates

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.sender,
    this.type = 'text',
    this.text,
    this.media,
    required this.createdAt,
    this.updatedAt,
    this.isEdited = false,
    this.editedAt,
    this.editHistory = const [],
    this.deletedForEveryone = false,
    this.deletedAt,
    this.deletedFor = const [],
    this.replyTo,
    this.forwardedFrom,
    this.priority = 'normal',
    this.isEmergency = false,
    this.isAnnouncement = false,
    this.requiresAcknowledgment = false,
    this.alertType,
    this.alertData,
    this.deliveredTo = const [],
    this.readBy = const [],
    this.acknowledgments = const [],
    this.canEditUntil,
    this.canDeleteUntil,
    this.status = MessageStatus.sent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Handle media - only create if it has valid URL
    ChatMessageMedia? media;
    if (json['media'] != null) {
      final mediaData = json['media'];
      // Check if media is not empty object and has URL
      if (mediaData is Map && 
          mediaData['url'] != null && 
          mediaData['url'].toString().isNotEmpty) {
        // Cast to Map<String, dynamic> for type safety
        media = ChatMessageMedia.fromJson(Map<String, dynamic>.from(mediaData));
      }
    }

    // Handle forwarded from
    ForwardedFrom? forwardedFrom;
    if (json['forwardedFrom'] != null) {
      forwardedFrom = ForwardedFrom.fromJson(json['forwardedFrom']);
    }

    // Handle edit history
    List<EditHistory> editHistory = [];
    if (json['editHistory'] != null && json['editHistory'] is List) {
      editHistory = (json['editHistory'] as List)
          .map((e) => EditHistory.fromJson(e))
          .toList();
    }

    // Handle acknowledgments
    List<MessageAcknowledgment> acknowledgments = [];
    if (json['acknowledgments'] != null && json['acknowledgments'] is List) {
      acknowledgments = (json['acknowledgments'] as List)
          .map((a) => MessageAcknowledgment.fromJson(a))
          .toList();
    }

    // Handle alert data
    Map<String, dynamic>? alertData;
    if (json['alertData'] != null && json['alertData'] is Map) {
      alertData = Map<String, dynamic>.from(json['alertData']);
    }

    return ChatMessage(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      sender: ChatMessageSender.fromJson(json['sender'] ?? {}),
      type: json['type']?.toString() ?? 'text',
      text: json['text']?.toString(),
      media: media,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      isEdited: json['isEdited'] ?? false,
      editedAt: json['editedAt'] != null
          ? DateTime.tryParse(json['editedAt'].toString())
          : null,
      editHistory: editHistory,
      deletedForEveryone: json['deletedForEveryone'] ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'].toString())
          : null,
      deletedFor: json['deletedFor'] != null
          ? (json['deletedFor'] as List).map((d) => d.toString()).toList()
          : [],
      replyTo: json['replyTo']?.toString(),
      forwardedFrom: forwardedFrom,
      priority: json['priority']?.toString() ?? 'normal',
      isEmergency: json['isEmergency'] ?? false,
      isAnnouncement: json['isAnnouncement'] ?? false,
      requiresAcknowledgment: json['requiresAcknowledgment'] ?? false,
      alertType: json['alertType']?.toString(),
      alertData: alertData,
      deliveredTo: json['deliveredTo'] != null
          ? (json['deliveredTo'] as List)
              .map((d) => MessageReceipt.fromJson(d))
              .toList()
          : [],
      readBy: json['readBy'] != null
          ? (json['readBy'] as List)
              .map((r) => MessageReceipt.fromJson(r))
              .toList()
          : [],
      acknowledgments: acknowledgments,
      canEditUntil: json['canEditUntil'] != null
          ? DateTime.tryParse(json['canEditUntil'].toString())
          : null,
      canDeleteUntil: json['canDeleteUntil'] != null
          ? DateTime.tryParse(json['canDeleteUntil'].toString())
          : null,
      status: MessageStatus.sent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'sender': sender.toJson(),
      'type': type,
      'text': text,
      'media': media?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isEdited': isEdited,
      'deletedForEveryone': deletedForEveryone,
      'deliveredTo': deliveredTo.map((d) => d.toJson()).toList(),
      'readBy': readBy.map((r) => r.toJson()).toList(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? chatId,
    ChatMessageSender? sender,
    String? type,
    String? text,
    ChatMessageMedia? media,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
    DateTime? editedAt,
    List<EditHistory>? editHistory,
    bool? deletedForEveryone,
    DateTime? deletedAt,
    List<String>? deletedFor,
    String? replyTo,
    ForwardedFrom? forwardedFrom,
    String? priority,
    bool? isEmergency,
    bool? isAnnouncement,
    bool? requiresAcknowledgment,
    String? alertType,
    Map<String, dynamic>? alertData,
    List<MessageReceipt>? deliveredTo,
    List<MessageReceipt>? readBy,
    List<MessageAcknowledgment>? acknowledgments,
    DateTime? canEditUntil,
    DateTime? canDeleteUntil,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      text: text ?? this.text,
      media: media ?? this.media,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      editHistory: editHistory ?? this.editHistory,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedFor: deletedFor ?? this.deletedFor,
      replyTo: replyTo ?? this.replyTo,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      priority: priority ?? this.priority,
      isEmergency: isEmergency ?? this.isEmergency,
      isAnnouncement: isAnnouncement ?? this.isAnnouncement,
      requiresAcknowledgment: requiresAcknowledgment ?? this.requiresAcknowledgment,
      alertType: alertType ?? this.alertType,
      alertData: alertData ?? this.alertData,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      readBy: readBy ?? this.readBy,
      acknowledgments: acknowledgments ?? this.acknowledgments,
      canEditUntil: canEditUntil ?? this.canEditUntil,
      canDeleteUntil: canDeleteUntil ?? this.canDeleteUntil,
      status: status ?? this.status,
    );
  }

  bool get canEdit {
    if (deletedForEveryone) return false;
    if (canEditUntil == null) return true; // Legacy messages
    return DateTime.now().isBefore(canEditUntil!);
  }

  bool get canDelete {
    if (deletedForEveryone) return false;
    if (canDeleteUntil == null) return true; // Legacy messages
    return DateTime.now().isBefore(canDeleteUntil!);
  }
}

class ChatMessageSender {
  final String id;
  final String name;
  final String role;
  final String? profilePicture;

  ChatMessageSender({
    required this.id,
    required this.name,
    required this.role,
    this.profilePicture,
  });

  factory ChatMessageSender.fromJson(Map<String, dynamic> json) {
    String? profilePic;
    if (json['profilePicture'] != null) {
      if (json['profilePicture'] is String) {
        profilePic = json['profilePicture'] as String;
      } else if (json['profilePicture'] is Map) {
        profilePic = json['profilePicture']?['url'] as String?;
      }
    }

    return ChatMessageSender(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'resident',
      profilePicture: profilePic,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'profilePicture': profilePicture,
    };
  }
}

class ChatMessageMedia {
  final String url;
  final String? publicId;
  final String? mimeType;
  final int? size;
  final int? width;
  final int? height;

  ChatMessageMedia({
    required this.url,
    this.publicId,
    this.mimeType,
    this.size,
    this.width,
    this.height,
  });

  factory ChatMessageMedia.fromJson(Map<String, dynamic> json) {
    return ChatMessageMedia(
      url: json['url']?.toString() ?? '',
      publicId: json['publicId']?.toString(),
      mimeType: json['mimeType']?.toString(),
      size: json['size'] != null ? int.tryParse(json['size'].toString()) : null,
      width: json['width'] != null ? int.tryParse(json['width'].toString()) : null,
      height: json['height'] != null ? int.tryParse(json['height'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'publicId': publicId,
      'mimeType': mimeType,
      'size': size,
      'width': width,
      'height': height,
    };
  }
}

class MessageReceipt {
  final String userId;
  final DateTime at;

  MessageReceipt({
    required this.userId,
    required this.at,
  });

  factory MessageReceipt.fromJson(Map<String, dynamic> json) {
    return MessageReceipt(
      userId: json['user']?.toString() ?? json['userId']?.toString() ?? '',
      at: json['at'] != null
          ? DateTime.tryParse(json['at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'at': at.toIso8601String(),
    };
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class EditHistory {
  final String text;
  final DateTime editedAt;

  EditHistory({
    required this.text,
    required this.editedAt,
  });

  factory EditHistory.fromJson(Map<String, dynamic> json) {
    return EditHistory(
      text: json['text']?.toString() ?? '',
      editedAt: json['editedAt'] != null
          ? DateTime.tryParse(json['editedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'editedAt': editedAt.toIso8601String(),
    };
  }
}

class ForwardedFrom {
  final String messageId;
  final String chatId;
  final String senderName;

  ForwardedFrom({
    required this.messageId,
    required this.chatId,
    required this.senderName,
  });

  factory ForwardedFrom.fromJson(Map<String, dynamic> json) {
    return ForwardedFrom(
      messageId: json['messageId']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'chatId': chatId,
      'senderName': senderName,
    };
  }
}

class MessageAcknowledgment {
  final String userId;
  final DateTime acknowledgedAt;
  final String response; // 'acknowledged', 'seen', 'action_taken'

  MessageAcknowledgment({
    required this.userId,
    required this.acknowledgedAt,
    required this.response,
  });

  factory MessageAcknowledgment.fromJson(Map<String, dynamic> json) {
    return MessageAcknowledgment(
      userId: json['user']?.toString() ?? json['userId']?.toString() ?? '',
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.tryParse(json['acknowledgedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      response: json['response']?.toString() ?? 'acknowledged',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'acknowledgedAt': acknowledgedAt.toIso8601String(),
      'response': response,
    };
  }
}

