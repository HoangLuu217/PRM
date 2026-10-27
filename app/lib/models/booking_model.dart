import 'package:flutter/material.dart';

class BookingModel {
  final String id;
  final String userId;
  final String? userName;
  final String? userPhone;
  final String? userAvatar;
  final String businessId;
  final String businessName;
  final String? businessLogo;
  final String branchId;
  final String? branchName;
  final String? branchAddress;
  final String? tableId;
  final String? tableName;
  final int? tableCapacity;
  final String bookingCode;
  final String bookingDate;
  final String startTime;
  final String? endTime;
  final int guestCount;
  final String status;
  final String note;
  final DateTime? createdAt;
  final DateTime? checkedInAt;
  final DateTime? completedAt;

  BookingModel({
    required this.id,
    required this.userId,
    this.userName,
    this.userPhone,
    this.userAvatar,
    required this.businessId,
    required this.businessName,
    this.businessLogo,
    required this.branchId,
    this.branchName,
    this.branchAddress,
    this.tableId,
    this.tableName,
    this.tableCapacity,
    required this.bookingCode,
    required this.bookingDate,
    required this.startTime,
    this.endTime,
    required this.guestCount,
    this.status = 'PENDING',
    this.note = '',
    this.createdAt,
    this.checkedInAt,
    this.completedAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isCheckedIn => status == 'CHECKED_IN';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isRejected => status == 'REJECTED';

  bool get canCustomerCancel => status == 'PENDING' || status == 'CONFIRMED';

  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'Chờ xác nhận';
      case 'CONFIRMED':
        return 'Đã xác nhận';
      case 'CHECKED_IN':
        return 'Đã nhận bàn';
      case 'COMPLETED':
        return 'Hoàn thành';
      case 'CANCELLED':
        return 'Đã hủy';
      case 'REJECTED':
        return 'Bị từ chối';
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
      case 'CHECKED_IN':
        return const Color(0xFF8B5CF6); // Purple
      case 'COMPLETED':
        return const Color(0xFF10B981); // Emerald
      case 'CANCELLED':
        return const Color(0xFF6B7280); // Gray
      case 'REJECTED':
        return const Color(0xFFEF4444); // Red
      default:
        return Colors.blueGrey;
    }
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // User info (populated in owner API)
    String? uName;
    String? uPhone;
    String? uAvatar;
    String uId = '';
    if (json['userId'] is Map) {
      final u = json['userId'] as Map<String, dynamic>;
      uId = (u['_id'] ?? u['id'] ?? '').toString();
      uName = u['fullName']?.toString() ?? u['name']?.toString();
      uPhone = u['phone']?.toString();
      uAvatar = u['avatarUrl']?.toString();
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
    String? brAddr;
    if (json['branchId'] is Map) {
      final br = json['branchId'] as Map<String, dynamic>;
      brId = (br['_id'] ?? br['id'] ?? '').toString();
      brName = br['name']?.toString();
      if (br['address'] is Map) {
        final a = br['address'] as Map<String, dynamic>;
        brAddr = [a['street'], a['ward'], a['district'], a['city']]
            .where((s) => s != null && s.toString().isNotEmpty)
            .join(', ');
      } else if (br['address'] is String) {
        brAddr = br['address'].toString();
      }
    } else {
      brId = (json['branchId'] ?? '').toString();
    }

    // Table info
    String? tId;
    String? tName;
    int? tCap;
    if (json['tableId'] is Map) {
      final t = json['tableId'] as Map<String, dynamic>;
      tId = (t['_id'] ?? t['id'] ?? '').toString();
      tName = t['name']?.toString();
      if (t['capacity'] is num) {
        tCap = (t['capacity'] as num).toInt();
      }
    } else if (json['tableId'] != null) {
      tId = json['tableId'].toString();
    }

    return BookingModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: uId,
      userName: uName,
      userPhone: uPhone,
      userAvatar: uAvatar,
      businessId: bId,
      businessName: bName,
      businessLogo: bLogo,
      branchId: brId,
      branchName: brName,
      branchAddress: brAddr,
      tableId: tId,
      tableName: tName,
      tableCapacity: tCap,
      bookingCode: (json['bookingCode'] ?? 'FCB${json['_id']}').toString(),
      bookingDate: (json['bookingDate'] ?? '').toString(),
      startTime: (json['startTime'] ?? '').toString(),
      endTime: json['endTime']?.toString(),
      guestCount: (json['guestCount'] is num) ? (json['guestCount'] as num).toInt() : 2,
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      note: (json['note'] ?? '').toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      checkedInAt: json['checkedInAt'] != null
          ? DateTime.tryParse(json['checkedInAt'].toString())
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'businessId': businessId,
      'branchId': branchId,
      if (tableId != null) 'tableId': tableId,
      'bookingDate': bookingDate,
      'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'guestCount': guestCount,
      'note': note,
      'status': status,
    };
  }
}
