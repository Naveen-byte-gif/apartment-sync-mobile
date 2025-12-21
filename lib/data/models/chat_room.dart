class ChatRoom {
  final String id;
  final String type; // 'personal' or 'community_apartment'
  final String name;
  final String? description;
  final String? avatarUrl;
  final String? apartmentCode;
  final DateTime? lastMessageAt;
  final LastMessagePreview? lastMessagePreview;
  final bool isAnnouncementOnly;
  final bool unread;
  final List<ChatParticipant>? participants;

  ChatRoom({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.avatarUrl,
    this.apartmentCode,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.isAnnouncementOnly = false,
    this.unread = false,
    this.participants,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'personal',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      apartmentCode: json['apartmentCode']?.toString(),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString())
          : null,
      lastMessagePreview: json['lastMessagePreview'] != null
          ? LastMessagePreview.fromJson(json['lastMessagePreview'])
          : null,
      isAnnouncementOnly: json['isAnnouncementOnly'] ?? false,
      unread: json['unread'] ?? false,
      participants: json['participants'] != null
          ? (json['participants'] as List)
              .map((p) => ChatParticipant.fromJson(p))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'description': description,
      'avatarUrl': avatarUrl,
      'apartmentCode': apartmentCode,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastMessagePreview': lastMessagePreview?.toJson(),
      'isAnnouncementOnly': isAnnouncementOnly,
      'unread': unread,
      'participants': participants?.map((p) => p.toJson()).toList(),
    };
  }

  bool get isPersonal => type == 'personal';
  bool get isCommunity => type.startsWith('community');
}

class LastMessagePreview {
  final String? text;
  final String? senderName;
  final DateTime? createdAt;

  LastMessagePreview({
    this.text,
    this.senderName,
    this.createdAt,
  });

  factory LastMessagePreview.fromJson(Map<String, dynamic> json) {
    return LastMessagePreview(
      text: json['text']?.toString(),
      senderName: json['senderName']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'senderName': senderName,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class ChatParticipant {
  final String userId;
  final String role;
  final DateTime? lastReadAt;
  final bool isMuted;
  final bool isArchived;

  ChatParticipant({
    required this.userId,
    required this.role,
    this.lastReadAt,
    this.isMuted = false,
    this.isArchived = false,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      userId: json['user']?.toString() ?? json['userId']?.toString() ?? '',
      role: json['role']?.toString() ?? 'resident',
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.tryParse(json['lastReadAt'].toString())
          : null,
      isMuted: json['isMuted'] ?? false,
      isArchived: json['isArchived'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'role': role,
      'lastReadAt': lastReadAt?.toIso8601String(),
      'isMuted': isMuted,
      'isArchived': isArchived,
    };
  }
}

