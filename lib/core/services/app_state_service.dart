import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants/app_constants.dart';
import '../../data/models/user_data.dart';
import 'storage_service.dart';

class AppStateService {
  // Save complete app state snapshot
  static Future<void> saveAppState({
    required UserData? user,
    required String? token,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save token
      if (token != null) {
        await prefs.setString(AppConstants.tokenKey, token);
      }
      
      // Save user data
      if (user != null) {
        await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      }
      
      // Save additional state
      if (additionalData != null) {
        await prefs.setString('app_state', jsonEncode(additionalData));
      }
      
      print('💾 [STATE] App state saved successfully');
    } catch (e) {
      print('❌ [STATE] Error saving app state: $e');
    }
  }
  
  // Load app state snapshot
  static Future<Map<String, dynamic>?> loadAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString(AppConstants.tokenKey);
      final userJson = prefs.getString(AppConstants.userKey);
      final stateJson = prefs.getString('app_state');
      
      UserData? user;
      if (userJson != null) {
        try {
          user = UserData.fromJson(jsonDecode(userJson));
        } catch (e) {
          print('❌ [STATE] Error parsing user data: $e');
        }
      }
      
      Map<String, dynamic>? additionalData;
      if (stateJson != null) {
        try {
          additionalData = jsonDecode(stateJson) as Map<String, dynamic>;
        } catch (e) {
          print('❌ [STATE] Error parsing state data: $e');
        }
      }
      
      print('✅ [STATE] App state loaded successfully');
      
      return {
        'token': token,
        'user': user,
        'additionalData': additionalData,
      };
    } catch (e) {
      print('❌ [STATE] Error loading app state: $e');
      return null;
    }
  }
  
  // Clear app state
  static Future<void> clearAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.tokenKey);
      await prefs.remove(AppConstants.userKey);
      await prefs.remove('app_state');
      print('🗑️ [STATE] App state cleared');
    } catch (e) {
      print('❌ [STATE] Error clearing app state: $e');
    }
  }
}

