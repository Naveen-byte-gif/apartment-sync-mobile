class StoryApiConstants {
  // Story Generation API
  static const String storyApiBaseUrl = 'https://api.storyhub.ai/v1';
  
  /// Story Generation API Key
  /// This key is used for generating Telugu stories
  static const String storyApiKey = String.fromEnvironment(
    'STORY_API_KEY',
    defaultValue: '72a2be79283049edb6341252e777d6bc.haNaYtNxPajWzHQ9BzOhOuCL--key',
  );

  static String generateStoryUrl() => '$storyApiBaseUrl/stories/generate';

  // Story Categories
  static const List<String> categories = [
    'kids',
    'love',
    'moral',
    'family',
    'devotional',
    'motivational',
  ];

  static String getCategoryLabel(String category) {
    switch (category) {
      case 'kids':
        return 'పిల్లల కథలు';
      case 'love':
        return 'ప్రేమ కథలు';
      case 'moral':
        return 'నీతి కథలు';
      case 'family':
        return 'కుటుంబ కథలు';
      case 'devotional':
        return 'భక్తి కథలు';
      case 'motivational':
        return 'ప్రేరణ కథలు';
      default:
        return 'కథలు';
    }
  }
}

