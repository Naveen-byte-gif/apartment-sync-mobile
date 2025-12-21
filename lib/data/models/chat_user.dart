class ChatUser {
  final String id;
  final String fullName;
  final String? phoneNumber;
  final String? email;
  final String role;
  final String? profilePicture;
  final String? apartmentCode;
  final String? flatNumber;
  final int? floorNumber;
  final String? flatType;
  final bool isOnline;
  final DateTime? lastSeen;

  ChatUser({
    required this.id,
    required this.fullName,
    this.phoneNumber,
    this.email,
    required this.role,
    this.profilePicture,
    this.apartmentCode,
    this.flatNumber,
    this.floorNumber,
    this.flatType,
    this.isOnline = false,
    this.lastSeen,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    String? profilePic;
    if (json['profilePicture'] != null) {
      if (json['profilePicture'] is String) {
        profilePic = json['profilePicture'] as String;
      } else if (json['profilePicture'] is Map) {
        profilePic = json['profilePicture']?['url'] as String?;
      }
    }

    return ChatUser(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'resident',
      profilePicture: profilePic,
      apartmentCode: json['apartmentCode']?.toString(),
      flatNumber: json['flatNumber']?.toString(),
      floorNumber: json['floorNumber'] != null
          ? int.tryParse(json['floorNumber'].toString())
          : null,
      flatType: json['flatType']?.toString(),
      isOnline: json['isOnline'] ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'email': email,
      'role': role,
      'profilePicture': profilePicture,
      'apartmentCode': apartmentCode,
      'flatNumber': flatNumber,
      'floorNumber': floorNumber,
      'flatType': flatType,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  String get displayName => fullName;
  String get roleLabel {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'staff':
        return 'Staff';
      case 'owner':
        return 'Owner';
      case 'resident':
        return 'Resident';
      default:
        return role;
    }
  }
}

