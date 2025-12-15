class ApiConstants {
  // Base URL - Update this with your backend URL
  static const String baseUrl = 'http://192.168.0.106:6500/api';
  // static const String baseUrl = 'https://apartment-sync-backend.onrender.com/api';
  // Socket.IO
  static const String socketUrl = 'http://192.168.0.106:6500';
  // static const String socketUrl = 'https://apartment-sync-backend.onrender.com';

  // Auth Endpoints
  static const String sendOTP = '/auth/send-otp';
  static const String verifyOTPRegister = '/auth/verify-otp-register';
  static const String verifyOTPLogin = '/auth/verify-otp-login';
  static const String passwordLogin = '/auth/password-login';
  static const String adminLogin = '/auth/admin/login';
  static const String adminRegister = '/auth/admin/register';
  static const String getMe = '/auth/me';

  // User Endpoints
  static const String users = '/users';
  static const String buildingDetails = '/users/building-details';
  static const String announcements = '/users/announcements';

  // Complaint Endpoints
  static const String complaints = '/complaints';

  // Notice Endpoints
  static const String notices = '/notices';

  // Payment Endpoints
  static const String payments = '/payments';

  // Admin Endpoints
  static const String adminDashboard = '/admin/dashboard';
  static const String adminPendingApprovals = '/admin/pending-approvals';
  static const String adminComplaints = '/admin/complaints';
  static const String adminBuildings = '/admin/buildings';
  static const String adminUsers = '/admin/users';
  static const String adminBuildingDetails = '/admin/building-details';
  static const String adminAvailableFlats = '/admin/available-flats';

  // Helper method to add buildingCode query param
  static String addBuildingCode(String endpoint, String? buildingCode) {
    if (buildingCode == null || buildingCode.isEmpty) {
      return endpoint;
    }
    final uri = Uri.parse(endpoint);
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'buildingCode': buildingCode,
          },
        )
        .toString();
  }

  // Staff Endpoints
  static const String staffDashboard = '/staff/dashboard';
  static const String staffAssignedComplaints = '/staff/assigned-complaints';

  // Headers
  static Map<String, String> getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
