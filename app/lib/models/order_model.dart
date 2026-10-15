import 'cart_item_model.dart';
import 'product_model.dart';

class OrderItemModel {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final ProductSize? selectedSize;
  final List<SelectedOption> selectedOptions;
  final double subtotal;

  OrderItemModel({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.selectedSize,
    this.selectedOptions = const [],
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productId: json['productId'] is Map ? json['productId']['_id'] : json['productId']?.toString() ?? '',
      productName: json['productName'] ?? '',
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      selectedSize: json['selectedSize'] != null
          ? ProductSize.fromJson(json['selectedSize'] as Map<String, dynamic>)
          : null,
      selectedOptions: (json['selectedOptions'] as List<dynamic>?)
              ?.map((o) => SelectedOption.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'unitPrice': unitPrice,
      'quantity': quantity,
      if (selectedSize != null) 'selectedSize': selectedSize!.toJson(),
      'selectedOptions': selectedOptions.map((o) => o.toJson()).toList(),
      'subtotal': subtotal,
    };
  }
}

class OrderModel {
  final String id;
  final String orderCode;
  final String userId;
  final String businessId;
  final String branchId;
  final String? bookingId;
  final String? tableId;
  final String orderType;
  final List<OrderItemModel> items;
  final double subtotal;
  final double discount;
  final double total;
  final String status;
  final String note;
  final DateTime? createdAt;

  OrderModel({
    required this.id,
    required this.orderCode,
    required this.userId,
    required this.businessId,
    required this.branchId,
    this.bookingId,
    this.tableId,
    this.orderType = 'PRE_ORDER',
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    required this.total,
    this.status = 'PENDING',
    this.note = '',
    this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    var itemList = (json['items'] as List<dynamic>?)
            ?.map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>))
            .toList() ??
        [];

    return OrderModel(
      id: json['_id'] ?? json['id'] ?? '',
      orderCode: json['orderCode'] ?? '',
      userId: json['userId'] is Map ? json['userId']['_id'] : json['userId']?.toString() ?? '',
      businessId: json['businessId'] is Map ? json['businessId']['_id'] : json['businessId']?.toString() ?? '',
      branchId: json['branchId'] is Map ? json['branchId']['_id'] : json['branchId']?.toString() ?? '',
      bookingId: json['bookingId'] is Map ? json['bookingId']['_id'] : json['bookingId']?.toString(),
      tableId: json['tableId'] is Map ? json['tableId']['_id'] : json['tableId']?.toString(),
      orderType: json['orderType'] ?? 'PRE_ORDER',
      items: itemList,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'PENDING',
      note: json['note'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'orderCode': orderCode,
      'userId': userId,
      'businessId': businessId,
      'branchId': branchId,
      if (bookingId != null) 'bookingId': bookingId,
      if (tableId != null) 'tableId': tableId,
      'orderType': orderType,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'status': status,
      'note': note,
    };
  }
}
