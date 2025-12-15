import 'package:flutter/material.dart';

class ErrorHandler {
  static void showError(BuildContext? context, dynamic error) {
    String message = 'An error occurred';
    
    if (error is String) {
      message = error;
    } else if (error.toString().contains('SocketException')) {
      message = 'No internet connection. Please check your network.';
    } else if (error.toString().contains('TimeoutException')) {
      message = 'Request timeout. Please try again.';
    } else if (error.toString().contains('401')) {
      message = 'Unauthorized. Please login again.';
    } else if (error.toString().contains('403')) {
      message = 'Access denied. You don\'t have permission.';
    } else if (error.toString().contains('404')) {
      message = 'Resource not found.';
    } else if (error.toString().contains('500')) {
      message = 'Server error. Please try again later.';
    } else {
      message = error.toString();
    }
    
    print('❌ [ERROR] $message');
    
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }
  
  static String getErrorMessage(dynamic error) {
    if (error is String) return error;
    if (error.toString().contains('SocketException')) {
      return 'No internet connection';
    }
    if (error.toString().contains('TimeoutException')) {
      return 'Request timeout';
    }
    return error.toString();
  }
}

