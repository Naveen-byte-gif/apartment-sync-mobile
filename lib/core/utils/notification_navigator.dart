import 'package:flutter/material.dart';
import '../../presentation/screens/complaints/ticket_detail_screen.dart';

/// Helper class to handle navigation based on notification type
class NotificationNavigator {
  /// Navigate to appropriate screen based on notification data
  static void navigateFromNotification(
    BuildContext context,
    Map<String, dynamic> notificationData,
  ) {
    final type = notificationData['type'] as String?;
    final ticketId = notificationData['ticketId'] as String?;

    if (ticketId == null) return;

    switch (type) {
      case 'ticket_created':
      case 'ticket_assigned':
      case 'ticket_status_updated':
      case 'ticket_comment_added':
      case 'work_update_added':
      case 'ticket_resolved':
      case 'ticket_closed':
      case 'ticket_reopened':
      case 'ticket_cancelled':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicketDetailScreen(ticketId: ticketId),
          ),
        );
        break;
      default:
        // Default navigation or no navigation
        break;
    }
  }

  /// Get route name for notification type
  static String? getRouteForType(String? type) {
    switch (type) {
      case 'ticket_created':
      case 'ticket_assigned':
      case 'ticket_status_updated':
      case 'ticket_comment_added':
      case 'work_update_added':
      case 'ticket_resolved':
      case 'ticket_closed':
      case 'ticket_reopened':
      case 'ticket_cancelled':
        return '/ticket-detail';
      default:
        return null;
    }
  }
}

