import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../../data/models/complaint_data.dart';

class TicketService {
  /// Get all tickets (for admin/staff)
  static Future<Map<String, dynamic>> getAllTickets({
    int page = 1,
    int limit = 20,
    String? status,
    String? category,
    String? priority,
    String? assignedTo,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) queryParams['status'] = status;
    if (category != null) queryParams['category'] = category;
    if (priority != null) queryParams['priority'] = priority;
    if (assignedTo != null) queryParams['assignedTo'] = assignedTo;

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return await ApiService.get('${ApiConstants.complaints}/all/tickets?$queryString');
  }

  /// Get my tickets (for residents)
  static Future<Map<String, dynamic>> getMyTickets({
    int page = 1,
    int limit = 20,
    String? status,
    String? category,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) queryParams['status'] = status;
    if (category != null) queryParams['category'] = category;

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return await ApiService.get('${ApiConstants.complaints}/my-complaints?$queryString');
  }

  /// Get ticket by ID
  static Future<Map<String, dynamic>> getTicket(String ticketId) async {
    return await ApiService.get('${ApiConstants.complaints}/$ticketId');
  }

  /// Create new ticket
  static Future<Map<String, dynamic>> createTicket(ComplaintData ticket) async {
    return await ApiService.post('${ApiConstants.complaints}', ticket.toJson());
  }

  /// Assign ticket to staff (Admin only)
  static Future<Map<String, dynamic>> assignTicket(
    String ticketId,
    String staffId, {
    String? note,
  }) async {
    return await ApiService.post(
      '${ApiConstants.complaints}/$ticketId/assign',
      {
        'staffId': staffId,
        if (note != null) 'note': note,
      },
    );
  }

  /// Add comment to ticket
  static Future<Map<String, dynamic>> addComment(
    String ticketId,
    String text, {
    List<ComplaintMedia>? media,
  }) async {
    return await ApiService.post(
      '${ApiConstants.complaints}/$ticketId/comments',
      {
        'text': text,
        if (media != null) 'media': media.map((e) => e.toJson()).toList(),
      },
    );
  }

  /// Update ticket status (Staff/Admin)
  static Future<Map<String, dynamic>> updateStatus(
    String ticketId,
    String status, {
    String? description,
  }) async {
    return await ApiService.put(
      '${ApiConstants.complaints}/$ticketId/status',
      {
        'status': status,
        if (description != null) 'description': description,
      },
    );
  }

  /// Add work update (Staff)
  static Future<Map<String, dynamic>> addWorkUpdate(
    String ticketId,
    String description, {
    List<ComplaintMedia>? images,
  }) async {
    return await ApiService.post(
      '${ApiConstants.complaints}/$ticketId/work-updates',
      {
        'description': description,
        if (images != null) 'images': images.map((e) => e.toJson()).toList(),
      },
    );
  }

  /// Reopen ticket (Resident)
  static Future<Map<String, dynamic>> reopenTicket(
    String ticketId, {
    String? reason,
  }) async {
    return await ApiService.post(
      '${ApiConstants.complaints}/$ticketId/reopen',
      {
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Close ticket (Resident)
  static Future<Map<String, dynamic>> closeTicket(String ticketId) async {
    return await ApiService.post(
      '${ApiConstants.complaints}/$ticketId/close',
      {},
    );
  }

  /// Cancel ticket (Resident/Admin)
  static Future<Map<String, dynamic>> cancelTicket(
    String ticketId, {
    String? reason,
  }) async {
    return await ApiService.post(
      '${ApiConstants.complaints}/$ticketId/cancel',
      {
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Rate ticket (Resident)
  static Future<Map<String, dynamic>> rateTicket(
    String ticketId,
    int score, {
    String? comment,
  }) async {
    return await ApiService.post(
      '${ApiConstants.complaints}/$ticketId/rate',
      {
        'score': score,
        if (comment != null) 'comment': comment,
      },
    );
  }
}

