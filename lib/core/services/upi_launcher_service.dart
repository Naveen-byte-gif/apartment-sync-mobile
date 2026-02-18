import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches UPI deep link (upi://pay?...). On Android, can target a specific app by package.
class UpiLauncherService {
  static const _channel = MethodChannel('com.apartmentsync.app/upi_launcher');

  /// Launch [upiUri]. If [androidPackage] is set and we're on Android, try to open in that app.
  static Future<bool> launchUpi(
    String upiUri, {
    String? androidPackage,
  }) async {
    final uri = Uri.parse(upiUri);
    if (androidPackage != null && androidPackage.isNotEmpty && Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>(
          'launchUpi',
          <String, dynamic>{
            'uri': upiUri,
            'package': androidPackage,
          },
        );
        if (result == true) return true;
      } on PlatformException catch (_) {
        // Fallback to url_launcher
      }
    }
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }
}
