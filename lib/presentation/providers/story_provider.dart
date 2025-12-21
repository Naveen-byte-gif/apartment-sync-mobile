import 'package:flutter/foundation.dart';
import '../../core/services/story_service.dart';
import '../../data/models/telugu_story.dart';
import '../../core/constants/story_api_constants.dart';

class StoryProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _isGenerating = false;
  String? _error;
  
  List<TeluguStory> _stories = [];
  TeluguStory? _currentStory;
  String _selectedCategory = 'kids';

  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  List<TeluguStory> get stories => _stories;
  TeluguStory? get currentStory => _currentStory;
  String get selectedCategory => _selectedCategory;
  
  List<String> get categories => StoryApiConstants.categories;

  /// Generate a new story (category can be null for random)
  Future<TeluguStory?> generateStory([String? category]) async {
    _isGenerating = true;
    _error = null;
    if (category != null) {
      _selectedCategory = category;
    }
    notifyListeners();

    try {
      final story = await StoryService.generateStory(category);
      _currentStory = story;
      _stories.insert(0, story); // Add to beginning of list
      
      // Keep only last 50 stories
      if (_stories.length > 50) {
        _stories = _stories.take(50).toList();
      }
      
      if (kDebugMode) {
        print('✅ [STORY] Generated story: ${story.title}');
      }
      
      return story;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('❌ [STORY] Error generating story: $e');
      }
      return null;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Generate random story
  Future<TeluguStory?> generateRandomStory() async {
    return generateStory(null);
  }

  /// Generate multiple alternative stories
  Future<List<TeluguStory>> generateAlternativeStories(String category, {int count = 3}) async {
    _isGenerating = true;
    _error = null;
    notifyListeners();

    try {
      final stories = await StoryService.generateAlternativeStories(category, count: count);
      _stories.insertAll(0, stories);
      
      // Keep only last 50 stories
      if (_stories.length > 50) {
        _stories = _stories.take(50).toList();
      }
      
      return stories;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('❌ [STORY] Error generating alternative stories: $e');
      }
      return [];
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Set selected category
  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Set current story for viewing
  void setCurrentStory(TeluguStory story) {
    _currentStory = story;
    notifyListeners();
  }

  /// Clear current story
  void clearCurrentStory() {
    _currentStory = null;
    notifyListeners();
  }

  /// Clear all stories
  void clearAllStories() {
    _stories.clear();
    _currentStory = null;
    notifyListeners();
  }

  /// Get stories by category
  List<TeluguStory> getStoriesByCategory(String category) {
    return _stories.where((s) => s.category == category).toList();
  }
}

