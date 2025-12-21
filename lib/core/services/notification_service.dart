import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'storage_service.dart';
import '../constants/api_constants.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted notification permission');
      }
    } catch (e) {
      print('⚠️ Firebase Messaging permission request failed: $e');
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

    try {
      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('✅ FCM Token: $token');
        // Send token to backend
        await _sendTokenToBackend(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed: $newToken');
        // Only send if user is authenticated
        _sendTokenToBackend(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
    } catch (e) {
      print('⚠️ Firebase Messaging setup failed: $e');
      print('⚠️ Push notifications will not work until Firebase is configured');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      // Only send token if user is authenticated
      if (ApiService.token == null || ApiService.token!.isEmpty) {
        print('ℹ️ FCM token stored for later (user not authenticated yet)');
        // Store token temporarily to send later after login
        await StorageService.setString('pending_fcm_token', token);
        return;
      }
      
      final response = await ApiService.post('/users/fcm-token', {'fcmToken': token});
      if (response['success'] == true) {
        print('✅ FCM token sent successfully');
        // Clear pending token if exists
        await StorageService.remove('pending_fcm_token');
      } else {
        print('⚠️ FCM token update failed: ${response['message']}');
      }
    } catch (e) {
      print('❌ Error sending FCM token to backend: $e');
      // Store token temporarily to send later after login
      await StorageService.setString('pending_fcm_token', token);
    }
  }

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
    // Handle notification tap - navigation will be handled by the app
    // The payload contains notification data that can be used for navigation
  }

  /// Get notification data from payload
  static Map<String, dynamic>? parseNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      // Parse the payload string back to Map
      // This is a simple implementation - adjust based on your payload format
      return {'payload': payload};
    } catch (e) {
      print('Error parsing notification payload: $e');
      return null;
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground message received: ${message.notification?.title}');
    print('📨 Message data: ${message.data}');

    // Determine notification type and customize display
    final notificationType = message.data['type'] ?? 'general';
    final title = message.notification?.title ?? _getDefaultTitle(notificationType);
    final body = message.notification?.body ?? _getDefaultBody(notificationType, message.data);

    // Show local notification with proper payload
    await _localNotifications.show(
      message.hashCode,
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
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  static void _handleBackgroundMessage(RemoteMessage message) {
    print('📨 Background message received: ${message.notification?.title}');
    print('📨 Message data: ${message.data}');
    // Handle background message - navigation will be handled when app opens
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
    switch (type) {
      case 'ticket_created':
        return 'Your ticket ${data['ticketNumber'] ?? ''} has been created successfully';
      case 'ticket_assigned':
        return 'Ticket ${data['ticketNumber'] ?? ''} assigned to ${data['assignedTo'] ?? 'staff'}';
      case 'ticket_status_updated':
        return 'Ticket ${data['ticketNumber'] ?? ''} status changed to ${data['newStatus'] ?? ''}';
      case 'ticket_comment_added':
        return '${data['postedBy'] ?? 'Someone'} commented on ticket ${data['ticketNumber'] ?? ''}';
      case 'work_update_added':
        return 'Progress update on ticket ${data['ticketNumber'] ?? ''}';
      case 'ticket_resolved':
        return 'Ticket ${data['ticketNumber'] ?? ''} has been resolved. Please verify and close.';
      case 'ticket_closed':
        return 'Ticket ${data['ticketNumber'] ?? ''} has been closed';
      case 'ticket_reopened':
        return 'Ticket ${data['ticketNumber'] ?? ''} has been reopened';
      case 'ticket_cancelled':
        return 'Ticket ${data['ticketNumber'] ?? ''} has been cancelled';
      default:
        return 'You have a new notification';
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

// Top-level function for background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message: ${message.notification?.title}');
}
