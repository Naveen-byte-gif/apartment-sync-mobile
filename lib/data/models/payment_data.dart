class PaymentData {
  final String id;
  final String invoiceNumber;
  final double totalAmount;
  final double dueAmount;
  final DateTime dueDate;
  final String status;
  final List<PaymentItem> items;
  final DateTime createdAt;

  PaymentData({
    required this.id,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.dueAmount,
    required this.dueDate,
    required this.status,
    required this.items,
    required this.createdAt,
  });

  factory PaymentData.fromJson(Map<String, dynamic> json) {
    return PaymentData(
      id: json['id'] ?? json['_id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      dueAmount: (json['dueAmount'] ?? json['totalAmount'] ?? 0).toDouble(),
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'])
          : DateTime.now(),
      status: json['status'] ?? 'pending',
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => PaymentItem.fromJson(item))
              .toList()
          : [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
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

