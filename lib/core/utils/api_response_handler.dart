import 'package:flutter/material.dart';
import '../../presentation/widgets/message_dialog.dart';
import '../../presentation/widgets/message_snackbar.dart';

/// Helper class to handle API responses consistently
class ApiResponseHandler {
  /// Handle API response and show appropriate message
  /// 
  /// Example usage:
  /// ```dart
  /// final response = await ApiService.post('/endpoint', data);
  /// ApiResponseHandler.handle(
  ///   context,
  ///   response,
  ///   onSuccess: () => Navigator.pop(context),
  /// );
  /// ```
  static void handle(
    BuildContext context,
    Map<String, dynamic> response, {
    bool showDialog = false,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) {
    final success = response['success'] ?? false;
    final message = response['message'] ?? 
                   (success ? 'Operation completed successfully' : 'An error occurred');

    if (success) {
      if (showDialog) {
        SuccessDialog.show(
          context,
          title: 'Success',
          message: message,
          onOkPressed: onSuccess,
        );
      } else {
        SuccessSnackBar.show(context, message);
        onSuccess?.call();
      }
    } else {
      if (showDialog) {
        ErrorDialog.show(
          context,
          title: 'Error',
          message: message,
          onOkPressed: onError,
        );
      } else {
        ErrorSnackBar.show(context, message);
        onError?.call();
      }
    }
  }

  /// Handle error from try-catch blocks
  /// 
  /// Example usage:
  /// ```dart
  /// try {
  ///   final response = await ApiService.post('/endpoint', data);
  ///   ApiResponseHandler.handle(context, response);
  /// } catch (e) {
  ///   ApiResponseHandler.handleError(context, e);
  /// }
  /// ```
  static void handleError(
    BuildContext context,
    dynamic error, {
    bool showDialog = false,
  }) {
    String message = 'An error occurred';

    // Handle Map responses (API error responses)
    if (error is Map<String, dynamic>) {
      message = error['message'] ?? 
               error['error'] ?? 
               'An error occurred';
    } 
    // Handle String errors
    else if (error is String) {
      message = error;
    } 
    // Handle Exception types
    else {
      final errorStr = error.toString();
      
      // Network errors
      if (errorStr.contains('SocketException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('Network is unreachable')) {
        message = 'No internet connection. Please check your network.';
      } 
      // Timeout errors
      else if (errorStr.contains('TimeoutException') ||
               errorStr.contains('Timeout') ||
               errorStr.contains('timed out')) {
        message = 'Request timeout. Please try again.';
      } 
      // HTTP status errors
      else if (errorStr.contains('401') ||
               errorStr.contains('Unauthorized')) {
        message = 'Unauthorized. Please login again.';
      } else if (errorStr.contains('403') ||
                 errorStr.contains('Forbidden')) {
        message = 'Access denied. You don\'t have permission.';
      } else if (errorStr.contains('404') ||
                 errorStr.contains('Not Found')) {
        message = 'Resource not found.';
      } else if (errorStr.contains('500') ||
                 errorStr.contains('Internal Server Error')) {
        message = 'Server error. Please try again later.';
      } 
      // Try to extract message from error string
      else {
        try {
          // Try to extract message from error string using simple pattern
          final pattern = RegExp(r'message\s*[:=]\s*["''](.+?)["'']');
          final match = pattern.firstMatch(errorStr);
          if (match != null && match.groupCount > 0) {
            message = match.group(1) ?? message;
          } else {
            message = errorStr;
          }
        } catch (e) {
          message = errorStr;
        }
      }
    }

    if (showDialog) {
      ErrorDialog.show(
        context,
        title: 'Error',
        message: message,
      );
    } else {
      ErrorSnackBar.show(context, message);
    }
  }
}

