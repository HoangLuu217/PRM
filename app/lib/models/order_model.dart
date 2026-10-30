import 'package:flutter/material.dart';
import 'cart_item_model.dart';
import 'product_model.dart';

class OrderItemModel {
  final String productId;
  final String productName;
  final int unitPrice;
  final int quantity;
  final ProductSize? selectedSize;
  final List<SelectedOption> selectedOptions;
  final String? sizeName;
  final int? sizePrice;
  final List<String> optionTexts;
  final int subtotal;

  OrderItemModel({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.selectedSize,
    this.selectedOptions = const [],
    this.sizeName,
    this.sizePrice,
    this.optionTexts = const [],
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    ProductSize? pSize;
    String? sName;
    int? sPrice;

    if (json['selectedSize'] is Map) {
      final sMap = json['selectedSize'] as Map<String, dynamic>;
      pSize = ProductSize.fromJson(sMap);
      sName = sMap['name']?.toString();
      if (sMap['price'] is num) {
        sPrice = (sMap['price'] as num).toInt();
      }
    }

    final sOptions = <SelectedOption>[];
    final opts = <String>[];
    if (json['selectedOptions'] is List) {
      for (final opt in json['selectedOptions']) {
        if (opt is Map) {
          final optMap = opt as Map<String, dynamic>;
          sOptions.add(SelectedOption.fromJson(optMap));
          final n = opt['name']?.toString() ?? '';
          final v = opt['value']?.toString() ?? '';
          if (n.isNotEmpty && v.isNotEmpty) {
            opts.add('$n: $v');
          }
        }
      }
    }

    final pId = (json['productId'] is Map
            ? json['productId']['_id']
            : json['productId'] ?? '')
        .toString();
    final pName = (json['productName'] ?? 'Món ăn').toString();
    final uPrice = (json['unitPrice'] is num) ? (json['unitPrice'] as num).toInt() : 0;
    final qty = (json['quantity'] is num) ? (json['quantity'] as num).toInt() : 1;
    final sub = (json['subtotal'] is num) ? (json['subtotal'] as num).toInt() : (uPrice * qty);

    return OrderItemModel(
      productId: pId,
      productName: pName,
      unitPrice: uPrice,
      quantity: qty,
      selectedSize: pSize,
      selectedOptions: sOptions,
      sizeName: sName,
      sizePrice: sPrice,
      optionTexts: opts,
      subtotal: sub,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'unitPrice': unitPrice,
      'quantity': quantity,
      if (selectedSize != null)
        'selectedSize': selectedSize!.toJson()
      else if (sizeName != null)
        'selectedSize': {'name': sizeName, 'price': sizePrice ?? unitPrice},
      if (selectedOptions.isNotEmpty)
        'selectedOptions': selectedOptions.map((o) => o.toJson()).toList(),
      'subtotal': subtotal,
    };
  }
}

class OrderModel {
  final String id;
  final String orderCode;
  final String userId;
  final String? userName;
  final String? userPhone;
  final String businessId;
  final String businessName;
  final String? businessLogo;
  final String branchId;
  final String? branchName;
  final String? bookingId;
  final String? bookingCode;
  final String? tableId;
  final String? tableName;
  final String orderType;
  final List<OrderItemModel> items;
  final int subtotal;
  final int discount;
  final int total;
  final String status;
  final String note;
  final DateTime? createdAt;
  final String? payosAccountNo;
  final String? payosAccountName;
  final String? payosBin;
  final String? payosQrUrl;

  OrderModel({
    required this.id,
    required this.orderCode,
    required this.userId,
    this.userName,
    this.userPhone,
    required this.businessId,
    this.businessName = 'Nhà hàng',
    this.businessLogo,
    required this.branchId,
    this.branchName,
    this.bookingId,
    this.bookingCode,
    this.tableId,
    this.tableName,
    this.orderType = 'PRE_ORDER',
    this.items = const [],
    required this.subtotal,
    this.discount = 0,
    required this.total,
    this.status = 'PENDING',
    this.note = '',
    this.createdAt,
    this.payosAccountNo,
    this.payosAccountName,
    this.payosBin,
    this.payosQrUrl,
  });

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isPreparing => status == 'PREPARING';
  bool get isReady => status == 'READY';
  bool get isServed => status == 'SERVED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';

  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'Chờ xác nhận';
      case 'CONFIRMED':
        return 'Đã xác nhận';
      case 'PREPARING':
        return 'Đang chuẩn bị';
      case 'READY':
        return 'Sẵn sàng phục vụ';
      case 'SERVED':
        return 'Đã lên món';
      case 'COMPLETED':
        return 'Hoàn thành';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'PENDING':
        return const Color(0xFFF59E0B); // Amber
      case 'CONFIRMED':
        return const Color(0xFF3B82F6); // Blue
      case 'PREPARING':
        return const Color(0xFF8B5CF6); // Purple
      case 'READY':
        return const Color(0xFF06B6D4); // Cyan
      case 'SERVED':
        return const Color(0xFF10B981); // Emerald
      case 'COMPLETED':
        return const Color(0xFF059669); // Dark Green
      case 'CANCELLED':
        return const Color(0xFFEF4444); // Red
      default:
        return Colors.blueGrey;
    }
  }

  int get trackingStepIndex {
    switch (status) {
      case 'PENDING':
        return 0;
      case 'CONFIRMED':
        return 1;
      case 'PREPARING':
        return 2;
      case 'READY':
        return 3;
      case 'SERVED':
        return 4;
      case 'COMPLETED':
        return 5;
      default:
        return 0;
    }
  }

  String? get nextOwnerStatus {
    switch (status) {
      case 'PENDING':
        return 'CONFIRMED';
      case 'CONFIRMED':
        return 'PREPARING';
      case 'PREPARING':
        return 'READY';
      case 'READY':
        return 'SERVED';
      case 'SERVED':
        return 'COMPLETED';
      default:
        return null;
    }
  }

  String? get nextOwnerStatusLabel {
    switch (status) {
      case 'PENDING':
        return 'Xác nhận đơn';
      case 'CONFIRMED':
        return 'Bắt đầu làm món';
      case 'PREPARING':
        return 'Món đã sẵn sàng';
      case 'READY':
        return 'Xác nhận đã phục vụ';
      case 'SERVED':
        return 'Hoàn thành đơn';
      default:
        return null;
    }
  }

  String get orderTypeLabel {
    switch (orderType) {
      case 'PRE_ORDER':
        return 'Đặt món trước';
      case 'DINE_IN':
        return 'Dùng tại quán';
      case 'PICKUP':
        return 'Mang đi';
      case 'DELIVERY':
        return 'Giao hàng';
      default:
        return orderType;
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // User info
    String? uName;
    String? uPhone;
    String uId = '';
    if (json['userId'] is Map) {
      final u = json['userId'] as Map<String, dynamic>;
      uId = (u['_id'] ?? u['id'] ?? '').toString();
      uName = u['fullName']?.toString() ?? u['name']?.toString();
      uPhone = u['phone']?.toString();
    } else {
      uId = (json['userId'] ?? '').toString();
    }

    // Business info
    String bId = '';
    String bName = 'Nhà hàng';
    String? bLogo;
    if (json['businessId'] is Map) {
      final b = json['businessId'] as Map<String, dynamic>;
      bId = (b['_id'] ?? b['id'] ?? '').toString();
      bName = (b['name'] ?? 'Nhà hàng').toString();
      bLogo = b['logoUrl']?.toString();
    } else {
      bId = (json['businessId'] ?? '').toString();
    }

    // Branch info
    String brId = '';
    String? brName;
    if (json['branchId'] is Map) {
      final br = json['branchId'] as Map<String, dynamic>;
      brId = (br['_id'] ?? br['id'] ?? '').toString();
      brName = br['name']?.toString();
    } else {
      brId = (json['branchId'] ?? '').toString();
    }

    // Booking info
    String? bkId;
    String? bkCode;
    if (json['bookingId'] is Map) {
      final bk = json['bookingId'] as Map<String, dynamic>;
      bkId = (bk['_id'] ?? bk['id'] ?? '').toString();
      bkCode = bk['bookingCode']?.toString();
    } else if (json['bookingId'] != null) {
      bkId = json['bookingId'].toString();
    }

    // Table info
    String? tId;
    String? tName;
    if (json['tableId'] is Map) {
      final t = json['tableId'] as Map<String, dynamic>;
      tId = (t['_id'] ?? t['id'] ?? '').toString();
      tName = t['name']?.toString();
    } else if (json['tableId'] != null) {
      tId = json['tableId'].toString();
    }

    // Items list
    final itemList = <OrderItemModel>[];
    if (json['items'] is List) {
      for (final item in json['items']) {
        if (item is Map) {
          itemList.add(OrderItemModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final sTotal = (json['subtotal'] is num) ? (json['subtotal'] as num).toInt() : 0;
    final disc = (json['discount'] is num) ? (json['discount'] as num).toInt() : 0;
    final tot = (json['total'] is num) ? (json['total'] as num).toInt() : (sTotal - disc);

    String? payosAccNo;
    String? payosAccName;
    String? payosBin;
    String? payosQrUrl;
    if (json['payosData'] is Map) {
      final pData = json['payosData'] as Map<String, dynamic>;
      payosAccNo = pData['accountNumber']?.toString();
      payosAccName = pData['accountName']?.toString();
      payosBin = pData['bin']?.toString();
      payosQrUrl = pData['qrCode']?.toString();
    }

    return OrderModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      orderCode: (json['orderCode'] ?? 'FCO${json['_id']}').toString(),
      userId: uId,
      userName: uName,
      userPhone: uPhone,
      businessId: bId,
      businessName: bName,
      businessLogo: bLogo,
      branchId: brId,
      branchName: brName,
      bookingId: bkId,
      bookingCode: bkCode,
      tableId: tId,
      tableName: tName,
      orderType: (json['orderType'] ?? 'PRE_ORDER').toString().toUpperCase(),
      items: itemList,
      subtotal: sTotal,
      discount: disc,
      total: tot,
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      note: (json['note'] ?? '').toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
      payosAccountNo: payosAccNo,
      payosAccountName: payosAccName,
      payosBin: payosBin,
      payosQrUrl: payosQrUrl,
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
