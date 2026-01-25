class UpiConfigData {
  final String id;
  final String apartmentCode;
  final String upiId; // Active UPI ID (for backward compatibility)
  final String accountHolderName;
  final String? bankName;
  final List<UpiIdData>? upiIds; // Multiple UPI IDs support
  final QrCodeImage? qrCodeImage;
  final String defaultPaymentNoteFormat;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  UpiConfigData({
    required this.id,
    required this.apartmentCode,
    required this.upiId,
    required this.accountHolderName,
    this.bankName,
    this.upiIds,
    this.qrCodeImage,
    required this.defaultPaymentNoteFormat,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });
  
  // Get active UPI ID from multiple UPI IDs or fallback to single UPI ID
  String get activeUpiId {
    if (upiIds != null && upiIds!.isNotEmpty) {
      final active = upiIds!.firstWhere(
        (id) => id.isActive,
        orElse: () => upiIds!.first,
      );
      return active.upiId;
    }
    return upiId;
  }
  
  // Get active account holder name
  String get activeAccountHolderName {
    if (upiIds != null && upiIds!.isNotEmpty) {
      final active = upiIds!.firstWhere(
        (id) => id.isActive,
        orElse: () => upiIds!.first,
      );
      return active.accountHolderName;
    }
    return accountHolderName;
  }

  factory UpiConfigData.fromJson(Map<String, dynamic> json) {
    // Handle multiple UPI IDs - safely parse the array
    List<UpiIdData>? upiIdsList;
    if (json['upiIds'] != null && json['upiIds'] is List) {
      try {
        final upiIdsRaw = json['upiIds'] as List;
        upiIdsList = upiIdsRaw
            .where((item) => item is Map<String, dynamic>)
            .map((item) {
              try {
                return UpiIdData.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                print('Error parsing UPI ID item: $e');
                return null;
              }
            })
            .whereType<UpiIdData>()
            .toList();
      } catch (e) {
        print('Error parsing upiIds array: $e');
        upiIdsList = null;
      }
    }
    
    // Get active UPI ID from array or fallback to single field
    String activeUpiId = '';
    String activeAccountHolderName = '';
    
    if (upiIdsList != null && upiIdsList.isNotEmpty) {
      final list = upiIdsList; // Non-null local variable
      try {
        final active = list.firstWhere(
          (id) => id.isActive,
          orElse: () => list.first,
        );
        activeUpiId = active.upiId;
        activeAccountHolderName = active.accountHolderName;
      } catch (e) {
        print('Error finding active UPI ID: $e');
        // Fallback to first item or single field
        if (list.isNotEmpty) {
          activeUpiId = list.first.upiId;
          activeAccountHolderName = list.first.accountHolderName;
        } else {
          activeUpiId = json['upiId']?.toString() ?? '';
          activeAccountHolderName = json['accountHolderName']?.toString() ?? '';
        }
      }
    } else {
      // Use direct fields (backward compatibility or public API response)
      activeUpiId = json['upiId']?.toString() ?? '';
      activeAccountHolderName = json['accountHolderName']?.toString() ?? '';
    }
    
    return UpiConfigData(
      id: json['_id'] ?? json['id'] ?? '',
      apartmentCode: json['apartmentCode'] ?? '',
      upiId: activeUpiId,
      accountHolderName: activeAccountHolderName,
      bankName: json['bankName'],
      upiIds: upiIdsList,
      qrCodeImage: json['qrCodeImage'] != null
          ? QrCodeImage.fromJson(json['qrCodeImage'])
          : null,
      defaultPaymentNoteFormat:
          json['defaultPaymentNoteFormat'] ?? 'INV-{invoiceNumber} | Flat {flatNumber}',
      isEnabled: json['isEnabled'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apartmentCode': apartmentCode,
      'upiId': upiId,
      'accountHolderName': accountHolderName,
      'bankName': bankName,
      'qrCodeImage': qrCodeImage?.toJson(),
      'defaultPaymentNoteFormat': defaultPaymentNoteFormat,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Generate UPI deep link with ALL REQUIRED parameters (MANDATORY for UPI security)
  // Format: upi://pay?pa=society@upi&pn=ApartmentSync&am=2500&cu=INR&tn=INV-102
  // MANDATORY params: pa, pn, am, cu, tn (all required for UPI security compliance)
  String generateUpiDeepLink(double amount, String note) {
    // Ensure note is max 30 characters (UPI security requirement)
    final shortNote = note.length > 30 ? note.substring(0, 30) : note;
    
    // Encode all parameters properly (URL encoding)
    final encodedNote = Uri.encodeComponent(shortNote);
    final encodedPayeeName = Uri.encodeComponent(activeAccountHolderName);
    final encodedUpiId = Uri.encodeComponent(activeUpiId);
    
    // Build UPI deep link with ALL required parameters
    // Format: upi://pay?pa=...&pn=...&am=...&cu=INR&tn=...
    return 'upi://pay?pa=$encodedUpiId&pn=$encodedPayeeName&am=${amount.toStringAsFixed(2)}&cu=INR&tn=$encodedNote';
  }

  // Format payment note (short format, max 25-30 chars for UPI security)
  // Format: "INV-102 | Flat 102" (exactly as specified)
  String formatPaymentNote(String invoiceNumber, String flatNumber) {
    // Extract short invoice number (remove long prefixes if present)
    String shortInvNum = invoiceNumber;
    
    // If invoice number is too long, extract the last part after last dash
    if (invoiceNumber.contains('-')) {
      final parts = invoiceNumber.split('-');
      // Use last meaningful part (usually the sequence number)
      if (parts.length > 1) {
        // Try to use last 2 parts
        shortInvNum = parts.sublist(parts.length - 2).join('-');
        // If still too long, use just the last part
        if (shortInvNum.length > 10) {
          shortInvNum = parts.last;
        }
      }
    }
    
    // Format: "INV-102 | Flat 102" - keep it short and clean
    String note = '';
    if (flatNumber.isNotEmpty) {
      note = 'INV-$shortInvNum | Flat $flatNumber';
    } else {
      note = 'INV-$shortInvNum';
    }
    
    // Enforce max 30 characters (UPI security requirement)
    if (note.length > 30) {
      // Try shorter format: "INV-102 | F102"
      if (flatNumber.isNotEmpty) {
        note = 'INV-$shortInvNum | F$flatNumber';
      } else {
        note = 'INV-$shortInvNum';
      }
    }
    
    // Final fallback - just invoice number
    if (note.length > 30) {
      note = 'INV-${shortInvNum.substring(0, 10)}'; // Max 13 chars
    }
    
    return note;
  }
}

// UPI ID data class for multiple UPI IDs support
class UpiIdData {
  final String id;
  final String upiId;
  final String accountHolderName;
  final String? bankName;
  final bool isActive;
  final DateTime createdAt;

  UpiIdData({
    required this.id,
    required this.upiId,
    required this.accountHolderName,
    this.bankName,
    required this.isActive,
    required this.createdAt,
  });

  factory UpiIdData.fromJson(Map<String, dynamic> json) {
    // Safely parse id - handle both ObjectId objects and strings
    String idStr = '';
    if (json['_id'] != null) {
      if (json['_id'] is String) {
        idStr = json['_id'] as String;
      } else if (json['_id'] is Map) {
        idStr = json['_id']['\$oid']?.toString() ?? json['_id']['_id']?.toString() ?? '';
      } else {
        idStr = json['_id'].toString();
      }
    } else if (json['id'] != null) {
      idStr = json['id'].toString();
    }
    
    // Safely parse createdAt
    DateTime createdAtDate = DateTime.now();
    if (json['createdAt'] != null) {
      try {
        if (json['createdAt'] is String) {
          createdAtDate = DateTime.parse(json['createdAt'] as String);
        } else if (json['createdAt'] is Map) {
          final dateStr = json['createdAt']['\$date']?.toString() ?? '';
          if (dateStr.isNotEmpty) {
            createdAtDate = DateTime.parse(dateStr);
          }
        }
      } catch (e) {
        print('Error parsing createdAt: $e');
        createdAtDate = DateTime.now();
      }
    }
    
    return UpiIdData(
      id: idStr,
      upiId: json['upiId']?.toString() ?? '',
      accountHolderName: json['accountHolderName']?.toString() ?? '',
      bankName: json['bankName']?.toString(),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : (json['isActive']?.toString().toLowerCase() == 'true'),
      createdAt: createdAtDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'upiId': upiId,
      'accountHolderName': accountHolderName,
      'bankName': bankName,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class QrCodeImage {
  final String url;
  final String? publicId;

  QrCodeImage({
    required this.url,
    this.publicId,
  });

  factory QrCodeImage.fromJson(Map<String, dynamic> json) {
    return QrCodeImage(
      url: json['url'] ?? '',
      publicId: json['publicId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'publicId': publicId,
    };
  }
}

