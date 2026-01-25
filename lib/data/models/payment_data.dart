class PaymentData {
  final String id;
  final String? invoiceId; // Optional - invoice generated after payment
  final String? flatId; // Optional - can use phone number
  final String apartmentCode;
  final String? invoiceNumber; // Optional - generated after payment
  final String? phoneNumber; // For phone-number-based payments
  final double amount;
  final String paymentPurpose;
  final String? description;
  final String? upiReferenceId;
  final DateTime paymentDate;
  final String status;
  final String? rejectionReason;
  final String? receiptNumber;
  final String? receiptPdfUrl;
  final String? transactionNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentData({
    required this.id,
    this.invoiceId,
    this.flatId,
    required this.apartmentCode,
    this.invoiceNumber,
    this.phoneNumber,
    required this.amount,
    required this.paymentPurpose,
    this.description,
    this.upiReferenceId,
    required this.paymentDate,
    required this.status,
    this.rejectionReason,
    this.receiptNumber,
    this.receiptPdfUrl,
    this.transactionNote,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentData.fromJson(Map<String, dynamic> json) {
    // Safely extract invoiceId - handle both Map and String
    String invoiceIdStr = '';
    if (json['invoiceId'] != null) {
      if (json['invoiceId'] is Map) {
        invoiceIdStr = json['invoiceId']?['_id']?.toString() ?? 
                       json['invoiceId']?['id']?.toString() ?? '';
      } else {
        invoiceIdStr = json['invoiceId'].toString();
      }
    }
    
    // Safely extract flatId - handle both Map and String
    String flatIdStr = '';
    if (json['flatId'] != null) {
      if (json['flatId'] is Map) {
        flatIdStr = json['flatId']?['_id']?.toString() ?? 
                    json['flatId']?['id']?.toString() ?? '';
      } else {
        flatIdStr = json['flatId'].toString();
      }
    }
    
    // Safely parse amount
    double amountValue = 0.0;
    if (json['amount'] != null) {
      if (json['amount'] is num) {
        amountValue = (json['amount'] as num).toDouble();
      } else if (json['amount'] is String) {
        amountValue = double.tryParse(json['amount'] as String) ?? 0.0;
      }
    }
    
    // Safely parse dates
    DateTime parseDate(dynamic dateValue, DateTime defaultValue) {
      if (dateValue == null) return defaultValue;
      if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          return defaultValue;
        }
      }
      return defaultValue;
    }
    
    return PaymentData(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      invoiceId: invoiceIdStr.isEmpty ? null : invoiceIdStr,
      flatId: flatIdStr.isEmpty ? null : flatIdStr,
      apartmentCode: json['apartmentCode']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      amount: amountValue,
      paymentPurpose: json['paymentPurpose']?.toString() ?? 'Maintenance',
      description: json['description']?.toString(),
      upiReferenceId: json['upiReferenceId']?.toString(),
      paymentDate: parseDate(json['paymentDate'], DateTime.now()),
      status: json['status']?.toString() ?? 'pending_verification',
      rejectionReason: json['rejectionReason']?.toString(),
      receiptNumber: json['receiptNumber']?.toString(),
      receiptPdfUrl: json['receiptPdfUrl']?.toString(),
      transactionNote: json['transactionNote']?.toString(),
      createdAt: parseDate(json['createdAt'], DateTime.now()),
      updatedAt: parseDate(json['updatedAt'], DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'flatId': flatId,
      'apartmentCode': apartmentCode,
      'invoiceNumber': invoiceNumber,
      'amount': amount,
      'paymentPurpose': paymentPurpose,
      'description': description,
      'upiReferenceId': upiReferenceId,
      'paymentDate': paymentDate.toIso8601String(),
      'status': status,
      'rejectionReason': rejectionReason,
      'receiptNumber': receiptNumber,
      'receiptPdfUrl': receiptPdfUrl,
      'transactionNote': transactionNote,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class PaymentItem {
  final String name;
  final double amount;

  PaymentItem({
    required this.name,
    required this.amount,
  });

  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    return PaymentItem(
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}

