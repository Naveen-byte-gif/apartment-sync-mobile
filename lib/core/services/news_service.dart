import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../constants/news_api_constants.dart';
import '../../data/models/news_article.dart';
import '../../data/models/cricket_match.dart';

class NewsService {
  NewsService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  static Future<List<NewsArticle>> fetchTopNews() async {
    if (NewsApiConstants.newsApiKey.isEmpty) {
      return [];
    }
    final response = await _dio.get(
      NewsApiConstants.topHeadlinesIndia(),
      options: Options(headers: {'X-Api-Key': NewsApiConstants.newsApiKey}),
    );
    final data = response.data as Map<String, dynamic>;
    final articles = data['articles'] as List<dynamic>? ?? [];
    return articles
        .map(
          (e) => NewsArticle.fromNewsApiJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  static Future<List<NewsArticle>> fetchHealthNews() async {
    if (NewsApiConstants.newsApiKey.isEmpty) {
      return [];
    }
    final response = await _dio.get(
      NewsApiConstants.healthNewsIndia(),
      options: Options(headers: {'X-Api-Key': NewsApiConstants.newsApiKey}),
    );
    final data = response.data as Map<String, dynamic>;
    final articles = data['articles'] as List<dynamic>? ?? [];
    return articles
        .map(
          (e) => NewsArticle.fromNewsApiJson(
            Map<String, dynamic>.from(e as Map),
            category: 'health',
          ),
        )
        .toList();
  }

  static Future<List<NewsArticle>> fetchSportsNews() async {
    if (NewsApiConstants.newsApiKey.isEmpty) {
      return [];
    }
    try {
      // Use IPL/Cricket specific API
      final cricketResponse = await _dio.get(
        'https://newsapi.org/v2/everything?q=IPL+cricket&sortBy=publishedAt&language=en&apiKey=${NewsApiConstants.newsApiKey}',
        options: Options(headers: {'X-Api-Key': NewsApiConstants.newsApiKey}),
      );
      final cricketData = cricketResponse.data as Map<String, dynamic>;
      final cricketArticles = cricketData['articles'] as List<dynamic>? ?? [];
      
      if (cricketArticles.isNotEmpty) {
        return cricketArticles
            .map(
              (e) => NewsArticle.fromNewsApiJson(
                Map<String, dynamic>.from(e as Map),
                category: 'sports',
              ),
            )
            .toList();
      }
    } catch (e) {
      print('Error fetching cricket news: $e');
    }
    
    // Fallback to general sports news
    try {
      final response = await _dio.get(
        NewsApiConstants.sportsNewsIndia(),
        options: Options(headers: {'X-Api-Key': NewsApiConstants.newsApiKey}),
      );
      final data = response.data as Map<String, dynamic>;
      final articles = data['articles'] as List<dynamic>? ?? [];
      return articles
          .map(
            (e) => NewsArticle.fromNewsApiJson(
              Map<String, dynamic>.from(e as Map),
              category: 'sports',
            ),
          )
          .toList();
    } catch (e) {
      print('Error fetching sports news: $e');
      return [];
    }
  }

  static Future<List<NewsArticle>> fetchWhoHealthRss() async {
    final response = await _dio.get<String>(NewsApiConstants.whoHealthRss);
    final document = XmlDocument.parse(response.data ?? '');
    final items = document.findAllElements('item');
    return items.map((node) {
      final title = node.getElement('title')?.text ?? 'WHO Update';
      final link = node.getElement('link')?.text;
      final description = node.getElement('description')?.text;
      final pubDate = node.getElement('pubDate')?.text;
      DateTime? publishedAt;
      if (pubDate != null) {
        publishedAt = DateTime.tryParse(pubDate);
      }
      return NewsArticle(
        title: title,
        description: description,
        url: link,
        source: 'WHO',
        publishedAt: publishedAt,
        category: 'health',
      );
    }).toList();
  }

  static Future<List<CricketMatch>> fetchLiveMatches() async {
    if (NewsApiConstants.cricketApiKey.isEmpty) {
      return [];
    }
    final response = await _dio.get(NewsApiConstants.liveMatches());
    final data = response.data as Map<String, dynamic>;
    final matches = data['data'] as List<dynamic>? ?? [];
    final parsed = matches
        .map(
          (e) => CricketMatch.fromCricApiJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    parsed.sort((a, b) {
      if (a.isIndiaMatch == b.isIndiaMatch) return 0;
      return a.isIndiaMatch ? -1 : 1;
    });
    return parsed;
  }

  static Future<List<CricketMatch>> fetchUpcomingMatches() async {
    if (NewsApiConstants.cricketApiKey.isEmpty) {
      return [];
    }
    final response = await _dio.get(NewsApiConstants.upcomingMatches());
    final data = response.data as Map<String, dynamic>;
    final matches = data['data'] as List<dynamic>? ?? [];
    return matches
        .map(
          (e) => CricketMatch.fromCricApiJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }
}


