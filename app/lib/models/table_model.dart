import 'package:flutter/material.dart';

class TableModel {
  final String id;
  final String branchId;
  final String name;
  final int capacity;
  final String location;
  final String status;
  final DateTime? createdAt;

  TableModel({
    required this.id,
    required this.branchId,
    required this.name,
    required this.capacity,
    this.location = 'Tầng 1',
    this.status = 'AVAILABLE',
    this.createdAt,
  });

  bool get isAvailable => status == 'AVAILABLE';

  String get statusLabel {
    switch (status) {
      case 'AVAILABLE':
        return 'Bàn trống';
      case 'RESERVED':
        return 'Đã đặt trước';
      case 'UNAVAILABLE':
        return 'Đang có khách';
      case 'MAINTENANCE':
        return 'Bảo trì / Tạm khóa';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'AVAILABLE':
        return const Color(0xFF10B981); // Emerald Green
      case 'RESERVED':
        return const Color(0xFFF59E0B); // Amber
      case 'UNAVAILABLE':
        return const Color(0xFFEF4444); // Red
      case 'MAINTENANCE':
        return const Color(0xFF6B7280); // Gray
      default:
        return const Color(0xFF3B82F6);
    }
  }

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      branchId: (json['branchId'] is Map
              ? json['branchId']['_id']
              : json['branchId'] ?? '')
          .toString(),
      name: (json['name'] ?? 'Bàn').toString(),
      capacity: (json['capacity'] is num) ? (json['capacity'] as num).toInt() : 2,
      location: (json['location'] ?? 'Tầng 1').toString(),
      status: (json['status'] ?? 'AVAILABLE').toString().toUpperCase(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'branchId': branchId,
      'name': name,
      'capacity': capacity,
      'location': location,
      'status': status,
    };
  }
}
