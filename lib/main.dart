import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/storage_service.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/socket_service.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/providers/auth_provider.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📨 Background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (optional - app can run without it)
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
    
    // Set background message handler only if Firebase is initialized
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    print('⚠️ Firebase initialization failed: $e');
    print('⚠️ App will continue without Firebase. Please configure Firebase when ready.');
  }
  
  // Initialize services
  await StorageService.init();
  await ApiService.init();
  
  // Initialize notifications (will handle Firebase errors internally)
  try {
    await NotificationService.initialize();
  } catch (e) {
    print('⚠️ Notification service initialization failed: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'ApartmentSync',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
