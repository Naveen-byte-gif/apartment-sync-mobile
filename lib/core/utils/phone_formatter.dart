/// Utility class for phone number formatting and validation
class PhoneFormatter {
  /// Format phone number for display (e.g., 9876543210 -> +91 98765 43210)
  static String formatForDisplay(String phoneNumber) {
    // Remove all non-digit characters
    final cleaned = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    if (cleaned.length == 10) {
      // Format as: +91 98765 43210
      return '+91 ${cleaned.substring(0, 5)} ${cleaned.substring(5)}';
    } else if (cleaned.length == 12 && cleaned.startsWith('91')) {
      // Format as: +91 98765 43210
      return '+${cleaned.substring(0, 2)} ${cleaned.substring(2, 7)} ${cleaned.substring(7)}';
    } else if (cleaned.startsWith('+')) {
      return phoneNumber;
    }
    
    return phoneNumber;
  }

  /// Format phone number for API (10 digits only)
  static String formatForAPI(String phoneNumber) {
    // Remove all non-digit characters
    final cleaned = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    // If 12 digits and starts with 91, remove the 91
    if (cleaned.length == 12 && cleaned.startsWith('91')) {
      return cleaned.substring(2);
    }
    
    // If 11 digits and starts with 0, remove the 0
    if (cleaned.length == 11 && cleaned.startsWith('0')) {
      return cleaned.substring(1);
    }
    
    // Return last 10 digits if longer
    if (cleaned.length > 10) {
      return cleaned.substring(cleaned.length - 10);
    }
    
    return cleaned;
  }

  /// Validate Indian phone number (10 digits starting with 6-9)
  static bool isValidIndianPhone(String phoneNumber) {
    final cleaned = formatForAPI(phoneNumber);
    return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned);
  }

  /// Mask phone number for privacy (e.g., 9876543210 -> 98765*****)
  static String maskPhoneNumber(String phoneNumber) {
    final cleaned = formatForAPI(phoneNumber);
    if (cleaned.length == 10) {
      return '${cleaned.substring(0, 5)}*****';
    }
    return phoneNumber;
  }
}

