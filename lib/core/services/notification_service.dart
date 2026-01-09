import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'storage_service.dart';
import '../constants/api_constants.dart';
import '../utils/notification_navigator.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Global navigator key for deep linking from terminated state
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Check FCM connection status
  static Future<Map<String, dynamic>> checkConnectionStatus() async {
    print('\n🔍 ========== [FLUTTER FCM] CONNECTION STATUS CHECK ==========');
    final status = <String, dynamic>{
      'firebaseInitialized': false,
      'permissionGranted': false,
      'tokenAvailable': false,
      'tokenSentToBackend': false,
      'token': null,
      'permissionStatus': null,
      'errors': <String>[],
    };

    try {
      // Check Firebase Core
      print('🔍 [FCM STATUS] Checking Firebase Core initialization...');
      try {
        final firebaseApp = Firebase.app();
        status['firebaseInitialized'] = true;
        status['firebaseAppName'] = firebaseApp.name;
        print(
          '✅ [FCM STATUS] Firebase Core is initialized: ${firebaseApp.name}',
        );
      } catch (e) {
        status['errors'].add('Firebase Core not initialized: $e');
        print('❌ [FCM STATUS] Firebase Core NOT initialized: $e');
      }

      // Check FCM permission
      print('🔍 [FCM STATUS] Checking notification permission...');
      try {
        final settings = await _firebaseMessaging.getNotificationSettings();
        status['permissionStatus'] = settings.authorizationStatus.toString();
        status['permissionGranted'] =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        print(
          '📱 [FCM STATUS] Permission status: ${settings.authorizationStatus}',
        );
        print('📱 [FCM STATUS] Alert enabled: ${settings.alert}');
        print('📱 [FCM STATUS] Badge enabled: ${settings.badge}');
        print('📱 [FCM STATUS] Sound enabled: ${settings.sound}');

        if (status['permissionGranted']) {
          print('✅ [FCM STATUS] Notification permission GRANTED');
        } else {
          print('❌ [FCM STATUS] Notification permission DENIED');
          status['errors'].add('Notification permission denied');
        }
      } catch (e) {
        status['errors'].add('Failed to check permission: $e');
        print('❌ [FCM STATUS] Error checking permission: $e');
      }

      // Check FCM token
      print('🔍 [FCM STATUS] Checking FCM token...');
      try {
        final token = await _firebaseMessaging.getToken();
        if (token != null && token.isNotEmpty) {
          status['tokenAvailable'] = true;
          status['token'] = token;
          status['tokenLength'] = token.length;
          print('✅ [FCM STATUS] FCM token is AVAILABLE');
          print('✅ [FCM STATUS] Token length: ${token.length}');
          print(
            '✅ [FCM STATUS] Token preview: ${token.substring(0, min(50, token.length))}...',
          );
        } else {
          status['errors'].add('FCM token is null or empty');
          print('❌ [FCM STATUS] FCM token is NULL or EMPTY');
        }
      } catch (e) {
        status['errors'].add('Failed to get token: $e');
        print('❌ [FCM STATUS] Error getting token: $e');
      }

      // Check if token sent to backend
      print('🔍 [FCM STATUS] Checking if token sent to backend...');
      try {
        final authToken = ApiService.token;
        if (authToken != null && authToken.isNotEmpty) {
          final pendingToken = StorageService.getString('pending_fcm_token');
          status['tokenSentToBackend'] = pendingToken == null;
          if (pendingToken != null) {
            status['errors'].add(
              'Token pending (not authenticated when token was received)',
            );
            print(
              '⚠️ [FCM STATUS] Token is PENDING (stored locally, waiting for auth)',
            );
          } else {
            print(
              '✅ [FCM STATUS] Token sent to backend (no pending token found)',
            );
          }
        } else {
          status['errors'].add(
            'User not authenticated - cannot verify backend token',
          );
          print(
            '⚠️ [FCM STATUS] User not authenticated - cannot verify backend token status',
          );
        }
      } catch (e) {
        status['errors'].add('Error checking backend token: $e');
        print('❌ [FCM STATUS] Error checking backend token: $e');
      }

      // Overall status
      final isConnected =
          status['firebaseInitialized'] == true &&
          status['permissionGranted'] == true &&
          status['tokenAvailable'] == true;

      status['isConnected'] = isConnected;

      print('\n📊 [FCM STATUS] ========== CONNECTION SUMMARY ==========');
      print(
        '📊 [FCM STATUS] Firebase Initialized: ${status['firebaseInitialized']}',
      );
      print(
        '📊 [FCM STATUS] Permission Granted: ${status['permissionGranted']}',
      );
      print('📊 [FCM STATUS] Token Available: ${status['tokenAvailable']}');
      print(
        '📊 [FCM STATUS] Token Sent to Backend: ${status['tokenSentToBackend']}',
      );
      print(
        '📊 [FCM STATUS] Overall Status: ${isConnected ? "✅ CONNECTED" : "❌ NOT CONNECTED"}',
      );

      if (status['errors'].isNotEmpty) {
        print('📊 [FCM STATUS] Errors found: ${status['errors'].length}');
        for (var error in status['errors']) {
          print('   ⚠️ $error');
        }
      }

      print('📊 [FCM STATUS] ==========================================\n');

      return status;
    } catch (e, stackTrace) {
      print('❌ [FCM STATUS] Exception during status check: $e');
      print('❌ [FCM STATUS] Stack: $stackTrace');
      status['errors'].add('Exception during status check: $e');
      return status;
    }
  }

  static Future<void> initialize() async {
    print('\n🔧 ========== [FLUTTER FCM] INITIALIZATION START ==========');
    print('🔧 [FLUTTER FCM] Timestamp: ${DateTime.now().toIso8601String()}');

    // Check Firebase Core first
    try {
      final firebaseApp = Firebase.app();
      print(
        '✅ [FLUTTER FCM] Firebase Core is initialized: ${firebaseApp.name}',
      );
    } catch (e) {
      print('❌ [FLUTTER FCM] CRITICAL: Firebase Core NOT initialized!');
      print('❌ [FLUTTER FCM] Error: $e');
      print('❌ [FLUTTER FCM] FCM will not work without Firebase Core');
      print(
        '❌ [FLUTTER FCM] Check: Is Firebase.initializeApp() called in main()?',
      );
      return;
    }

    try {
      // Request permission (handles Android 13+ POST_NOTIFICATIONS automatically)
      print('🔧 [FLUTTER FCM] Requesting notification permission...');
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false, // Explicit permission required
          );

      print('📱 [FLUTTER FCM] Permission request completed');
      print(
        '📱 [FLUTTER FCM] Authorization status: ${settings.authorizationStatus}',
      );
      print('📱 [FLUTTER FCM] Alert: ${settings.alert}');
      print('📱 [FLUTTER FCM] Badge: ${settings.badge}');
      print('📱 [FLUTTER FCM] Sound: ${settings.sound}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ [FLUTTER FCM] User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print(
          '⚠️ [FLUTTER FCM] User granted provisional notification permission',
        );
      } else {
        print('❌ [FLUTTER FCM] User DENIED notification permission');
        print('❌ [FLUTTER FCM] FCM will not work without permission');
      }
    } catch (e, stackTrace) {
      print('❌ [FLUTTER FCM] Permission request failed: $e');
      print('❌ [FLUTTER FCM] Stack: $stackTrace');
      // Continue without Firebase messaging
    }

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create high-importance notification channel for Android (required for Android 8.0+)
    // This must be done early to ensure notifications can be displayed
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'apartmentsync_notifications',
              'ApartmentSync Notifications',
              description: 'Notifications from ApartmentSync',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
              showBadge: true,
            ),
          );
      print('✅ Notification channel created with high importance');
    } catch (e) {
      print('⚠️ Error creating notification channel: $e');
    }

    try {
      print('\n📱 ========== [FLUTTER FCM] INITIALIZATION ==========');
      print('📱 [FLUTTER FCM] Requesting FCM token from Firebase...');

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();

      if (token != null) {
        print('✅ [FLUTTER FCM] SUCCESS: FCM token received from Firebase');
        print('✅ [FLUTTER FCM] Token length: ${token.length}');
        print(
          '✅ [FLUTTER FCM] Token preview: ${token.substring(0, min(50, token.length))}...',
        );
        print('✅ [FLUTTER FCM] Full token: $token');
        // Send token to backend
        await _sendTokenToBackend(token);
      } else {
        print('❌ [FLUTTER FCM] ERROR: Failed to get FCM token from Firebase');
        print('❌ [FLUTTER FCM] Token is null');
        print('📱 [FLUTTER FCM] Check: Is Firebase properly configured?');
        print(
          '📱 [FLUTTER FCM] Check: Is google-services.json/GoogleService-Info.plist present?',
        );
      }

      // Listen for token refresh
      print('🔧 [FLUTTER FCM] Setting up token refresh listener...');
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('\n🔄 ========== [FLUTTER FCM] TOKEN REFRESH ==========');
        print(
          '🔄 [FLUTTER FCM] New token received: ${newToken.substring(0, min(50, newToken.length))}...',
        );
        print('🔄 [FLUTTER FCM] Token length: ${newToken.length}');
        // Only send if user is authenticated
        _sendTokenToBackend(newToken);
        print(
          '🔄 ========== [FLUTTER FCM] TOKEN REFRESH COMPLETE ==========\n',
        );
      });
      print('✅ [FLUTTER FCM] Token refresh listener registered');

      // Handle foreground messages (app is open)
      print('🔧 [FLUTTER FCM] Setting up foreground message listener...');
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      print('✅ [FLUTTER FCM] Foreground message listener registered');

      // Handle background/terminated messages (app opened from notification)
      print('🔧 [FLUTTER FCM] Setting up background message listener...');
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      print('✅ [FLUTTER FCM] Background message listener registered');

      // Check if app was opened from terminated state
      print('🔧 [FLUTTER FCM] Checking for initial message...');
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print(
          '📱 [FLUTTER FCM] App opened from terminated state via notification',
        );
        _handleTerminatedMessage(initialMessage);
      } else {
        print('ℹ️ [FLUTTER FCM] No initial message (app started normally)');
      }

      print('✅ [FLUTTER FCM] All listeners registered successfully');
      print('🔧 ========== [FLUTTER FCM] INITIALIZATION COMPLETE ==========\n');

      // Print final connection status
      await Future.delayed(const Duration(milliseconds: 500));
      await checkConnectionStatus();
    } catch (e, stackTrace) {
      print('\n❌ ========== [FLUTTER FCM] INITIALIZATION FAILED ==========');
      print('❌ [FLUTTER FCM] Error: $e');
      print('❌ [FLUTTER FCM] Stack trace: $stackTrace');
      print(
        '❌ [FLUTTER FCM] Push notifications will not work until this is fixed',
      );
      print('❌ ========== [FLUTTER FCM] INITIALIZATION ERROR ==========\n');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    print('\n📱 ========== [FLUTTER FCM] SEND TOKEN TO BACKEND ==========');
    print('📱 [FLUTTER FCM] Timestamp: ${DateTime.now().toIso8601String()}');
    print('📱 [FLUTTER FCM] Token length: ${token.length}');
    print(
      '📱 [FLUTTER FCM] Token preview: ${token.substring(0, min(50, token.length))}...',
    );

    try {
      // Only send token if user is authenticated
      final authToken = ApiService.token;
      print(
        '📱 [FLUTTER FCM] Auth token exists: ${authToken != null && authToken.isNotEmpty ? 'YES' : 'NO'}',
      );

      if (authToken == null || authToken.isEmpty) {
        print(
          '⚠️ [FLUTTER FCM] User not authenticated yet - storing token for later',
        );
        // Store token temporarily to send later after login
        await StorageService.setString('pending_fcm_token', token);
        print(
          '💾 [FLUTTER FCM] Token stored in local storage as pending_fcm_token',
        );
        print(
          '📱 ========== [FLUTTER FCM] TOKEN STORED FOR LATER ==========\n',
        );
        return;
      }

      print('📤 [FLUTTER FCM] Sending token to backend API...');
      print('📤 [FLUTTER FCM] Endpoint: /users/fcm-token');
      print('📤 [FLUTTER FCM] Method: POST');

      final response = await ApiService.post('/users/fcm-token', {
        'fcmToken': token,
      });

      print('📥 [FLUTTER FCM] Response received');
      print('📥 [FLUTTER FCM] Response: ${response.toString()}');

      if (response['success'] == true) {
        print('✅ [FLUTTER FCM] SUCCESS: FCM token sent and stored in backend');
        print(
          '✅ [FLUTTER FCM] Message: ${response['message'] ?? 'Token updated successfully'}',
        );
        // Clear pending token if exists
        await StorageService.remove('pending_fcm_token');
        print('🗑️ [FLUTTER FCM] Cleared pending token from local storage');
      } else {
        print('❌ [FLUTTER FCM] FAILED: Backend returned success: false');
        print(
          '❌ [FLUTTER FCM] Error message: ${response['message'] ?? 'Unknown error'}',
        );
      }
      print('📱 ========== [FLUTTER FCM] SEND TOKEN COMPLETE ==========\n');
    } catch (e, stackTrace) {
      print('❌ ========== [FLUTTER FCM] SEND TOKEN ERROR ==========');
      print('❌ [FLUTTER FCM] Exception: $e');
      print('❌ [FLUTTER FCM] Stack trace: $stackTrace');
      // Store token temporarily to send later after login
      await StorageService.setString('pending_fcm_token', token);
      print('💾 [FLUTTER FCM] Token stored in local storage for retry');
      print('📱 ========== [FLUTTER FCM] ERROR HANDLED ==========\n');
    }
  }

  static int min(int a, int b) => a < b ? a : b;

  /// Send pending FCM token after user login
  static Future<void> sendPendingToken() async {
    try {
      final pendingToken = StorageService.getString('pending_fcm_token');
      if (pendingToken != null && pendingToken.isNotEmpty) {
        print('📤 Sending pending FCM token after login...');
        await _sendTokenToBackend(pendingToken);
      }
    } catch (e) {
      print('❌ Error sending pending FCM token: $e');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      final notificationData = parseNotificationPayload(response.payload);
      if (notificationData != null && navigatorKey?.currentContext != null) {
        // Navigate using the navigator key
        NotificationNavigator.navigateFromNotification(
          navigatorKey!.currentContext!,
          notificationData,
        );
      }
    }
  }

  /// Parse notification data from payload string
  static Map<String, dynamic>? parseNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      // Try to parse as JSON first
      if (payload.startsWith('{')) {
        return jsonDecode(payload) as Map<String, dynamic>;
      }

      // If it's a string representation of a map, try to parse it
      // Format: {key: value, key2: value2}
      final cleaned = payload.replaceAll(RegExp(r'[{}]'), '');
      final Map<String, dynamic> result = {};
      final pairs = cleaned.split(',');
      for (var pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final value = parts[1].trim();
          result[key] = value;
        }
      }
      return result.isNotEmpty ? result : null;
    } catch (e) {
      print('❌ Error parsing notification payload: $e');
      return null;
    }
  }

  /// Extract notification data from RemoteMessage
  static Map<String, dynamic> extractNotificationData(RemoteMessage message) {
    final data = <String, dynamic>{};

    // Extract from data field (FCM data payload)
    data.addAll(message.data);

    // Extract reference ID, status, date & time
    if (message.data.containsKey('referenceId')) {
      data['referenceId'] = message.data['referenceId'];
    } else if (message.data.containsKey('ticketNumber')) {
      data['referenceId'] = message.data['ticketNumber'];
    }

    if (message.data.containsKey('status')) {
      data['status'] = message.data['status'];
    } else if (message.data.containsKey('newStatus')) {
      data['status'] = message.data['newStatus'];
    }

    if (message.data.containsKey('dateTime')) {
      data['dateTime'] = message.data['dateTime'];
    } else if (message.data.containsKey('updatedAt')) {
      data['dateTime'] = message.data['updatedAt'];
    }

    if (message.data.containsKey('formattedDate')) {
      data['formattedDate'] = message.data['formattedDate'];
    }

    if (message.data.containsKey('formattedTime')) {
      data['formattedTime'] = message.data['formattedTime'];
    }

    // Extract ticket/complaint ID for navigation
    if (message.data.containsKey('ticketId')) {
      data['ticketId'] = message.data['ticketId'];
    } else if (message.data.containsKey('complaintId')) {
      data['ticketId'] = message.data['complaintId'];
    }

    return data;
  }

  /// Handle foreground messages (app is open and visible)
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('\n📨 ========== [FLUTTER FCM] FOREGROUND NOTIFICATION ==========');
    print('📨 [FLUTTER FCM] Timestamp: ${DateTime.now().toIso8601String()}');
    print('📨 [FLUTTER FCM] Message ID: ${message.messageId ?? 'null'}');
    print('📨 [FLUTTER FCM] Sent Time: ${message.sentTime ?? 'null'}');
    print('📨 [FLUTTER FCM] From: ${message.from ?? 'null'}');
    print('📨 [FLUTTER FCM] Collapse Key: ${message.collapseKey ?? 'null'}');
    print('📨 [FLUTTER FCM] Message Type: ${message.messageType ?? 'null'}');
    print(
      '📨 [FLUTTER FCM] Notification Title: ${message.notification?.title ?? 'null'}',
    );
    print(
      '📨 [FLUTTER FCM] Notification Body: ${message.notification?.body ?? 'null'}',
    );
    print(
      '📨 [FLUTTER FCM] Notification Android: ${message.notification?.android != null ? 'present' : 'null'}',
    );
    print(
      '📨 [FLUTTER FCM] Notification Apple: ${message.notification?.apple != null ? 'present' : 'null'}',
    );
    print(
      '📨 [FLUTTER FCM] Data payload keys: ${message.data.keys.join(', ')}',
    );
    print('📨 [FLUTTER FCM] Data payload: ${jsonEncode(message.data)}');
    print('📨 [FLUTTER FCM] Full message: ${message.toString()}');

    // Extract notification data
    final notificationData = extractNotificationData(message);
    final notificationType = notificationData['type'] ?? 'general';

    print('📨 [FOREGROUND] Notification Type: $notificationType');
    print('📨 [FOREGROUND] Extracted Data: ${jsonEncode(notificationData)}');

    // Get title and body with reference ID, status, date & time
    final title =
        message.notification?.title ?? _getDefaultTitle(notificationType);
    String body =
        message.notification?.body ??
        _getDefaultBody(notificationType, notificationData);

    // Enhance body with reference ID, status, date & time if available
    if (notificationData.containsKey('referenceId') &&
        notificationData.containsKey('status') &&
        notificationData.containsKey('dateTime')) {
      body =
          'Reference ID: ${notificationData['referenceId']}\n'
          'Status: ${notificationData['status']}\n'
          'Updated: ${notificationData['dateTime']}';
    }

    // Store notification in local storage for notifications screen
    await _storeNotification(notificationData, title, body);

    // Create notification channel for Android (required for Android 8.0+)
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'apartmentsync_notifications',
              'ApartmentSync Notifications',
              description: 'Notifications from ApartmentSync',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );
      print('✅ [FOREGROUND] Notification channel created');
    } catch (e) {
      print('⚠️ [FOREGROUND] Error creating notification channel: $e');
    }

    // Show local notification with proper payload (JSON stringified)
    try {
      await _localNotifications.show(
        message.hashCode.abs(), // Use absolute value to avoid negative IDs
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'apartmentsync_notifications',
            'ApartmentSync Notifications',
            channelDescription: 'Notifications from ApartmentSync',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: _getNotificationColor(notificationType),
            enableVibration: true,
            playSound: true,
            showWhen: true,
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
            ),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(notificationData), // Store as JSON string
      );

      print(
        '✅ [FLUTTER FCM] SUCCESS: Local notification displayed successfully',
      );
      print('✅ [FLUTTER FCM] Notification ID: ${message.hashCode.abs()}');
      print('✅ [FLUTTER FCM] Title: "$title"');
      print('✅ [FLUTTER FCM] Body: "$body"');
      print('✅ [FLUTTER FCM] Payload: ${jsonEncode(notificationData)}');
    } catch (e, stackTrace) {
      print('❌ ========== [FLUTTER FCM] DISPLAY NOTIFICATION ERROR ==========');
      print('❌ [FLUTTER FCM] Error showing local notification: $e');
      print('❌ [FLUTTER FCM] Error type: ${e.runtimeType}');
      print('❌ [FLUTTER FCM] Stack trace: $stackTrace');
      print('❌ [FLUTTER FCM] Attempted title: "$title"');
      print('❌ [FLUTTER FCM] Attempted body: "$body"');
      print('❌ ========== [FLUTTER FCM] DISPLAY ERROR END ==========');
    }

    // Also emit to navigator key if available (for in-app display)
    if (navigatorKey.currentContext != null) {
      print('📱 [FOREGROUND] Showing in-app notification');
      _showInAppNotification(
        navigatorKey.currentContext!,
        title,
        body,
        notificationData,
      );
    } else {
      print(
        '⚠️ [FOREGROUND] Navigator key not available for in-app notification',
      );
    }

    print(
      '📨 [FLUTTER FCM] ========== FOREGROUND NOTIFICATION HANDLED ==========\n',
    );
  }

  /// Handle background messages (app is in background)
  static void _handleBackgroundMessage(RemoteMessage message) {
    print('📨 [BACKGROUND] Message received: ${message.notification?.title}');
    print('📨 [BACKGROUND] Message data: ${message.data}');

    // Extract notification data
    final notificationData = extractNotificationData(message);

    // Store notification data for navigation when app comes to foreground
    _storeNotificationForNavigation(notificationData);

    // Navigate if app is already in background and navigator is available
    if (navigatorKey.currentContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationNavigator.navigateFromNotification(
          navigatorKey.currentContext!,
          notificationData,
        );
      });
    }
  }

  /// Handle terminated state messages (app was closed)
  static void _handleTerminatedMessage(RemoteMessage message) {
    print(
      '📨 [TERMINATED] App opened from notification: ${message.notification?.title}',
    );
    print('📨 [TERMINATED] Message data: ${message.data}');

    // Extract notification data
    final notificationData = extractNotificationData(message);

    // Store notification data for navigation after app initializes
    _storeNotificationForNavigation(notificationData);
  }

  /// Store notification data for later navigation (when app initializes)
  static void _storeNotificationForNavigation(
    Map<String, dynamic> notificationData,
  ) {
    try {
      StorageService.setString(
        'pending_notification',
        jsonEncode(notificationData),
      );
      print('💾 [NOTIFICATION] Stored notification data for navigation');
    } catch (e) {
      print('❌ [NOTIFICATION] Error storing notification data: $e');
    }
  }

  /// Check and handle pending notification (call this after app initializes)
  static void handlePendingNotification(BuildContext context) {
    try {
      final pendingNotificationJson = StorageService.getString(
        'pending_notification',
      );
      if (pendingNotificationJson != null &&
          pendingNotificationJson.isNotEmpty) {
        final notificationData =
            jsonDecode(pendingNotificationJson) as Map<String, dynamic>;
        print(
          '📱 [NOTIFICATION] Handling pending notification: $notificationData',
        );

        // Navigate to appropriate screen
        NotificationNavigator.navigateFromNotification(
          context,
          notificationData,
        );

        // Clear pending notification
        StorageService.remove('pending_notification');
      }
    } catch (e) {
      print('❌ [NOTIFICATION] Error handling pending notification: $e');
    }
  }

  static String _getDefaultTitle(String type) {
    switch (type) {
      case 'ticket_created':
        return 'Ticket Created';
      case 'ticket_assigned':
        return 'Ticket Assigned';
      case 'ticket_status_updated':
        return 'Ticket Status Updated';
      case 'ticket_comment_added':
        return 'New Comment';
      case 'work_update_added':
        return 'Work Update';
      case 'ticket_resolved':
        return 'Ticket Resolved';
      case 'ticket_closed':
        return 'Ticket Closed';
      case 'ticket_reopened':
        return 'Ticket Reopened';
      case 'ticket_cancelled':
        return 'Ticket Cancelled';
      default:
        return 'New Notification';
    }
  }

  static String _getDefaultBody(String type, Map<String, dynamic> data) {
    // Extract reference ID, status, and date/time
    final referenceId = data['referenceId'] ?? data['ticketNumber'] ?? '';
    final status = data['status'] ?? data['newStatus'] ?? '';
    final dateTime = data['dateTime'] ?? '';

    switch (type) {
      case 'ticket_created':
        return referenceId.isNotEmpty
            ? 'Reference ID: $referenceId\nStatus: Created\n${dateTime.isNotEmpty ? "Created: $dateTime" : ""}'
            : 'Your ticket has been created successfully';
      case 'ticket_assigned':
        return referenceId.isNotEmpty
            ? 'Reference ID: $referenceId\nAssigned to: ${data['assignedTo'] ?? 'staff'}\n${dateTime.isNotEmpty ? "Assigned: $dateTime" : ""}'
            : 'Ticket assigned to ${data['assignedTo'] ?? 'staff'}';
      case 'ticket_status_updated':
        return referenceId.isNotEmpty && status.isNotEmpty
            ? 'Reference ID: $referenceId\nStatus: $status\n${dateTime.isNotEmpty ? "Updated: $dateTime" : ""}'
            : 'Ticket status changed to ${status.isNotEmpty ? status : data['newStatus'] ?? ''}';
      case 'ticket_comment_added':
        return referenceId.isNotEmpty
            ? 'Reference ID: $referenceId\n${data['postedBy'] ?? 'Someone'} commented\n${dateTime.isNotEmpty ? "Posted: $dateTime" : ""}'
            : '${data['postedBy'] ?? 'Someone'} commented on ticket';
      case 'work_update_added':
        return referenceId.isNotEmpty
            ? 'Reference ID: $referenceId\nProgress update available\n${dateTime.isNotEmpty ? "Updated: $dateTime" : ""}'
            : 'Progress update on ticket';
      case 'ticket_resolved':
        return referenceId.isNotEmpty
            ? 'Reference ID: $referenceId\nStatus: Resolved\n${dateTime.isNotEmpty ? "Resolved: $dateTime" : ""}\nPlease verify and close.'
            : 'Ticket has been resolved. Please verify and close.';
      case 'ticket_closed':
        return referenceId.isNotEmpty
            ? 'Reference ID: $referenceId\nStatus: Closed\n${dateTime.isNotEmpty ? "Closed: $dateTime" : ""}'
            : 'Ticket has been closed';
      case 'ticket_reopened':
        return referenceId.isNotEmpty
            ? 'Reference ID: $referenceId\nStatus: Reopened\n${dateTime.isNotEmpty ? "Reopened: $dateTime" : ""}'
            : 'Ticket has been reopened';
      case 'ticket_cancelled':
        return referenceId.isNotEmpty
            ? 'Reference ID: $referenceId\nStatus: Cancelled\n${dateTime.isNotEmpty ? "Cancelled: $dateTime" : ""}'
            : 'Ticket has been cancelled';
      case 'user_approved':
        return referenceId.isNotEmpty
            ? 'Reference ID: $referenceId\nStatus: Approved\n${dateTime.isNotEmpty ? "Approved: $dateTime" : ""}'
            : 'Your account has been approved';
      case 'user_rejected':
        return referenceId.isNotEmpty
            ? 'Reference ID: $referenceId\nStatus: Rejected\nReason: ${data['reason'] ?? 'No reason provided'}\n${dateTime.isNotEmpty ? "Rejected: $dateTime" : ""}'
            : 'Your account registration has been rejected';
      default:
        return referenceId.isNotEmpty
            ? 'Reference ID: $referenceId\n${dateTime.isNotEmpty ? "Updated: $dateTime" : ""}'
            : 'You have a new notification';
    }
  }

  static Color? _getNotificationColor(String type) {
    switch (type) {
      case 'ticket_created':
        return const Color(0xFFFF9800); // Orange
      case 'ticket_assigned':
        return const Color(0xFF2196F3); // Blue
      case 'ticket_status_updated':
        return const Color(0xFF9C27B0); // Purple
      case 'ticket_resolved':
        return const Color(0xFF4CAF50); // Green
      case 'ticket_closed':
        return const Color(0xFF607D8B); // Grey
      case 'ticket_reopened':
        return const Color(0xFFFF5722); // Deep Orange
      case 'ticket_cancelled':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF667EEA); // Primary color
    }
  }

  /// Store notification in local storage for notifications screen
  static Future<void> _storeNotification(
    Map<String, dynamic> notificationData,
    String title,
    String body,
  ) async {
    try {
      final notification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'body': body,
        'type': notificationData['type'] ?? 'general',
        'data': notificationData,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      };

      // Get existing notifications
      final notificationsJson = StorageService.getString(
        'stored_notifications',
      );
      List<Map<String, dynamic>> notifications = [];

      if (notificationsJson != null && notificationsJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(notificationsJson) as List;
          notifications = decoded.cast<Map<String, dynamic>>();
        } catch (e) {
          print('⚠️ [NOTIFICATION] Error parsing stored notifications: $e');
        }
      }

      // Add new notification at the beginning
      notifications.insert(0, notification);

      // Keep only last 100 notifications
      if (notifications.length > 100) {
        notifications = notifications.sublist(0, 100);
      }

      // Save back to storage
      await StorageService.setString(
        'stored_notifications',
        jsonEncode(notifications),
      );
      print('✅ [NOTIFICATION] Stored notification: ${notification['id']}');
    } catch (e) {
      print('❌ [NOTIFICATION] Error storing notification: $e');
    }
  }

  /// Show in-app notification (SnackBar) when app is in foreground
  static void _showInAppNotification(
    BuildContext context,
    String title,
    String body,
    Map<String, dynamic> notificationData,
  ) {
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // Dismiss any existing snackbar
      scaffoldMessenger.clearSnackBars();

      // Show new snackbar with notification
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getNotificationIcon(notificationData['type'] ?? 'general'),
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          backgroundColor:
              _getNotificationColor(notificationData['type'] ?? 'general') ??
              Colors.blue,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to appropriate screen
              final ticketId =
                  notificationData['ticketId'] ??
                  notificationData['complaintId'];
              if (ticketId != null) {
                NotificationNavigator.navigateFromNotification(
                  context,
                  notificationData,
                );
              }
            },
          ),
        ),
      );

      print('✅ [NOTIFICATION] In-app notification displayed');
    } catch (e) {
      print('❌ [NOTIFICATION] Error showing in-app notification: $e');
    }
  }

  /// Get icon for notification type
  static IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'ticket_created':
        return Icons.add_circle;
      case 'ticket_assigned':
        return Icons.assignment;
      case 'ticket_status_updated':
        return Icons.update;
      case 'ticket_comment_added':
        return Icons.comment;
      case 'work_update_added':
        return Icons.work;
      case 'ticket_resolved':
        return Icons.check_circle;
      case 'ticket_closed':
        return Icons.close;
      case 'ticket_reopened':
        return Icons.refresh;
      case 'ticket_cancelled':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  /// Get all stored notifications
  static List<Map<String, dynamic>> getStoredNotifications() {
    try {
      final notificationsJson = StorageService.getString(
        'stored_notifications',
      );
      if (notificationsJson != null && notificationsJson.isNotEmpty) {
        final decoded = jsonDecode(notificationsJson) as List;
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('❌ [NOTIFICATION] Error getting stored notifications: $e');
    }
    return [];
  }

  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final notifications = getStoredNotifications();
      final index = notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        notifications[index]['read'] = true;
        await StorageService.setString(
          'stored_notifications',
          jsonEncode(notifications),
        );
        print('✅ [NOTIFICATION] Marked notification as read: $notificationId');
      }
    } catch (e) {
      print('❌ [NOTIFICATION] Error marking notification as read: $e');
    }
  }

  /// Clear all notifications
  static Future<void> clearAllNotifications() async {
    try {
      await StorageService.remove('stored_notifications');
      print('✅ [NOTIFICATION] Cleared all notifications');
    } catch (e) {
      print('❌ [NOTIFICATION] Error clearing notifications: $e');
    }
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'apartmentsync_notifications',
          'ApartmentSync Notifications',
          channelDescription: 'Notifications from ApartmentSync',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: data?.toString(),
    );
  }
}

/// Top-level function for background message handler (when app is terminated)
/// This must be a top-level function for Firebase to work properly
/// Firebase automatically displays notifications when app is in background/killed state
/// This handler is called for data-only messages or for additional processing
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print(
    '📨 [BACKGROUND HANDLER] Message received: ${message.notification?.title}',
  );
  print('📨 [BACKGROUND HANDLER] Body: ${message.notification?.body}');
  print('📨 [BACKGROUND HANDLER] Message data: ${message.data}');

  // Initialize local notifications for background handler
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  final InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();
  await localNotifications.initialize(initSettings);

  // Create notification channel for Android (if not already created)
  try {
    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'apartmentsync_notifications',
            'ApartmentSync Notifications',
            description: 'Notifications from ApartmentSync',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );
    print('✅ [BACKGROUND HANDLER] Notification channel created');
  } catch (e) {
    print('⚠️ [BACKGROUND HANDLER] Error creating notification channel: $e');
  }

  // Extract notification data
  final notificationData = <String, dynamic>{};
  notificationData.addAll(message.data);

  // Store notification for navigation when app opens
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_notification', jsonEncode(notificationData));
    print('💾 [BACKGROUND HANDLER] Stored notification for later navigation');
  } catch (e) {
    print('❌ [BACKGROUND HANDLER] Error storing notification: $e');
  }

  // Note: If message has notification payload, Firebase automatically displays it
  // This handler is primarily for data-only messages or additional processing
}
