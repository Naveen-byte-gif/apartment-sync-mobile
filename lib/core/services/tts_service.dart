import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;
  static bool _isSpeaking = false;
  static VoidCallback? _onComplete;
  static String _currentLanguage = 'en-US'; // Default fallback

  static bool get isSpeaking => _isSpeaking;
  static bool get isInitialized => _isInitialized;

  /// Initialize TTS service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if plugin is available by trying a simple operation
      try {
        // Get available languages
        final languages = await _flutterTts.getLanguages;
        if (kDebugMode) {
          print('🔊 [TTS] Available languages: $languages');
        }

        // Try to set Telugu language, fallback to English if not available
        String selectedLanguage = 'en-US'; // Default fallback
        if (languages != null && languages.isNotEmpty) {
          if (languages.contains('te-IN')) {
            selectedLanguage = 'te-IN';
          } else if (languages.contains('te')) {
            selectedLanguage = 'te';
          } else if (languages.contains('hi-IN')) {
            selectedLanguage = 'hi-IN'; // Hindi as fallback
          } else if (languages.contains('en-US')) {
            selectedLanguage = 'en-US';
          } else {
            selectedLanguage = languages.first;
          }
        }

        _currentLanguage = selectedLanguage;
        await _flutterTts.setLanguage(selectedLanguage);
        
        if (kDebugMode) {
          print('🔊 [TTS] Language set to: $selectedLanguage');
        }
      } catch (e) {
        // If getLanguages fails, try with default language
        if (kDebugMode) {
          print('⚠️ [TTS] Could not get languages, using default: $e');
        }
        _currentLanguage = 'en-US';
        try {
          await _flutterTts.setLanguage('en-US');
        } catch (e2) {
          // If setLanguage also fails, plugin might not be available
          throw Exception('TTS plugin not available: $e2');
        }
      }

      // Set speech parameters - MAXIMUM VOLUME
      await _flutterTts.setSpeechRate(0.5); // Normal speed (0.0 to 1.0)
      await _flutterTts.setVolume(1.0); // Maximum volume (0.0 to 1.0)
      await _flutterTts.setPitch(1.0); // Normal pitch (0.5 to 2.0)

      // Platform-specific settings
      if (Platform.isAndroid) {
        try {
          await _flutterTts.setSilence(0); // No silence
          await _flutterTts.awaitSpeakCompletion(true);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ [TTS] Android-specific settings failed: $e');
          }
        }
      } else if (Platform.isIOS) {
        try {
          await _flutterTts.awaitSpeakCompletion(true);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ [TTS] iOS-specific settings failed: $e');
          }
        }
      }

      // Set completion handler
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        if (kDebugMode) {
          print('✅ [TTS] Speech completed');
        }
        _onComplete?.call();
        _onComplete = null;
      });

      // Set error handler
      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        if (kDebugMode) {
          print('❌ [TTS] Error: $msg');
        }
        _onComplete?.call();
        _onComplete = null;
      });

      // Set start handler
      _flutterTts.setStartHandler(() {
        if (kDebugMode) {
          print('🔊 [TTS] Speech started');
        }
      });

      _isInitialized = true;
      if (kDebugMode) {
        print('✅ [TTS] Initialized successfully with language: $_currentLanguage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [TTS] Initialization error: $e');
        print('⚠️ [TTS] TTS plugin may not be properly linked. Please rebuild the app.');
      }
      // Don't set _isInitialized = true if initialization failed
      // This will prevent speak() from being called
    }
  }

  /// Speak text with optional completion callback
  static Future<void> speak(String text, {VoidCallback? onComplete}) async {
    // Ensure initialization
    if (!_isInitialized) {
      await initialize();
    }

    // Check if initialization was successful
    if (!_isInitialized) {
      if (kDebugMode) {
        print('❌ [TTS] Cannot speak - TTS not initialized. Plugin may not be available.');
        print('💡 [TTS] Please rebuild the app: flutter clean && flutter pub get && flutter run');
      }
      // Call onComplete immediately since we can't speak
      onComplete?.call();
      return;
    }

    try {
      // Always stop any current speech before starting new one
      if (_isSpeaking) {
        await stop();
        // Wait for stop to complete
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Ensure volume is at maximum before speaking
      await _flutterTts.setVolume(1.0);
      
      _onComplete = onComplete;
      _isSpeaking = true;
      
      // Clean text - remove extra spaces and normalize
      final cleanText = text
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'\.{2,}'), '.')
          .replaceAll(RegExp(r'[^\w\s\.\,\!\?\-]'), '') // Remove special chars that might cause issues
          .trim();
      
      if (cleanText.isEmpty) {
        if (kDebugMode) {
          print('⚠️ [TTS] Text is empty after cleaning');
        }
        _isSpeaking = false;
        onComplete?.call();
        return;
      }
      
      if (kDebugMode) {
        print('🔊 [TTS] Speaking (${cleanText.length} chars): ${cleanText.substring(0, cleanText.length > 100 ? 100 : cleanText.length)}...');
        print('🔊 [TTS] Language: $_currentLanguage, Volume: 1.0, Rate: 0.5');
      }
      
      // Speak the text
      final result = await _flutterTts.speak(cleanText);
      
      if (result == 1) {
        // Success
        if (kDebugMode) {
          print('✅ [TTS] Speak command sent successfully');
        }
      } else {
        // Failed to start
        _isSpeaking = false;
        if (kDebugMode) {
          print('❌ [TTS] Failed to start speaking. Result: $result');
        }
        onComplete?.call();
      }
    } catch (e) {
      _isSpeaking = false;
      _onComplete = null;
      if (kDebugMode) {
        print('❌ [TTS] Speak error: $e');
        print('❌ [TTS] Error type: ${e.runtimeType}');
      }
      // Call onComplete even on error
      onComplete?.call();
    }
  }

  /// Stop speaking
  static Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      _onComplete = null;
      if (kDebugMode) {
        print('⏹️ [TTS] Stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [TTS] Stop error: $e');
      }
    }
  }

  /// Pause speaking
  static Future<void> pause() async {
    try {
      await _flutterTts.pause();
      if (kDebugMode) {
        print('⏸️ [TTS] Paused');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [TTS] Pause error: $e');
      }
    }
  }
}

