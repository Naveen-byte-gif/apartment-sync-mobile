class InvoiceData {
  final String id;
  final String invoiceNumber;
  final String flatId;
  final String apartmentCode;
  final String building;
  final String flatNumber;
  final int floor;
  final BillingPeriod billingPeriod;
  final List<InvoiceItem> items;
  final double totalAmount;
  final double previousDues;
  final double lateFee;
  final double totalPayable;
  final DateTime dueDate;
  final String status;
  final double paidAmount;
  final double outstandingAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  InvoiceData({
    required this.id,
    required this.invoiceNumber,
    required this.flatId,
    required this.apartmentCode,
    required this.building,
    required this.flatNumber,
    required this.floor,
    required this.billingPeriod,
    required this.items,
    required this.totalAmount,
    required this.previousDues,
    required this.lateFee,
    required this.totalPayable,
    required this.dueDate,
    required this.status,
    required this.paidAmount,
    required this.outstandingAmount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InvoiceData.fromJson(Map<String, dynamic> json) {
    return InvoiceData(
      id: json['_id'] ?? json['id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      flatId: json['flatId'] is Map 
          ? (json['flatId']?['_id'] ?? json['flatId']?['id'] ?? '')
          : (json['flatId']?.toString() ?? ''),
      apartmentCode: json['apartmentCode'] ?? '',
      building: json['building'] ?? '',
      flatNumber: json['flatNumber'] ?? '',
      floor: json['floor'] is int 
          ? json['floor'] as int
          : (json['floor'] != null ? int.tryParse(json['floor'].toString()) ?? 0 : 0),
      billingPeriod: BillingPeriod.fromJson(json['billingPeriod'] ?? {}),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => InvoiceItem.fromJson(item))
              .toList() ??
          [],
      totalAmount: json['totalAmount'] is num 
          ? (json['totalAmount'] as num).toDouble()
          : 0.0,
      previousDues: json['previousDues'] is num 
          ? (json['previousDues'] as num).toDouble()
          : 0.0,
      lateFee: json['lateFee'] is num 
          ? (json['lateFee'] as num).toDouble()
          : 0.0,
      totalPayable: json['totalPayable'] is num 
          ? (json['totalPayable'] as num).toDouble()
          : 0.0,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'])
          : DateTime.now(),
      status: json['status'] ?? 'pending',
      paidAmount: json['paidAmount'] is num 
          ? (json['paidAmount'] as num).toDouble()
          : 0.0,
      outstandingAmount: json['outstandingAmount'] is num 
          ? (json['outstandingAmount'] as num).toDouble()
          : 0.0,
      notes: json['notes'],
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
      'invoiceNumber': invoiceNumber,
      'flatId': flatId,
      'apartmentCode': apartmentCode,
      'building': building,
      'flatNumber': flatNumber,
      'floor': floor,
      'billingPeriod': billingPeriod.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'previousDues': previousDues,
      'lateFee': lateFee,
      'totalPayable': totalPayable,
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'paidAmount': paidAmount,
      'outstandingAmount': outstandingAmount,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class BillingPeriod {
  final DateTime startDate;
  final DateTime endDate;

  BillingPeriod({
    required this.startDate,
    required this.endDate,
  });

  factory BillingPeriod.fromJson(Map<String, dynamic> json) {
    return BillingPeriod(
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }
}

class InvoiceItem {
  final String name;
  final double amount;
  final String? description;

  InvoiceItem({
    required this.name,
    required this.amount,
    this.description,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      name: json['name'] ?? '',
      amount: json['amount'] is num 
          ? (json['amount'] as num).toDouble()
          : 0.0,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'description': description,
    };
  }
}

