import 'package:flutter/foundation.dart';
import '../../core/services/tts_service.dart';

class TtsProvider with ChangeNotifier {
  bool _isSpeaking = false;
  bool _isPaused = false;
  String? _currentStoryId;

  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  String? get currentStoryId => _currentStoryId;

  bool _isInitialized = false;
  bool _isAvailable = false;

  bool get isAvailable => _isAvailable;

  TtsProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await TtsService.initialize();
      _isInitialized = true;
      _isAvailable = TtsService.isInitialized;
      if (kDebugMode) {
        if (_isAvailable) {
          print('✅ [TTS Provider] Initialized and available');
        } else {
          print('⚠️ [TTS Provider] Initialized but TTS not available');
        }
      }
    } catch (e) {
      _isAvailable = false;
      if (kDebugMode) {
        print('❌ [TTS Provider] Initialization error: $e');
      }
    }
  }

  /// Speak story text
  Future<void> speakStory({
    required String storyId,
    required String title,
    required String content,
    required String moral,
  }) async {
    // Ensure TTS is initialized
    if (!_isInitialized) {
      await _initialize();
      // Wait a bit for initialization
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Check if TTS is available
    if (!_isAvailable || !TtsService.isInitialized) {
      if (kDebugMode) {
        print('❌ [TTS Provider] TTS not available. Please rebuild the app.');
      }
      // Don't set speaking state if TTS is not available
      return;
    }

    // Stop any current speech
    if (_isSpeaking && _currentStoryId != storyId) {
      await stop();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // If same story is already speaking, stop it
    if (_isSpeaking && _currentStoryId == storyId) {
      await stop();
      return;
    }

    // Format text properly for TTS
    final fullText = '$title. $content. నీతి: $moral';
    
    _isSpeaking = true;
    _isPaused = false;
    _currentStoryId = storyId;
    notifyListeners();

    if (kDebugMode) {
      print('🔊 [TTS Provider] Starting to speak story: $storyId');
    }

    await TtsService.speak(fullText, onComplete: () {
      if (kDebugMode) {
        print('✅ [TTS Provider] Story completed: $storyId');
      }
      _isSpeaking = false;
      _isPaused = false;
      _currentStoryId = null;
      notifyListeners();
    });
  }

  /// Stop speaking
  Future<void> stop() async {
    await TtsService.stop();
    _isSpeaking = false;
    _isPaused = false;
    _currentStoryId = null;
    notifyListeners();
  }

  /// Pause speaking
  Future<void> pause() async {
    if (_isSpeaking && !_isPaused) {
      await TtsService.pause();
      _isPaused = true;
      notifyListeners();
    }
  }

  /// Resume speaking
  Future<void> resume() async {
    if (_isPaused) {
      // Note: Flutter TTS doesn't have direct resume, so we need to handle this differently
      _isPaused = false;
      notifyListeners();
    }
  }

  /// Check if a specific story is being read
  bool isStoryBeingRead(String storyId) {
    return _isSpeaking && _currentStoryId == storyId;
  }
}

