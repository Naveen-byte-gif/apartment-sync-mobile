class ApiConstants {
  // Base URL - Update this with your backend URL
  static const String baseUrl = 'http://192.168.0.113:6500/api';

  // ------------- AWS URL--------------
  // static const String baseUrl = 'http://13.60.226.11:6500/api';
  // static const String baseUrl = 'https://apartment-sync-backend.onrender.com/api';
  // Socket.IO
  static const String socketUrl = 'http://192.168.0.113:6500';

  // ------------- AWS URL--------------
  // static const String socketUrl = 'http://13.60.226.11:6500';
  // static const String socketUrl = 'https://apartment-sync-backend.onrender.com';

  // Auth Endpoints
  static const String sendOTP = '/auth/send-otp';
  static const String verifyOTPRegister = '/auth/verify-otp-register';
  static const String verifyOTPLogin = '/auth/verify-otp-login';
  static const String passwordLogin = '/auth/password-login';
  static const String adminLogin = '/auth/admin/login';
  static const String adminRegister = '/auth/admin/register';
  static const String adminVerifyOTPRegister =
      '/auth/admin/verify-otp-register';
  static const String getMe = '/auth/me';

  // User Endpoints
  static const String users = '/users';
  static const String buildingDetails = '/users/building-details';
  static const String announcements = '/users/announcements';

  // Complaint Endpoints
  static const String complaints = '/complaints';
  static String complaintById(String id) => '/complaints/$id';
  static String complaintStatus(String id) => '/complaints/$id/status';
  static String complaintAssign(String id) => '/complaints/$id/assign';
  static String complaintUploadAdminMedia(String id) =>
      '/complaints/$id/upload-admin-media';
  static String complaintAdminMedia(String id) => '/complaints/$id/admin-media';
  static String complaintInternalNotes(String id) =>
      '/complaints/$id/internal-notes';
  static String complaintPriority(String id) => '/complaints/$id/priority';
  static String complaintComments(String id) => '/complaints/$id/comments';

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
  static const String adminBuildingView = '/admin/building-view';
  static const String adminAvailableFlats = '/admin/available-flats';
  static const String adminResidents = '/admin/residents';
  static const String adminResidentsBulkAction = '/admin/residents/bulk-action';

  // Helper method to get flat details endpoint
  static String getFlatDetails(
    String buildingCode,
    int floorNumber,
    String flatNumber,
  ) {
    return '/admin/flats/$buildingCode/$floorNumber/$flatNumber';
  }

  // Staff Endpoints
  static const String staffDashboard = '/staff/dashboard';
  static const String staffBuildings = '/staff/buildings';
  static const String staffBuildingDetails = '/staff/building-details';

  // Visitor Endpoints
  static const String visitors = '/visitors';

  // Helper method to change flat status endpoint
  static String changeFlatStatus(
    String buildingCode,
    int floorNumber,
    String flatNumber,
  ) {
    return '/admin/flats/$buildingCode/$floorNumber/$flatNumber/status';
  }

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

  // Staff Endpoints (additional)
  static const String staffAssignedComplaints = '/staff/assigned-complaints';
  static const String adminStaff = '/admin/staff';
  static const String adminStaffOnboard = '/admin/staff/onboard';
  static String adminStaffVerifyIdentity(String staffId) =>
      '/admin/staff/$staffId/verify-identity';
  static const String visitorsOverdue = '/visitors/overdue';
  static String visitorById(String id) => '/visitors/$id';
  static String visitorCheckIn(String id) => '/visitors/$id/check-in';
  static String visitorCheckOut(String id) => '/visitors/$id/check-out';
  static String visitorGenerateQR(String id) => '/visitors/$id/generate-qr';
  static String visitorGenerateOTP(String id) => '/visitors/$id/generate-otp';


  // Headers
  static Map<String, String> getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
