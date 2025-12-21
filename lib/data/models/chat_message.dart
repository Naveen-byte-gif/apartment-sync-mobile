class ChatMessage {
  final String id;
  final String chatId;
  final ChatMessageSender sender;
  final String type; // 'text', 'image', 'system'
  final String? text;
  final ChatMessageMedia? media;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;
  final bool deletedForEveryone;
  final List<MessageReceipt> deliveredTo;
  final List<MessageReceipt> readBy;
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
    this.deletedForEveryone = false,
    this.deliveredTo = const [],
    this.readBy = const [],
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
      deletedForEveryone: json['deletedForEveryone'] ?? false,
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
    bool? deletedForEveryone,
    List<MessageReceipt>? deliveredTo,
    List<MessageReceipt>? readBy,
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
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      readBy: readBy ?? this.readBy,
      status: status ?? this.status,
    );
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

