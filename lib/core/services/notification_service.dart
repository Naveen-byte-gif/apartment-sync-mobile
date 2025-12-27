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
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    try {
      // Request permission (handles Android 13+ POST_NOTIFICATIONS automatically)
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false, // Explicit permission required
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ User granted provisional notification permission');
      } else {
        print('⚠️ User denied notification permission');
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

    // Create high-importance notification channel for Android (required for Android 8.0+)
    // This must be done early to ensure notifications can be displayed
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
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

      // Handle foreground messages (app is open)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background/terminated messages (app opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      
      // Check if app was opened from terminated state
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('📱 App opened from terminated state via notification');
        _handleTerminatedMessage(initialMessage);
      }
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
    print('📨 [FOREGROUND] ========== NOTIFICATION RECEIVED ==========');
    print('📨 [FOREGROUND] Title: ${message.notification?.title}');
    print('📨 [FOREGROUND] Body: ${message.notification?.body}');
    print('📨 [FOREGROUND] Message data: ${jsonEncode(message.data)}');
    print('📨 [FOREGROUND] Message ID: ${message.messageId}');
    print('📨 [FOREGROUND] Sent Time: ${message.sentTime}');

    // Extract notification data
    final notificationData = extractNotificationData(message);
    final notificationType = notificationData['type'] ?? 'general';
    
    print('📨 [FOREGROUND] Notification Type: $notificationType');
    print('📨 [FOREGROUND] Extracted Data: ${jsonEncode(notificationData)}');
    
    // Get title and body with reference ID, status, date & time
    final title = message.notification?.title ?? _getDefaultTitle(notificationType);
    String body = message.notification?.body ?? _getDefaultBody(notificationType, notificationData);
    
    // Enhance body with reference ID, status, date & time if available
    if (notificationData.containsKey('referenceId') && 
        notificationData.containsKey('status') && 
        notificationData.containsKey('dateTime')) {
      body = 'Reference ID: ${notificationData['referenceId']}\n'
             'Status: ${notificationData['status']}\n'
             'Updated: ${notificationData['dateTime']}';
    }

    // Store notification in local storage for notifications screen
    await _storeNotification(notificationData, title, body);

    // Create notification channel for Android (required for Android 8.0+)
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
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
      
      print('✅ [FOREGROUND] Local notification displayed successfully');
      print('✅ [FOREGROUND] Notification ID: ${message.hashCode.abs()}');
    } catch (e) {
      print('❌ [FOREGROUND] Error showing notification: $e');
      print('❌ [FOREGROUND] Error stack: ${StackTrace.current}');
    }

    // Also emit to navigator key if available (for in-app display)
    if (navigatorKey.currentContext != null) {
      print('📱 [FOREGROUND] Showing in-app notification');
      _showInAppNotification(navigatorKey.currentContext!, title, body, notificationData);
    } else {
      print('⚠️ [FOREGROUND] Navigator key not available for in-app notification');
    }
    
    print('📨 [FOREGROUND] ========== NOTIFICATION HANDLED ==========');
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
    print('📨 [TERMINATED] App opened from notification: ${message.notification?.title}');
    print('📨 [TERMINATED] Message data: ${message.data}');
    
    // Extract notification data
    final notificationData = extractNotificationData(message);
    
    // Store notification data for navigation after app initializes
    _storeNotificationForNavigation(notificationData);
  }
  
  /// Store notification data for later navigation (when app initializes)
  static void _storeNotificationForNavigation(Map<String, dynamic> notificationData) {
    try {
      StorageService.setString('pending_notification', jsonEncode(notificationData));
      print('💾 [NOTIFICATION] Stored notification data for navigation');
    } catch (e) {
      print('❌ [NOTIFICATION] Error storing notification data: $e');
    }
  }
  
  /// Check and handle pending notification (call this after app initializes)
  static void handlePendingNotification(BuildContext context) {
    try {
      final pendingNotificationJson = StorageService.getString('pending_notification');
      if (pendingNotificationJson != null && pendingNotificationJson.isNotEmpty) {
        final notificationData = jsonDecode(pendingNotificationJson) as Map<String, dynamic>;
        print('📱 [NOTIFICATION] Handling pending notification: $notificationData');
        
        // Navigate to appropriate screen
        NotificationNavigator.navigateFromNotification(context, notificationData);
        
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
      final notificationsJson = StorageService.getString('stored_notifications');
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
      await StorageService.setString('stored_notifications', jsonEncode(notifications));
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          backgroundColor: _getNotificationColor(notificationData['type'] ?? 'general') ?? Colors.blue,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to appropriate screen
              final ticketId = notificationData['ticketId'] ?? notificationData['complaintId'];
              if (ticketId != null) {
                NotificationNavigator.navigateFromNotification(context, notificationData);
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
      final notificationsJson = StorageService.getString('stored_notifications');
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
        await StorageService.setString('stored_notifications', jsonEncode(notifications));
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
  print('📨 [BACKGROUND HANDLER] Message received: ${message.notification?.title}');
  print('📨 [BACKGROUND HANDLER] Body: ${message.notification?.body}');
  print('📨 [BACKGROUND HANDLER] Message data: ${message.data}');
  
  // Initialize local notifications for background handler
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
  
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();
  await localNotifications.initialize(initSettings);
  
  // Create notification channel for Android (if not already created)
  try {
    await localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
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
