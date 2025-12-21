import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/news_service.dart';
import '../../data/models/news_article.dart';
import '../../data/models/cricket_match.dart';

class NewsProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _isCricketLoading = false;
  String? _error;

  List<NewsArticle> _topNews = [];
  List<NewsArticle> _healthNews = [];
  List<NewsArticle> _sportsNews = [];
  List<NewsArticle> _whoHealth = [];

  List<CricketMatch> _liveMatches = [];
  List<CricketMatch> _upcomingMatches = [];

  Timer? _liveCricketTimer;

  bool get isLoading => _isLoading;
  bool get isCricketLoading => _isCricketLoading;
  String? get error => _error;

  List<NewsArticle> get topNews => _topNews;
  List<NewsArticle> get healthNews => _healthNews;
  List<NewsArticle> get sportsNews => _sportsNews;
  List<NewsArticle> get whoHealth => _whoHealth;

  List<CricketMatch> get liveMatches => _liveMatches;
  List<CricketMatch> get upcomingMatches => _upcomingMatches;

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        NewsService.fetchTopNews(),
        NewsService.fetchHealthNews(),
        NewsService.fetchSportsNews(),
        NewsService.fetchWhoHealthRss(),
      ]);
      _topNews = results[0] as List<NewsArticle>;
      _healthNews = results[1] as List<NewsArticle>;
      _sportsNews = results[2] as List<NewsArticle>;
      _whoHealth = results[3] as List<NewsArticle>;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('❌ [NEWS] Error loading news: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCricket({bool startAutoRefresh = false}) async {
    _isCricketLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        NewsService.fetchLiveMatches(),
        NewsService.fetchUpcomingMatches(),
      ]);
      _liveMatches = results[0] as List<CricketMatch>;
      _upcomingMatches = results[1] as List<CricketMatch>;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [NEWS] Error loading cricket data: $e');
      }
    } finally {
      _isCricketLoading = false;
      notifyListeners();
    }

    if (startAutoRefresh && _liveCricketTimer == null) {
      _liveCricketTimer = Timer.periodic(
        const Duration(seconds: 45),
        (_) => loadCricket(),
      );
    }
  }

  @override
  void dispose() {
    _liveCricketTimer?.cancel();
    super.dispose();
  }
}


