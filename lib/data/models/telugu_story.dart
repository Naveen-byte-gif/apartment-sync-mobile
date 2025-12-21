class TeluguStory {
  final String id;
  final String title;
  final String content;
  final String moral;
  final String category;
  final String? imageUrl;
  final DateTime createdAt;

  TeluguStory({
    required this.id,
    required this.title,
    required this.content,
    required this.moral,
    required this.category,
    this.imageUrl,
    required this.createdAt,
  });

  factory TeluguStory.fromJson(Map<String, dynamic> json) {
    return TeluguStory(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? json['story'] as String? ?? '',
      moral: json['moral'] as String? ?? json['neeti'] as String? ?? '',
      category: json['category'] as String? ?? 'kids',
      imageUrl: json['imageUrl'] as String? ?? json['image'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'moral': moral,
      'category': category,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get wordCount {
    final words = content.split(RegExp(r'\s+'));
    return words.length.toString();
  }
}

