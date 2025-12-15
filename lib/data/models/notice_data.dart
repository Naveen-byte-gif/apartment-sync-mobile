class NoticeData {
  final String id;
  final String title;
  final String content;
  final String category;
  final String priority;
  final bool requiresAcknowledgement;
  final DateTime createdAt;
  final DateTime? effectiveDate;
  final String? createdByName;

  NoticeData({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.priority,
    required this.requiresAcknowledgement,
    required this.createdAt,
    this.effectiveDate,
    this.createdByName,
  });

  factory NoticeData.fromJson(Map<String, dynamic> json) {
    return NoticeData(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? '',
      priority: json['priority'] ?? '',
      requiresAcknowledgement: json['requiresAcknowledgement'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      effectiveDate: json['effectiveDate'] != null
          ? DateTime.parse(json['effectiveDate'])
          : null,
      createdByName: json['createdBy'] is Map<String, dynamic>
          ? (json['createdBy'] as Map<String, dynamic>)['fullName'] as String?
          : null,
    );
  }
}
