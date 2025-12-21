class NewsArticle {
  final String title;
  final String? description;
  final String? url;
  final String? imageUrl;
  final String? source;
  final DateTime? publishedAt;
  final String? category;

  NewsArticle({
    required this.title,
    this.description,
    this.url,
    this.imageUrl,
    this.source,
    this.publishedAt,
    this.category,
  });

  factory NewsArticle.fromNewsApiJson(
    Map<String, dynamic> json, {
    String? category,
  }) {
    return NewsArticle(
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      url: json['url'] as String?,
      imageUrl: json['urlToImage'] as String?,
      source: (json['source'] as Map<String, dynamic>?)?['name'] as String?,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      category: category,
    );
  }
}


