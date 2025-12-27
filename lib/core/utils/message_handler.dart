import 'package:flutter/material.dart';
import '../../presentation/widgets/message_dialog.dart';
import '../../presentation/widgets/message_snackbar.dart';

/// Centralized message handler for API responses
class AppMessageHandler {
  /// Handle API response and show appropriate message
  static void handleResponse(
    BuildContext context,
    Map<String, dynamic> response, {
    bool showDialog = false,
    VoidCallback? onSuccess,
    VoidCallback? onError,
    int? statusCode,
  }) {
    final success = response['success'] ?? false;
    String message = response['message'] ?? 
                    response['error'] ??
                    (success ? 'Operation completed successfully' : 'An error occurred');

    // Clean up message - remove any extra formatting
    message = message.trim();

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
      // For important errors (400, 409, etc.), show as dialog by default
      final shouldShowDialog = showDialog || 
                               statusCode != null && (statusCode >= 400 && statusCode < 500);
      
      if (shouldShowDialog) {
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

  /// Handle error and show appropriate message
  static void handleError(
    BuildContext context,
    dynamic error, {
    bool showDialog = false,
  }) {
    String message = 'An error occurred';

    if (error is Map<String, dynamic>) {
      message = error['message'] ?? 
               error['error'] ?? 
               'An error occurred';
    } else if (error is String) {
      message = error;
    } else if (error.toString().contains('SocketException') ||
               error.toString().contains('Failed host lookup')) {
      message = 'No internet connection. Please check your network.';
    } else if (error.toString().contains('TimeoutException') ||
               error.toString().contains('Timeout')) {
      message = 'Request timeout. Please try again.';
    } else if (error.toString().contains('401') ||
               error.toString().contains('Unauthorized')) {
      message = 'Unauthorized. Please login again.';
    } else if (error.toString().contains('403') ||
               error.toString().contains('Forbidden')) {
      message = 'Access denied. You don\'t have permission.';
    } else if (error.toString().contains('404') ||
               error.toString().contains('Not Found')) {
      message = 'Resource not found.';
    } else if (error.toString().contains('500') ||
               error.toString().contains('Internal Server Error')) {
      message = 'Server error. Please try again later.';
    } else {
      // Extract message from error string if possible
      final errorStr = error.toString();
      if (errorStr.contains('message')) {
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
      } else {
        message = errorStr;
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

  /// Show success message
  static void showSuccess(
    BuildContext context,
    String message, {
    bool showDialog = false,
    VoidCallback? onOkPressed,
  }) {
    if (showDialog) {
      SuccessDialog.show(
        context,
        title: 'Success',
        message: message,
        onOkPressed: onOkPressed,
      );
    } else {
      SuccessSnackBar.show(context, message);
    }
  }

  /// Show error message
  static void showError(
    BuildContext context,
    String message, {
    bool showDialog = false,
    VoidCallback? onOkPressed,
  }) {
    if (showDialog) {
      ErrorDialog.show(
        context,
        title: 'Error',
        message: message,
        onOkPressed: onOkPressed,
      );
    } else {
      ErrorSnackBar.show(context, message);
    }
  }

  /// Show info message
  static void showInfo(
    BuildContext context,
    String message, {
    bool showDialog = false,
    VoidCallback? onOkPressed,
  }) {
    if (showDialog) {
      InfoDialog.show(
        context,
        title: 'Information',
        message: message,
        onOkPressed: onOkPressed,
      );
    } else {
      InfoSnackBar.show(context, message);
    }
  }

  /// Show warning message
  static void showWarning(
    BuildContext context,
    String message, {
    bool showDialog = false,
    VoidCallback? onOkPressed,
  }) {
    if (showDialog) {
      InfoDialog.show(
        context,
        title: 'Warning',
        message: message,
        onOkPressed: onOkPressed,
      );
    } else {
      WarningSnackBar.show(context, message);
    }
  }
}

