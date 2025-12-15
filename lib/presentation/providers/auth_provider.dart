import 'package:flutter/foundation.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/user_data.dart';

class AuthProvider with ChangeNotifier {
  UserData? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  UserData? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    final token = StorageService.getString(AppConstants.tokenKey);
    if (token != null && token.isNotEmpty) {
      ApiService.setToken(token);
      // Load user data
      await loadUserData();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadUserData() async {
    try {
      final response = await ApiService.get('/auth/me');
      if (response['success'] == true && response['data']?['user'] != null) {
        _user = UserData.fromJson(response['data']['user']);
        _isAuthenticated = true;
      }
    } catch (e) {
      _isAuthenticated = false;
      _user = null;
    }
    notifyListeners();
  }

  Future<void> login(String identifier, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.post('/auth/password-login', {
        'identifier': identifier, // Can be email or phone
        'password': password,
      });

      if (response['success'] == true) {
        final token = response['data']?['token'];
        if (token != null) {
          ApiService.setToken(token);
          _user = UserData.fromJson(response['data']?['user'] ?? {});
          _isAuthenticated = true;
        }
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> adminLogin(String phoneNumber, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.post('/auth/admin/login', {
        'phoneNumber': phoneNumber,
        'password': password,
      });

      if (response['success'] == true) {
        final token = response['data']?['token'];
        if (token != null) {
          ApiService.setToken(token);
          _user = UserData.fromJson(response['data']?['user'] ?? {});
          _isAuthenticated = true;
        }
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await StorageService.remove(AppConstants.tokenKey);
    await StorageService.remove(AppConstants.userKey);
    ApiService.setToken(null);
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  bool get isAdmin => _user?.role == AppConstants.roleAdmin;
  bool get isResident => _user?.role == AppConstants.roleResident;
  bool get isStaff => _user?.role == AppConstants.roleStaff;
}

