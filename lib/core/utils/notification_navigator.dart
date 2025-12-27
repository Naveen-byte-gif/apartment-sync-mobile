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
    final complaintId = notificationData['complaintId'] as String?;
    
    // Use ticketId or complaintId for navigation
    final id = ticketId ?? complaintId;

    // Handle ticket/complaint related notifications
    if (id != null && id.isNotEmpty) {
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
              builder: (_) => TicketDetailScreen(ticketId: id),
            ),
          );
          break;
        default:
          // For other types, still navigate to ticket detail if ID exists
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TicketDetailScreen(ticketId: id),
            ),
          );
          break;
      }
    } else {
      // For user approval/rejection, navigate to home or profile
      switch (type) {
        case 'user_approved':
        case 'user_rejected':
          // Navigate to home screen (user will see their status)
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
          break;
        default:
          // No navigation for unknown types without IDs
          print('⚠️ [NOTIFICATION NAVIGATOR] No navigation for type: $type');
          break;
      }
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

