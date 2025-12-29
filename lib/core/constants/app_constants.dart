class AppConstants {
  // App Info
  static const String appName = 'ApartmentSync';
  static const String appTagline = 'Your Community, Connected';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String fcmTokenKey = 'fcm_token';
  static const String isFirstLaunchKey = 'is_first_launch';
  static const String selectedBuildingKey = 'selected_building_code';
  
  // Complaint Status
  static const String complaintStatusOpen = 'Open';
  static const String complaintStatusAssigned = 'Assigned';
  static const String complaintStatusInProgress = 'In Progress';
  static const String complaintStatusResolved = 'Resolved';
  static const String complaintStatusClosed = 'Closed';
  
  // Complaint Categories
  static const String categoryElectrical = 'Electrical';
  static const String categoryPlumbing = 'Plumbing';
  static const String categoryMaintenance = 'Maintenance';
  static const String categorySecurity = 'Security';
  
  // Notice Categories
  static const String noticeCategoryGeneral = 'General';
  static const String noticeCategoryMaintenance = 'Maintenance';
  static const String noticeCategorySecurity = 'Security';
  static const String noticeCategoryEvents = 'Events';
  
  // User Roles
  static const String roleResident = 'resident';
  static const String roleStaff = 'staff';
  static const String roleAdmin = 'admin';
  
  // User Status
  static const String statusPending = 'pending';
  static const String statusActive = 'active';
  static const String statusSuspended = 'suspended';
  static const String statusRejected = 'rejected';
  
  // Date Formats
  static const String dateFormat = 'MMM d, yyyy';
  static const String dateTimeFormat = 'MMM d, yyyy • h:mm a';
  static const String timeFormat = 'h:mm a';
}

