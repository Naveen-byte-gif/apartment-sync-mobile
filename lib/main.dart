import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/storage_service.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/tts_service.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/news_provider.dart';
import 'presentation/providers/story_provider.dart';
import 'presentation/providers/tts_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up error handling to catch and log errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('❌ [FLUTTER ERROR] ${details.exception}');
    print('❌ [FLUTTER ERROR] Stack: ${details.stack}');
  };

  // CRITICAL: Register background message handler BEFORE runApp
  // This must be done at the top level before any isolate is created
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  print('✅ [MAIN] Background message handler registered');

  // Initialize CRITICAL services that UI needs (fast, shouldn't block)
  print('🔧 [MAIN] Initializing critical services...');
  try {
    await StorageService.init();
    print('✅ StorageService initialized');
  } catch (e) {
    print('⚠️ StorageService initialization failed: $e');
  }

  try {
    await ApiService.init();
    print('✅ ApiService initialized');
  } catch (e) {
    print('⚠️ ApiService initialization failed: $e');
  }

  // Initialize Firebase BEFORE runApp (required for FCM)
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('⚠️ Firebase initialization failed: $e');
    print(
      '⚠️ App will continue without Firebase. Please configure Firebase when ready.',
    );
  }

  // CRITICAL: Call runApp IMMEDIATELY after critical services
  // Notification service will initialize in background
  print('🎬 [MAIN] About to call runApp');
  runApp(const MyApp());
  print('✅ [MAIN] runApp called successfully');

  // Initialize notification service AFTER UI is shown (non-blocking)
  _initializeNotificationServiceInBackground();
}

Future<void> _initializeNotificationServiceInBackground() async {
  print('🔧 [MAIN] Starting notification service initialization...');
  
  // Initialize notifications (will handle Firebase errors internally)
  try {
    await NotificationService.initialize();
    print('✅ NotificationService initialized');
  } catch (e) {
    print('⚠️ Notification service initialization failed: $e');
  }

  print('✅ [MAIN] Notification service initialization completed');
  
  // Initialize TTS service in background
  try {
    await TtsService.initialize();
    print('✅ TTS service initialized');
  } catch (e) {
    print('⚠️ TTS service initialization failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('🏗️ [MyApp] BUILD called - creating widget tree');
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            print('🔧 [MyApp] Creating AuthProvider');
            return AuthProvider();
          },
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) {
            print('🔧 [MyApp] Creating NewsProvider');
            return NewsProvider();
          },
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) {
            print('🔧 [MyApp] Creating StoryProvider');
            return StoryProvider();
          },
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) {
            print('🔧 [MyApp] Creating TtsProvider');
            try {
              return TtsProvider();
            } catch (e) {
              print('❌ [MyApp] Error creating TtsProvider: $e');
              // Return a minimal provider if creation fails
              return TtsProvider();
            }
          },
          lazy: true,
        ),
      ],
      child: MaterialApp(
        title: 'ApartmentSync',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: NotificationService.navigatorKey,
        home: const SplashScreen(),
        builder: (context, child) {
          print('🎨 [MyApp] MaterialApp builder called');
          // Ensure child is never null
          if (child == null) {
            print('⚠️ [MyApp] Child is null, returning SplashScreen');
            return const SplashScreen();
          }
          // Wrap with MediaQuery to control text scaling
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: child,
          );
        },
      ),
    );
  }
}
