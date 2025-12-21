class ComplaintData {
  final String id;
  final String ticketNumber;
  final String title;
  final String description;
  final String category;
  final String subCategory;
  final String priority;
  final String status;
  final ComplaintLocation? location;
  final List<ComplaintMedia>? media;
  final String createdBy;
  final UserInfo? createdByUser;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final AssignmentInfo? assignedTo;
  final List<TimelineEntry>? timeline;
  final List<WorkUpdate>? workUpdates;
  final ResolutionInfo? resolution;
  final RatingInfo? rating;
  final List<Comment>? comments;
  final bool previouslyClosed;
  final DateTime? closedAt;
  final DateTime? reopenedAt;
  final String? reopenedBy;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancellationReason;

  ComplaintData({
    required this.id,
    required this.ticketNumber,
    required this.title,
    required this.description,
    required this.category,
    required this.subCategory,
    required this.priority,
    required this.status,
    this.location,
    this.media,
    required this.createdBy,
    this.createdByUser,
    required this.createdAt,
    this.updatedAt,
    this.assignedTo,
    this.timeline,
    this.workUpdates,
    this.resolution,
    this.rating,
    this.comments,
    this.previouslyClosed = false,
    this.closedAt,
    this.reopenedAt,
    this.reopenedBy,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
  });

  factory ComplaintData.fromJson(Map<String, dynamic> json) {
    return ComplaintData(
      id: json['id'] ?? json['_id'] ?? '',
      ticketNumber: json['ticketNumber'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      subCategory: json['subCategory'] ?? '',
      priority: json['priority'] ?? '',
      status: json['status'] ?? '',
      location: json['location'] != null
          ? ComplaintLocation.fromJson(json['location'])
          : null,
      media: json['media'] != null
          ? (json['media'] as List)
              .map((e) => ComplaintMedia.fromJson(e))
              .toList()
          : null,
      createdBy: json['createdBy'] is String
          ? json['createdBy']
          : json['createdBy']?['_id'] ?? '',
      createdByUser: json['createdBy'] is Map
          ? UserInfo.fromJson(json['createdBy'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      assignedTo: json['assignedTo'] != null &&
              json['assignedTo']['staff'] != null
          ? AssignmentInfo.fromJson(json['assignedTo'])
          : null,
      timeline: json['timeline'] != null
          ? (json['timeline'] as List)
              .map((e) => TimelineEntry.fromJson(e))
              .toList()
          : null,
      workUpdates: json['workUpdates'] != null
          ? (json['workUpdates'] as List)
              .map((e) => WorkUpdate.fromJson(e))
              .toList()
          : null,
      resolution: json['resolution'] != null &&
              json['resolution']['resolvedAt'] != null
          ? ResolutionInfo.fromJson(json['resolution'])
          : null,
      rating: json['rating'] != null && json['rating']['score'] != null
          ? RatingInfo.fromJson(json['rating'])
          : null,
      comments: json['comments'] != null
          ? (json['comments'] as List)
              .map((e) => Comment.fromJson(e))
              .toList()
          : null,
      previouslyClosed: json['previouslyClosed'] ?? false,
      closedAt: json['closedAt'] != null
          ? DateTime.parse(json['closedAt'])
          : null,
      reopenedAt: json['reopenedAt'] != null
          ? DateTime.parse(json['reopenedAt'])
          : null,
      reopenedBy: json['reopenedBy'] is String
          ? json['reopenedBy']
          : json['reopenedBy']?['_id'],
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'])
          : null,
      cancelledBy: json['cancelledBy'] is String
          ? json['cancelledBy']
          : json['cancelledBy']?['_id'],
      cancellationReason: json['cancellationReason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'subCategory': subCategory,
      'priority': priority,
      'location': location?.toJson(),
      'media': media?.map((e) => e.toJson()).toList(),
    };
  }

  bool get canReopen => status == 'Resolved' || status == 'Closed';
  bool get canClose => status == 'Resolved';
  bool get canCancel =>
      status != 'Resolved' && status != 'Closed' && status != 'Cancelled';
  bool get isActive =>
      ['Open', 'Assigned', 'In Progress', 'Reopened'].contains(status);
}

class ComplaintLocation {
  final String? specificLocation;
  final String? accessInstructions;
  final String? wing;
  final String? flatNumber;
  final int? floorNumber;

  ComplaintLocation({
    this.specificLocation,
    this.accessInstructions,
    this.wing,
    this.flatNumber,
    this.floorNumber,
  });

  factory ComplaintLocation.fromJson(Map<String, dynamic> json) {
    return ComplaintLocation(
      specificLocation: json['specificLocation'],
      accessInstructions: json['accessInstructions'],
      wing: json['wing'],
      flatNumber: json['flatNumber'],
      floorNumber: json['floorNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'specificLocation': specificLocation,
      'accessInstructions': accessInstructions,
      'wing': wing,
      'flatNumber': flatNumber,
      'floorNumber': floorNumber,
    };
  }

  String get displayAddress {
    if (wing != null && flatNumber != null) {
      return '$wing-$flatNumber${floorNumber != null ? ', Floor $floorNumber' : ''}';
    }
    return specificLocation ?? 'Not specified';
  }
}

class ComplaintMedia {
  final String url;
  final String? publicId;
  final String type;

  ComplaintMedia({
    required this.url,
    this.publicId,
    required this.type,
  });

  factory ComplaintMedia.fromJson(Map<String, dynamic> json) {
    return ComplaintMedia(
      url: json['url'] ?? '',
      publicId: json['publicId'],
      type: json['type'] ?? 'image',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'publicId': publicId,
      'type': type,
    };
  }
}

class AssignmentInfo {
  final String staffId;
  final StaffInfo? staff;
  final DateTime? assignedAt;
  final String? assignedBy;
  final UserInfo? assignedByUser;

  AssignmentInfo({
    required this.staffId,
    this.staff,
    this.assignedAt,
    this.assignedBy,
    this.assignedByUser,
  });

  factory AssignmentInfo.fromJson(Map<String, dynamic> json) {
    return AssignmentInfo(
      staffId: json['staff'] is String
          ? json['staff']
          : json['staff']?['_id'] ?? '',
      staff: json['staff'] is Map ? StaffInfo.fromJson(json['staff']) : null,
      assignedAt: json['assignedAt'] != null
          ? DateTime.parse(json['assignedAt'])
          : null,
      assignedBy: json['assignedBy'] is String
          ? json['assignedBy']
          : json['assignedBy']?['_id'],
      assignedByUser: json['assignedBy'] is Map
          ? UserInfo.fromJson(json['assignedBy'])
          : null,
    );
  }
}

class StaffInfo {
  final String id;
  final UserInfo? user;
  final List<String>? specialization;

  StaffInfo({
    required this.id,
    this.user,
    this.specialization,
  });

  factory StaffInfo.fromJson(Map<String, dynamic> json) {
    return StaffInfo(
      id: json['id'] ?? json['_id'] ?? '',
      user: json['user'] != null ? UserInfo.fromJson(json['user']) : null,
      specialization: json['specialization'] != null
          ? (json['specialization'] as List)
              .map<String>((e) => e['category']?.toString() ?? e.toString())
              .toList()
          : null,
    );
  }
}

class UserInfo {
  final String id;
  final String fullName;
  final String? phoneNumber;
  final String? profilePicture;
  final String? role;
  final String? wing;
  final String? flatNumber;

  UserInfo({
    required this.id,
    required this.fullName,
    this.phoneNumber,
    this.profilePicture,
    this.role,
    this.wing,
    this.flatNumber,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] ?? json['_id'] ?? '',
      fullName: json['fullName'] ?? '',
      phoneNumber: json['phoneNumber'],
      profilePicture: json['profilePicture']?['url'],
      role: json['role'],
      wing: json['wing'],
      flatNumber: json['flatNumber'],
    );
  }
}

class TimelineEntry {
  final String status;
  final String description;
  final String? updatedBy;
  final UserInfo? updatedByUser;
  final DateTime timestamp;

  TimelineEntry({
    required this.status,
    required this.description,
    this.updatedBy,
    this.updatedByUser,
    required this.timestamp,
  });

  factory TimelineEntry.fromJson(Map<String, dynamic> json) {
    return TimelineEntry(
      status: json['status'] ?? '',
      description: json['description'] ?? '',
      updatedBy: json['updatedBy'] is String
          ? json['updatedBy']
          : json['updatedBy']?['_id'],
      updatedByUser: json['updatedBy'] is Map
          ? UserInfo.fromJson(json['updatedBy'])
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}

class WorkUpdate {
  final String description;
  final List<ComplaintMedia> images;
  final String? updatedBy;
  final UserInfo? updatedByUser;
  final DateTime timestamp;

  WorkUpdate({
    required this.description,
    required this.images,
    this.updatedBy,
    this.updatedByUser,
    required this.timestamp,
  });

  factory WorkUpdate.fromJson(Map<String, dynamic> json) {
    return WorkUpdate(
      description: json['description'] ?? '',
      images: json['images'] != null
          ? (json['images'] as List)
              .map((e) => ComplaintMedia.fromJson(e))
              .toList()
          : [],
      updatedBy: json['updatedBy'] is String
          ? json['updatedBy']
          : json['updatedBy']?['_id'],
      updatedByUser: json['updatedBy'] is Map
          ? UserInfo.fromJson(json['updatedBy'])
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}

class ResolutionInfo {
  final String? description;
  final DateTime resolvedAt;
  final String? resolvedBy;
  final UserInfo? resolvedByUser;
  final List<ComplaintMedia> images;

  ResolutionInfo({
    this.description,
    required this.resolvedAt,
    this.resolvedBy,
    this.resolvedByUser,
    required this.images,
  });

  factory ResolutionInfo.fromJson(Map<String, dynamic> json) {
    return ResolutionInfo(
      description: json['description'],
      resolvedAt: DateTime.parse(json['resolvedAt']),
      resolvedBy: json['resolvedBy'] is String
          ? json['resolvedBy']
          : json['resolvedBy']?['_id'],
      resolvedByUser: json['resolvedBy'] is Map
          ? UserInfo.fromJson(json['resolvedBy'])
          : null,
      images: json['images'] != null
          ? (json['images'] as List)
              .map((e) => ComplaintMedia.fromJson(e))
              .toList()
          : [],
    );
  }
}

class RatingInfo {
  final int score;
  final String? comment;
  final DateTime ratedAt;

  RatingInfo({
    required this.score,
    this.comment,
    required this.ratedAt,
  });

  factory RatingInfo.fromJson(Map<String, dynamic> json) {
    return RatingInfo(
      score: json['score'] ?? 0,
      comment: json['comment'],
      ratedAt: DateTime.parse(json['ratedAt']),
    );
  }
}

class Comment {
  final String id;
  final String text;
  final String postedBy;
  final UserInfo? postedByUser;
  final DateTime postedAt;
  final List<ComplaintMedia> media;
  final bool isEdited;
  final DateTime? editedAt;

  Comment({
    required this.id,
    required this.text,
    required this.postedBy,
    this.postedByUser,
    required this.postedAt,
    required this.media,
    this.isEdited = false,
    this.editedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? json['_id'] ?? '',
      text: json['text'] ?? '',
      postedBy: json['postedBy'] is String
          ? json['postedBy']
          : json['postedBy']?['_id'] ?? '',
      postedByUser: json['postedBy'] is Map
          ? UserInfo.fromJson(json['postedBy'])
          : null,
      postedAt: json['postedAt'] != null
          ? DateTime.parse(json['postedAt'])
          : DateTime.now(),
      media: json['media'] != null
          ? (json['media'] as List)
              .map((e) => ComplaintMedia.fromJson(e))
              .toList()
          : [],
      isEdited: json['isEdited'] ?? false,
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'media': media.map((e) => e.toJson()).toList(),
    };
  }
}
