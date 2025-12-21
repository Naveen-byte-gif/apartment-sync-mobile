class NewsApiConstants {
  // NewsAPI.org
  static const String newsApiBaseUrl = 'https://newsapi.org/v2';

  /// TODO: Put your NewsAPI.org key here for development/testing.
  /// Free tier: 100 requests/day (non-commercial).
  static const String newsApiKey = String.fromEnvironment(
    'NEWS_API_KEY',
    defaultValue: 'd46649aa81164fbc94607e261fe84b7e',
  );

  static String topHeadlinesIndia() =>
      '$newsApiBaseUrl/top-headlines?country=in&pageSize=30';

  static String healthNewsIndia() =>
      '$newsApiBaseUrl/top-headlines?country=in&category=health&pageSize=30';

  static String sportsNewsIndia() =>
      '$newsApiBaseUrl/top-headlines?country=in&category=sports&pageSize=30';

  // WHO RSS feeds for health news
  static const String whoHealthRss =
      'https://www.who.int/rss-feeds/news-english.xml';

  // Cricket APIs (MVP / free-tier friendly)
  static const String cricketBaseUrl = 'https://api.cricapi.com/v1';

  /// TODO: Put your CricAPI key here if you register for a free key.
  static const String cricketApiKey = String.fromEnvironment(
    'CRICKET_API_KEY',
    defaultValue: '',
  );

  static String liveMatches() =>
      '$cricketBaseUrl/currentMatches?apikey=$cricketApiKey&offset=0';

  static String upcomingMatches() =>
      '$cricketBaseUrl/matches?apikey=$cricketApiKey&offset=0';
}


