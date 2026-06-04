class Order {
  final String id;
  final String orderNumber;
  final String? pharmacyName;
  final String? pharmacyPhone;
  final String? pharmacyAddress;
  final String? riderName;
  final double totalAmount;
  final double subtotal;
  final double commissionRate;
  final double commissionAmount;
  final double deliveryFee;
  final String status;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime? estimatedDeliveryTime;
  final DateTime? expiresAt;
  final List<OrderItem> items;
  final RiderInfo? rider;
  final String? prescriptionId;
  final String? quoteId;
  final Map<String, dynamic>? deliveryAddress;
  final String? prescriptionImage;
  final bool isPendingQuote;
  final List<Map<String, dynamic>> medicines;
  final List<QuoteHistoryItem> quoteHistory;

  Order({
    required this.id,
    required this.orderNumber,
    this.pharmacyName,
    this.pharmacyPhone,
    this.pharmacyAddress,
    this.riderName,
    required this.totalAmount,
    this.subtotal = 0,
    this.commissionRate = 0,
    this.commissionAmount = 0,
    this.deliveryFee = 0,
    required this.status,
    this.paymentMethod,
    required this.createdAt,
    this.estimatedDeliveryTime,
    this.expiresAt,
    required this.items,
    this.rider,
    this.prescriptionId,
    this.quoteId,
    this.deliveryAddress,
    this.prescriptionImage,
    this.isPendingQuote = false,
    this.medicines = const [],
    this.quoteHistory = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // prescription data can be at top level OR nested under 'prescription'
    final prescriptionObj = json['prescription'] is Map
        ? Map<String, dynamic>.from(json['prescription'] as Map)
        : null;

    final prescriptionImage = json['prescriptionImage']?.toString().isNotEmpty == true
        ? json['prescriptionImage'].toString()
        : prescriptionObj?['imageUrl']?.toString();

    final medicinesRaw = (json['medicines'] as List?)?.isNotEmpty == true
        ? json['medicines'] as List
        : (prescriptionObj?['medicines'] as List?);

    final quoteHistoryRaw = (json['quoteHistory'] as List?)
        ?.map((q) => QuoteHistoryItem.fromJson(Map<String, dynamic>.from(q as Map)))
        .toList() ?? [];

    return Order(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      orderNumber: json['orderNumber'] ?? '',
      pharmacyName: json['pharmacyName'] ?? (json['pharmacy'] is Map ? json['pharmacy']['name'] : null),
      pharmacyPhone: json['pharmacyPhone'],
      pharmacyAddress: json['pharmacyAddress'] ?? (json['pharmacy'] is Map ? json['pharmacy']['address'] : null),
      riderName: json['riderName'],
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      commissionRate: (json['commissionRate'] ?? 0).toDouble(),
      commissionAmount: (json['commissionAmount'] ?? 0).toDouble(),
      deliveryFee: (json['deliveryFee'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      paymentMethod: json['paymentMethod'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.now(),
      estimatedDeliveryTime: json['estimatedDeliveryTime'] != null
          ? DateTime.parse(json['estimatedDeliveryTime']).toLocal()
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt']).toLocal()
          : null,
      items: (json['items'] as List?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
      rider: json['rider'] != null ? RiderInfo.fromJson(json['rider']) : null,
      prescriptionId: json['prescriptionId']?.toString(),
      quoteId: json['quoteId']?.toString(),
      deliveryAddress: json['deliveryAddress'] is Map
          ? Map<String, dynamic>.from(json['deliveryAddress'])
          : (json['deliveryAddress'] is String && (json['deliveryAddress'] as String).isNotEmpty
              ? {'address': json['deliveryAddress']}
              : null),
      prescriptionImage: prescriptionImage,
      isPendingQuote: json['_isPendingQuote'] == true,
      medicines: medicinesRaw
          ?.map((m) => Map<String, dynamic>.from(m as Map))
          .toList() ?? [],
      quoteHistory: quoteHistoryRaw,
    );
  }
}

class QuoteHistoryItem {
  final String? pharmacyName;
  final String status;
  final String rejectionReason;
  final DateTime createdAt;

  QuoteHistoryItem({
    this.pharmacyName,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
  });

  factory QuoteHistoryItem.fromJson(Map<String, dynamic> json) {
    return QuoteHistoryItem(
      pharmacyName: json['pharmacyName'],
      status: json['status'] ?? '',
      rejectionReason: json['rejectionReason'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.now(),
    );
  }
}

class RiderInfo {
  final String id;
  final String name;
  final String phone;
  final String? vehicleNumber;

  RiderInfo({
    required this.id,
    required this.name,
    required this.phone,
    this.vehicleNumber,
  });

  factory RiderInfo.fromJson(Map<String, dynamic> json) {
    return RiderInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      vehicleNumber: json['vehicleNumber'],
    );
  }
}

class OrderItem {
  final String medicineName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  OrderItem({
    required this.medicineName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      medicineName: json['medicineName'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
    );
  }
}
