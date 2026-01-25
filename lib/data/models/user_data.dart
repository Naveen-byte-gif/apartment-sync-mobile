class UserData {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final String role;
  final String status;
  final String? apartmentCode;
  final String? wing;
  final String? flatNumber;
  final String? flatCode;
  final int? floorNumber;
  final String? flatType;
  final String? profilePicture;
  final String? emergencyContact;
  final DateTime? registeredAt;
  final DateTime? lastUpdatedAt;
  final bool? isOnline;
  final DateTime? lastSeen;

  UserData({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    required this.role,
    required this.status,
    this.apartmentCode,
    this.wing,
    this.flatNumber,
    this.flatCode,
    this.floorNumber,
    this.flatType,
    this.profilePicture,
    this.emergencyContact,
    this.registeredAt,
    this.lastUpdatedAt,
    this.isOnline,
    this.lastSeen,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    // Handle floorNumber conversion - can be int or string from API
    int? floorNum;
    if (json['floorNumber'] != null) {
      if (json['floorNumber'] is int) {
        floorNum = json['floorNumber'] as int;
      } else if (json['floorNumber'] is String) {
        floorNum = int.tryParse(json['floorNumber'] as String);
      } else if (json['floorNumber'] is num) {
        floorNum = (json['floorNumber'] as num).toInt();
      }
    }
    
    // Handle profilePicture - can be Map, String, or null
    String? profilePic;
    if (json['profilePicture'] != null) {
      if (json['profilePicture'] is String) {
        profilePic = json['profilePicture'] as String;
      } else if (json['profilePicture'] is Map) {
        profilePic = json['profilePicture']?['url'] as String?;
      }
    }
    
    return UserData(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      apartmentCode: json['apartmentCode']?.toString(),
      wing: json['wing']?.toString(),
      flatNumber: json['flatNumber']?.toString(),
      flatCode: json['flatCode']?.toString(),
      floorNumber: floorNum,
      flatType: json['flatType']?.toString(),
      profilePicture: profilePic,
      emergencyContact: json['emergencyContact']?.toString(),
      registeredAt: json['registeredAt'] != null 
          ? DateTime.tryParse(json['registeredAt'].toString())
          : null,
      lastUpdatedAt: json['lastUpdatedAt'] != null
          ? DateTime.tryParse(json['lastUpdatedAt'].toString())
          : null,
      isOnline: json['isOnline'] as bool?,
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
      'status': status,
      'apartmentCode': apartmentCode,
      'wing': wing,
      'flatNumber': flatNumber,
      'flatCode': flatCode,
      'floorNumber': floorNumber,
      'flatType': flatType,
      'profilePicture': profilePicture,
      'registeredAt': registeredAt?.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }
}

